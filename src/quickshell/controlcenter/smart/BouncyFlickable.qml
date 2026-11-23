import QtQuick

// Responsive vertical Flickable combining native touchpad 1:1 tracking with silky critically-damped wheel glide.
Flickable {
    id: fl
    clip: true
    boundsBehavior: Flickable.DragAndOvershootBounds
    flickDeceleration: 3000
    maximumFlickVelocity: 3200

    property real wheelStep: 120
    property real _targetY: 0

    SpringVal {
        id: scrollSp
        stiffness: 420
        damping: 0.96
        eps: 0.25
        onValueChanged: {
            if (!fl.dragging && !fl.flicking) fl.contentY = value;
        }
    }

    onDraggingChanged: {
        if (dragging) {
            scrollSp.snap(contentY);
            _targetY = contentY;
        }
    }

    onContentHeightChanged: {
        const maxY = Math.max(0, contentHeight - height);
        if (contentY > maxY) {
            _targetY = maxY;
            scrollSp.snap(maxY);
            contentY = maxY;
        } else if (_targetY > maxY) {
            _targetY = maxY;
            scrollSp.target = maxY;
        }
    }

    function jumpTop() {
        _targetY = 0;
        scrollSp.snap(0);
        contentY = 0;
    }

    function jumpTo(y) {
        const clamped = Math.max(0, Math.min(Math.max(0, contentHeight - height), y));
        _targetY = clamped;
        scrollSp.snap(clamped);
        scrollSp.target = clamped;
        contentY = clamped;
    }

    WheelHandler {
        target: null
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => {
            const maxY = Math.max(0, fl.contentHeight - fl.height);
            if (maxY <= 0) return;

            // On Wayland/Qt6, discrete mouse wheels often report both angleDelta (multiples of 120) and a small pixelDelta.
            // Treat discrete notches via angleDelta for crisp, consistent travel; treat fine pixelDelta as 1:1 touchpad scroll.
            const hasPixel = e.pixelDelta && e.pixelDelta.y !== 0;
            const ay = e.angleDelta ? e.angleDelta.y : 0;
            const isDiscreteWheel = !hasPixel || (Math.abs(ay) >= 120 && Math.abs(ay) % 120 === 0);

            if (!isDiscreteWheel) {
                const nextY = Math.max(0, Math.min(maxY, fl.contentY - e.pixelDelta.y));
                fl._targetY = nextY;
                scrollSp.snap(nextY);
                fl.contentY = nextY;
                e.accepted = true;
                return;
            }

            if (!scrollSp.moving) {
                scrollSp.snap(fl.contentY);
                fl._targetY = fl.contentY;
            }
            const delta = -(ay / 120.0) * fl.wheelStep;
            fl._targetY = Math.max(0, Math.min(maxY, fl._targetY + delta));
            scrollSp.target = fl._targetY;
            e.accepted = true;
        }
    }
}
