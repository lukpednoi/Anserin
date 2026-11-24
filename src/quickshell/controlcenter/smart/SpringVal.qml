import QtQuick

// Under-damped harmonic spring with velocity impulse kick() and 0% CPU at rest.
QtObject {
    id: sp
    property real value: 0.0
    property real target: 0.0
    property real velocity: 0.0
    property real stiffness: 360.0
    property real damping: 0.56
    property real eps: 0.001
    property bool initialized: false
    readonly property bool moving: anim.running

    function snap(v) {
        value = v;
        velocity = 0.0;
        initialized = true;
        anim.running = false;
    }

    function snapAndGo(fromVal, toVal) {
        value = fromVal;
        velocity = 0.0;
        target = toVal;
        initialized = true;
        anim.running = true;
    }

    function kick(impulse) {
        velocity += impulse;
        initialized = true;
        anim.running = true;
    }

    onTargetChanged: {
        if (!initialized) {
            value = target;
            initialized = true;
        } else {
            anim.running = true;
        }
    }

    property FrameAnimation _anim: FrameAnimation {
        id: anim
        running: false
        onTriggered: {
            const dt = Math.min(0.033, Math.max(0.001, frameTime));
            const k = Math.max(20.0, sp.stiffness);
            const c = 2.0 * Math.max(0.08, sp.damping) * Math.sqrt(k);
            const acc = -k * (sp.value - sp.target) - c * sp.velocity;
            sp.velocity += acc * dt;
            sp.value += sp.velocity * dt;
            if (Math.abs(sp.value - sp.target) < sp.eps && Math.abs(sp.velocity) < sp.eps * 8.0) {
                sp.value = sp.target;
                sp.velocity = 0.0;
                anim.running = false;
            }
        }
    }
}
