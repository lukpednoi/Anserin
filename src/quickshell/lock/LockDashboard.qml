import QtQuick
import "../"
import "redactor"

Item {
    id: dashboard
    required property var screenRoot
    required property var store
    required property var passwordItem
    required property Item passwordHome
    readonly property var motion: screenRoot.portalEnabled ? portalMotion : padlockMotion
    readonly property real fit: Math.min(width / store.refW, height / store.refH)
    readonly property real reveal: screenRoot.transitionEnabled ? dashboard.motion.dashboardOpacity : screenRoot.centerReveal

    anchors.fill: parent

    Item {
        width: dashboard.store.refW
        height: dashboard.store.refH
        anchors.centerIn: parent
        scale: dashboard.fit

        PortalTransition {
            id: portalMotion
            imageSource: "file://" + Caching.anserinDir + "/assets/lock/portal.png"
            anchors.centerIn: parent
            width: large ? dashboard.store.panelW + 64 : 170
            height: large ? dashboard.store.panelH + 64 : 152
            large: screenRoot.animationStyle === "portal-large"
            visible: screenRoot.portalEnabled && screenRoot.sceneActive
            authenticated: screenRoot.isUnlocking && screenRoot.portalEnabled
        }

        Rectangle {
            id: frame
            anchors.centerIn: parent
            width: screenRoot.transitionEnabled ? 170 + (dashboard.store.panelW - 170) * dashboard.motion.morph : dashboard.store.panelW
            height: screenRoot.transitionEnabled ? 152 + (dashboard.store.panelH - 152) * dashboard.motion.morph : dashboard.store.panelH
            radius: ThemeBackend.borderRadius * 1.5
            color: ThemeBackend.surface0
            border.width: 1.5
            border.color: ThemeBackend.surface1
            clip: true
            opacity: screenRoot.transitionEnabled ? dashboard.motion.frameOpacity : dashboard.reveal
            scale: screenRoot.transitionEnabled ? dashboard.motion.frameScale : 0.92 + dashboard.reveal * 0.08
            rotation: screenRoot.transitionEnabled ? dashboard.motion.turn : 0
            visible: opacity > 0.001
            transform: Scale {
                origin.x: frame.width / 2
                origin.y: frame.height / 2
                xScale: screenRoot.foldScaleX
                yScale: screenRoot.foldScaleY
            }

            Loader {
                width: dashboard.store.panelW
                height: dashboard.store.panelH
                anchors.centerIn: parent
                opacity: dashboard.reveal
                active: screenRoot.sceneActive && (screenRoot.inputActive || opacity > 0.001)
                sourceComponent: LockLayoutView {
                    store: dashboard.store
                    scope: "panel"
                    ctx: dashboard.screenRoot
                    passwordItem: dashboard.passwordItem
                    passwordHome: dashboard.passwordHome
                }
            }

            PadlockTransition {
                id: padlockMotion
                anchors.fill: parent
                visible: screenRoot.transitionEnabled && !screenRoot.portalEnabled
                glyphColor: ThemeBackend.text
                glyphSize: screenRoot.s(100)
                authenticated: screenRoot.isUnlocking && screenRoot.transitionEnabled && !screenRoot.portalEnabled
            }
        }
    }

    Connections {
        target: dashboard.motion
        function onStageChanged() {
            const stage = dashboard.motion.stage;
            if (stage === "spin") screenRoot.centerReveal = 1;
            else if (stage === "ready") screenRoot.centerReveal = screenRoot.wingsReveal = 0;
            else if (stage === "dashboard") {
                screenRoot.wingsReveal = 1;
                screenRoot.restoreFocus();
            }
        }
        function onUnlockFinished() { screenRoot.lockController.completeUnlock(); }
    }

    Connections {
        target: screenRoot.lockUI
        function onFailedChanged() {
            if (!screenRoot.lockUI.failed) return;
            dashboard.passwordItem.input.triggerShake();
            dashboard.passwordItem.input.clear();
            screenRoot.restoreFocus();
        }
    }
}
