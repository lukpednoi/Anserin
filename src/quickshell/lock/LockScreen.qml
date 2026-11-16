import QtQuick
import QtQuick.Window
import Quickshell.Io
import Quickshell.Services.Mpris
import "../"
import "redactor"
import "redactor/elements"

FocusScope {
    id: lockScreenRoot
    required property var surface
    required property var lockController
    required property var rootLock
    required property var pam
    required property var lockUI
    required property var suspendProcess
    required property var reloadProcess
    required property var poweroffProcess

    readonly property var passwordInput: livePassword.input
    readonly property bool sceneActive: rootLock.locked
    readonly property string animationStyle: Config.getSetting("lockscreen.animation", "padlock")
    // Simple (lockscreen.style): no Dashboard; the clock, and the profile picture, the name and the password under it;
    // unlocked it slides up. After the corner revolver's Lock (AnserinMode.lockShotAt), in either style, the intro's
    // waves sweep in from the top-right corner to the bottom-left instead of down from the top.
    readonly property bool simple: Config.getSetting("lockscreen.style", "dashboard") === "simple"
    readonly property bool diagonalIntro: Date.now() - AnserinMode.lockShotAt < 4000
    property real simpleSlide: 0
    readonly property bool portalEnabled: !simple && (animationStyle === "portal" || animationStyle === "portal-large")
    readonly property bool transitionEnabled: !simple && animationStyle !== "default"
    readonly property bool slides: transitionEnabled || simple          // the backdrop goes up with the content
    readonly property real slide: simple ? simpleSlide : dashboard.motion.slide
    LockLayoutStore { id: layoutStore; monitorName: lockScreenRoot.safeScreenName || "default" }
    property alias freezeWallpaperView: backdrop.freezeWallpaperView
    property alias idleTimer: idleTimer
    property alias introStartDelayTimer: introStartDelayTimer
    property alias introSequence: introSequence

    anchors.fill: parent
    focus: true

    Rectangle {
        z: 10000
        anchors.fill: parent
        color: "black"
        opacity: lockController.startupFade ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { enabled: !lockController.startupFade; NumberAnimation { duration: 400 } }
    }

    Rectangle {
        anchors.fill: parent
        color: ThemeBackend.crust
        z: -1
    }

    function s(val) {
        return Scaler.s(val);
    }

    readonly property var glassScreen: surface.screen
    property string safeScreenName: (surface.screen && surface.screen.name) ? surface.screen.name : (surface.output && surface.output.name ? surface.output.name : "")
    property string wallpaperSource: {
        let cacheDir = Caching.getCacheDir("wallpaper");
        if (safeScreenName !== "" && safeScreenName !== "default") {
            return "file://" + cacheDir + "/current_wallpaper_" + safeScreenName + ".png";
        }
        return "file://" + cacheDir + "/current_wallpaper.png";
    }
    property string currentFreezePath: {
        if (lockController.freezeTimestamp === "") return "";
        let scrName = (safeScreenName !== "" && safeScreenName !== "default") ? safeScreenName : "default";
        return Caching.getRunDir("screenshot") + "/lock_freeze_" + scrName + "_" + lockController.freezeTimestamp + ".png";
    }

    property bool isUnlocking: lockController.isUnlocking
    property real foldScaleX: 1.0
    property real foldScaleY: 1.0

    onIsUnlockingChanged: {
        if (isUnlocking) {
            openDashboardAnim.stop();
            closeDashboardAnim.stop();
            if (simple) simpleUnlock.restart();
            else if (transitionEnabled) dashboard.motion.startUnlock();
            else unlockSequence.restart();
        } else {
            foldScaleX = 1.0;
            foldScaleY = 1.0;
            mainOpacity = 1.0;
        }
    }

    property string currentUser: SystemInfo.username !== "" ? SystemInfo.username : I18n.t("lock.default_user")
    property string faceIconPath: SystemInfo.avatarPath !== "" ? (SystemInfo.avatarPath.startsWith("file://") ? SystemInfo.avatarPath : "file://" + SystemInfo.avatarPath) : ""
    property bool powerMenuOpen: false
    property bool inputActive: false
    property bool isPlayingIntro: true

    property real centerReveal: 0.0
    property real wingsReveal: 0.0

    function restoreFocus() {
        if (!rootLock.locked || lockScreenRoot.isUnlocking) return;
        if (lockScreenRoot.inputActive) {
            if (!passwordInput.activeFocus) {
                lockScreenRoot.focus = true;
                lockScreenRoot.forceActiveFocus();
                passwordInput.focus = true;
                passwordInput.forceInputFocus();
            }
        } else {
            if (!lockScreenRoot.activeFocus) {
                lockScreenRoot.focus = true;
                lockScreenRoot.forceActiveFocus();
            }
        }
    }

    onActiveFocusChanged: {
        if (!activeFocus && rootLock.locked && !isUnlocking) {
            Qt.callLater(lockScreenRoot.restoreFocus);
        }
    }

    Keys.onPressed: (event) => {
        if (!lockScreenRoot.isPlayingIntro && !lockScreenRoot.isUnlocking) {
            if (!lockScreenRoot.inputActive) {
                if (event.key !== Qt.Key_Escape) {
                    lockScreenRoot.inputActive = true;
                    lockScreenRoot.restoreFocus();
                    if (event.text.length > 0 && event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter && event.key !== Qt.Key_Tab && event.key !== Qt.Key_Backspace) {
                        passwordInput.insertText(event.text);
                    }
                    event.accepted = true;
                }
            } else {
                lockScreenRoot.restoreFocus();
                if (event.key === Qt.Key_Escape) {
                    if (lockScreenRoot.powerMenuOpen) {
                        lockScreenRoot.powerMenuOpen = false;
                    } else {
                        lockScreenRoot.inputActive = false;
                    }
                    passwordInput.clear();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    if (passwordInput.text.length > 0 && pam.responseRequired && !lockUI.authenticating) {
                        lockUI.authenticating = true;
                        lockUI.statusText = I18n.t("lock.status.authenticating");
                        lockUI.failed = false;
                        pam.respond(passwordInput.text);
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    event.accepted = true;
                } else if (event.text.length > 0 && event.key !== Qt.Key_Backspace) {
                    passwordInput.insertText(event.text);
                    event.accepted = true;
                }
            }
        }
    }

    SequentialAnimation {
        id: openDashboardAnim
        running: false
        NumberAnimation {
            target: lockScreenRoot
            property: "centerReveal"
            to: 1.0
            duration: 180
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
        NumberAnimation {
            target: lockScreenRoot
            property: "wingsReveal"
            to: 1.0
            duration: 220
            easing.type: Easing.OutBack
            easing.overshoot: 1.12
        }
    }

    ParallelAnimation {
        id: closeDashboardAnim
        running: false
        NumberAnimation {
            target: lockScreenRoot
            property: "wingsReveal"
            to: 0.0
            duration: 110
            easing.type: Easing.InQuad
        }
        NumberAnimation {
            target: lockScreenRoot
            property: "centerReveal"
            to: 0.0
            duration: 100
            easing.type: Easing.InQuad
        }
    }

    SequentialAnimation {
        id: unlockSequence
        running: false

        ScriptAction {
            script: {
                lockScreenRoot.powerMenuOpen = false;
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: lockScreenRoot
                property: "wingsReveal"
                to: 0.0
                duration: 130
                easing.type: Easing.InQuad
            }
        }

        ParallelAnimation {
            NumberAnimation {
                target: lockScreenRoot
                property: "foldScaleX"
                to: 0.0
                duration: 220
                easing.type: Easing.InBack
                easing.overshoot: 1.3
            }
            NumberAnimation {
                target: lockScreenRoot
                property: "foldScaleY"
                to: 0.0
                duration: 220
                easing.type: Easing.InBack
                easing.overshoot: 1.3
            }
            NumberAnimation {
                target: lockScreenRoot
                property: "centerReveal"
                to: 0.0
                duration: 200
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: lockScreenRoot
                property: "contentReveal"
                to: 0.0
                duration: 220
                easing.type: Easing.InQuad
            }
            NumberAnimation {
                target: lockScreenRoot
                property: "panelReveal"
                to: 0.0
                duration: 250
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: lockScreenRoot
                property: "mainOpacity"
                to: 0.0
                duration: 250
                easing.type: Easing.InQuad
            }
        }

        ScriptAction {
            script: {
                lockController.completeUnlock();
            }
        }
    }

    // Simple's password is always there: it never folds away
    SequentialAnimation {
        id: simpleUnlock
        ScriptAction { script: lockScreenRoot.powerMenuOpen = false }
        NumberAnimation { target: lockScreenRoot; property: "simpleSlide"; to: 1.0; duration: 520; easing.type: Easing.InOutCubic }
        ScriptAction { script: lockController.completeUnlock() }
    }

    onInputActiveChanged: {
        if (lockScreenRoot.isUnlocking) return;
        if (simple) {
            if (!inputActive && !isPlayingIntro) inputActive = true;
            lockScreenRoot.restoreFocus();
            return;
        }
        if (transitionEnabled) {
            if (inputActive) dashboard.motion.open();
            else dashboard.motion.close();
            powerMenuOpen = false;
            lockScreenRoot.restoreFocus();
            return;
        }
        if (inputActive) {
            closeDashboardAnim.stop();
            openDashboardAnim.restart();
            lockScreenRoot.restoreFocus();
        } else {
            openDashboardAnim.stop();
            closeDashboardAnim.restart();
            powerMenuOpen = false;
            lockScreenRoot.restoreFocus();
        }
    }

    property real panelReveal: 0.0
    property real contentReveal: 0.0
    property real mainOpacity: 1.0

    Timer {
        id: introStartDelayTimer
        interval: 100
        repeat: false
        onTriggered: {
            if (lockScreenRoot.isPlayingIntro && !introSequence.running) {
                introSequence.start();
            }
        }
    }

    Component.onCompleted: {
        lockScreenRoot.restoreFocus();
        if (freezeWallpaperView.status === Image.Ready) {
            introSequence.start();
        } else {
            introStartDelayTimer.start();
        }
    }

    Connections {
        target: rootLock
        function onLockedChanged() {
            if (rootLock.locked) {
                lockScreenRoot.restoreFocus();
            }
        }
    }

    Connections {
        target: surface
        function onVisibleChanged() {
            if (surface.visible && rootLock.locked && !lockScreenRoot.isUnlocking) {
                lockScreenRoot.restoreFocus();
            }
        }
    }

    Connections {
        target: root
        function onResumeRevisionChanged() {
            if (rootLock.locked && !lockScreenRoot.isUnlocking) {
                lockScreenRoot.restoreFocus();
                if (typeof clockModule !== "undefined") {
                    clockModule.currentTime = (typeof DateTime !== "undefined" && DateTime.now) ? DateTime.now : new Date();
                }
            }
        }
    }

    Timer {
        id: idleTimer
        interval: 15000
        running: lockScreenRoot.inputActive && passwordInput.text.length === 0
        repeat: false
        onTriggered: {
            lockScreenRoot.inputActive = false;
            lockScreenRoot.restoreFocus();
        }
    }

    LockBackdrop {
        id: backdrop
        screenRoot: lockScreenRoot
    }

    SequentialAnimation {
        id: introSequence

        ParallelAnimation {
            NumberAnimation {
                target: lockScreenRoot
                property: "panelReveal"
                from: 0.0
                to: 1.0
                duration: 600
                easing.type: Easing.Linear
            }

            SequentialAnimation {
                PauseAnimation { duration: 460 }
                NumberAnimation {
                    target: lockScreenRoot
                    property: "contentReveal"
                    from: 0.0
                    to: 1.0
                    duration: 140
                    easing.type: Easing.OutCubic
                }
            }
        }

        PropertyAction { target: lockScreenRoot; property: "isPlayingIntro"; value: false }
        ScriptAction {
            script: {
                if (lockScreenRoot.simple) lockScreenRoot.inputActive = true;
                lockScreenRoot.restoreFocus();
            }
        }
    }

    Item {
        id: rootContent
        anchors.fill: parent
        z: 20
        opacity: lockScreenRoot.mainOpacity
        transform: Translate { y: -lockScreenRoot.height * lockScreenRoot.slide }

        LockPasswordElement { id: livePassword; ctx: lockScreenRoot; visible: parent !== rootContent }

        MouseArea {
            anchors.fill: parent
            preventStealing: true
            enabled: !lockScreenRoot.isPlayingIntro && !lockScreenRoot.isUnlocking
            onPressed: {
                lockScreenRoot.restoreFocus();
            }
            onClicked: {
                if (lockScreenRoot.powerMenuOpen) lockScreenRoot.powerMenuOpen = false;
                if (!lockScreenRoot.inputActive) {
                    lockScreenRoot.inputActive = true;
                }
                lockScreenRoot.restoreFocus();
            }
        }

        Item {
            anchors.fill: parent
            opacity: lockScreenRoot.contentReveal
            transform: Translate { y: lockScreenRoot.s(20) * (1.0 - lockScreenRoot.contentReveal) }


            LockClock {
                id: clockModule
                screenRoot: lockScreenRoot
                store: layoutStore
            }

            LockDashboard {
                id: dashboard
                visible: !lockScreenRoot.simple
                screenRoot: lockScreenRoot
                store: layoutStore
                passwordItem: lockScreenRoot.simple ? null : livePassword
                passwordHome: rootContent
            }

            // Simple: the profile picture, the name in its frame and the password, a little below the middle
            Column {
                id: simplePrompt
                visible: lockScreenRoot.simple
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height * 0.6 - height / 2
                spacing: lockScreenRoot.s(14)
                LockAvatarElement {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: lockScreenRoot.s(96); height: width
                    ctx: lockScreenRoot
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: simpleName.implicitWidth + lockScreenRoot.s(32); height: lockScreenRoot.s(36)
                    radius: height / 2
                    color: Qt.alpha(ThemeBackend.surface0, 0.8)
                    border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.12)
                    Text {
                        id: simpleName
                        anchors.centerIn: parent
                        text: lockScreenRoot.currentUser
                        font.family: ThemeBackend.fontFamily; font.pixelSize: lockScreenRoot.s(16); font.bold: true
                        color: ThemeBackend.text
                    }
                }
                Item {
                    id: simpleField
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: lockScreenRoot.s(300); height: lockScreenRoot.s(46)
                }
            }
            Binding { when: lockScreenRoot.simple; target: livePassword; property: "parent"; value: simpleField }
            Binding { when: lockScreenRoot.simple; target: livePassword; property: "width"; value: simpleField.width }
            Binding { when: lockScreenRoot.simple; target: livePassword; property: "height"; value: simpleField.height }

            LockPowerControls {
                screenRoot: lockScreenRoot
            }
    }
    }
}
