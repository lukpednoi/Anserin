import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../reusables"
import "../../"

Item {
    id: root

    property int requestedLayoutTemplate: 1
    property bool isActiveTab: typeof isCurrentTarget !== "undefined" ? isCurrentTarget : true
    property string iconFont: "Font Awesome 6 Free Solid"
    property string safeActiveEdge: typeof activeEdge !== "undefined" ? activeEdge : "left"

    function s(val) {
        return typeof scaleFunc === "function" ? scaleFunc(val) : val;
    }

    property real baseW: s(380)
    property real baseL: s(330)

    property real preferredWidth: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseL + 50 : baseW
    property real preferredExtraLength: (root.safeActiveEdge === "bottom" || root.safeActiveEdge === "top") ? baseW : baseL

    property real counterRotation: {
        if (root.safeActiveEdge === "right") return 180;
        if (root.safeActiveEdge === "bottom") return 90;
        if (root.safeActiveEdge === "top") return -90;
        return 0;
    }

    function alpha(color, a) { return Qt.rgba(color.r, color.g, color.b, a); }

    // Shared with every other Timer view (TimerState), so they all show the same time.
    readonly property var stateCache: TimerState
    readonly property var swLapData: TimerState.swLapData

    function saveFullState() { TimerState.saveFullState(); }
    function updateExportedState() { TimerState.updateExportedState(); }
    Component.onCompleted: TimerState.ensureLoaded()

    function notify(title, message, icon) { TimerState.notify(title, message, icon); }

    function toggleActiveTabState() {
        if (!root.isActiveTab || root.isEditingTime) return;
        TimerState.toggleMode();
    }

    property bool isTimerRunning: stateCache.timerTargetEpoch > 0
    property bool isTimerIdle: !isTimerRunning && stateCache.timerRemainingMs === stateCache.timerPresetMs
    property bool isEditingTime: stateSelector.visible && stateSelector.isEditing

    property bool widgetVisible: parent !== null && parent.visible !== undefined ? parent.visible : true
    readonly property bool anyTimerActive: TimerState.anyTimerActive

    property var interceptedShortcuts: {
        let arr = ["Return", "Enter"];
        if (root.isEditingTime) {
            arr.push("Left", "Right", "Up", "Down");
        } else if (stateCache.activeMode === 0 && isTimerIdle) {
            arr.push("Left", "Right", "Up", "Down");
        }
        return arr;
    }

    Shortcut { enabled: root.isActiveTab && !root.isEditingTime; sequence: "Return"; onActivated: root.toggleActiveTabState() }
    Shortcut { enabled: root.isActiveTab && !root.isEditingTime; sequence: "Enter"; onActivated: root.toggleActiveTabState() }

    function formatTime(ms, includeMs) { return TimerState.formatTime(ms, includeMs); }

    Item {
        id: orientedRoot
        anchors.centerIn: parent
        width: (root.counterRotation % 180 !== 0) ? parent.height : parent.width
        height: (root.counterRotation % 180 !== 0) ? parent.width : parent.height
        rotation: root.counterRotation
        clip: true

        Rectangle {
            anchors.fill: parent
            color: (tileGlass1.active ? "transparent" : ThemeBackend.mantle)
            GlassFill { id: tileGlass1; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
            radius: ThemeBackend.borderRadius
            z: -1
        }

        Rectangle {
            id: tabBar
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.topMargin: root.s(12)
            width: root.s(270)
            height: root.s(36)
            radius: ThemeBackend.borderRadius
            color: (tileGlass2.active ? "transparent" : ThemeBackend.surface0)
            GlassFill { id: tileGlass2; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
            border.width: 1
            border.color: ThemeBackend.surface1
            z: 10

            Rectangle {
                id: tabActiveHighlight
                y: root.s(2)
                height: root.s(32)
                radius: ThemeBackend.borderRadius
                color: ThemeBackend.mauve
                z: 0

                property int prevIdx: 0
                property int curIdx: stateCache.activeMode

                onCurIdxChanged: {
                    if (curIdx > prevIdx) { rightAnim.duration = 200; leftAnim.duration = 350; }
                    else if (curIdx < prevIdx) { leftAnim.duration = 200; rightAnim.duration = 350; }
                    prevIdx = curIdx;
                }

                property real stepSize: (parent.width - root.s(4)) / 3
                property real targetLeft: root.s(2) + (curIdx * stepSize)
                property real targetRight: targetLeft + stepSize

                property real actualLeft: targetLeft
                property real actualRight: targetRight

                Behavior on actualLeft { NumberAnimation { id: leftAnim; duration: 250; easing.type: Easing.OutExpo } }
                Behavior on actualRight { NumberAnimation { id: rightAnim; duration: 250; easing.type: Easing.OutExpo } }

                x: actualLeft
                width: actualRight - actualLeft
            }

            Row {
                anchors.fill: parent
                anchors.margins: root.s(2)
                z: 1

                Repeater {
                    model: [
                        I18n.t("quickactions.timer.tabs.timer"),
                        I18n.t("quickactions.timer.tabs.stopwatch"),
                        I18n.t("quickactions.timer.tabs.pomodoro")
                    ]
                    Item {
                        width: (tabBar.width - root.s(4)) / 3
                        height: parent.height

                        Text {
                            anchors.centerIn: parent
                            text: modelData
                            font.family: ThemeBackend.fontFamily
                            font.bold: true
                            font.pixelSize: root.s(12)
                            color: stateCache.activeMode === index ? ThemeBackend.mantle : ThemeBackend.text
                            Behavior on color { ColorAnimation { duration: 250 } }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/clickbutton/click.wav");
                                stateCache.activeMode = index;
                                root.saveFullState();
                            }
                        }
                    }
                }
            }
        }

        Item {
            anchors.top: tabBar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: root.s(10)

            Item {
                id: standardTimerView
                anchors.fill: parent
                visible: stateCache.activeMode === 0
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                Item {
                    anchors.top: parent.top
                    anchors.bottom: timerControlsRow.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    Text {
                        anchors.centerIn: parent
                        text: root.formatTime(stateCache.timerRemainingMs, false)
                        font.family: ThemeBackend.fontFamily
                        font.weight: Font.Black
                        font.pixelSize: root.s(68)
                        color: stateCache.timerRemainingMs === 0 && !root.isTimerRunning ? ThemeBackend.mauve : ThemeBackend.text
                        visible: !root.isTimerIdle
                    }

                    TimeSelector {
                        id: stateSelector
                        clickSound: "reusables/clickbutton/click.wav"
                        anchors.centerIn: parent
                        visible: root.isTimerIdle
                        valueMs: stateCache.timerPresetMs
                        isActive: root.isActiveTab && stateCache.activeMode === 0 && root.isTimerIdle
                        isWidgetVisible: root.widgetVisible
                        iconFont: root.iconFont
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: root.alpha(ThemeBackend.surface1, 0.5)
                        activeTextColor: ThemeBackend.mantle
                        scaleMultiplier: 1.4
                        onValueChanged: function(newMs) {
                            stateCache.timerPresetMs = newMs;
                            stateCache.timerRemainingMs = newMs;
                            root.saveFullState();
                        }
                    }
                }

                Item {
                    id: timerControlsRow
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.s(10)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: root.s(64)

                    IconButton {
                        size: root.s(50)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "\uF0E2"
                        iconFontSize: root.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        anchors.right: timerPlayBtn.left
                        anchors.rightMargin: root.s(20)
                        anchors.verticalCenter: timerPlayBtn.verticalCenter
                        onClicked: {
                            if (!root.isTimerIdle) {
                                stateCache.timerTargetEpoch = 0;
                                stateCache.timerRemainingMs = stateCache.timerPresetMs;
                            } else {
                                stateCache.timerPresetMs = 0;
                                stateCache.timerRemainingMs = 0;
                            }
                            root.saveFullState();
                            root.updateExportedState();
                        }
                    }

                    IconButton {
                        id: timerPlayBtn
                        size: root.s(64)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: root.isTimerRunning ? "\uF04C" : "\uF04B"
                        iconFontSize: root.s(24)
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.mantle
                        anchors.centerIn: parent
                        onClicked: root.toggleActiveTabState()
                    }
                }
            }

            Item {
                id: stopwatchView
                anchors.fill: parent
                visible: stateCache.activeMode === 1
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                property bool isRunning: stateCache.swStartEpoch > 0
                readonly property real currentDisplayMs: TimerState.swDisplayMs

                Item {
                    id: swContentArea
                    anchors.top: parent.top
                    anchors.bottom: swControlsRow.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    Column {
                        anchors.centerIn: parent
                        spacing: root.s(15)

                        Text {
                            id: swTimeText
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.formatTime(stopwatchView.currentDisplayMs, true)
                            font.family: ThemeBackend.fontFamily
                            font.weight: Font.Black
                            font.pixelSize: root.s(52)
                            color: ThemeBackend.text
                        }

                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: root.s(270)
                            height: root.swLapData.length > 0 ? Math.min(root.s(130), swContentArea.height - swTimeText.height - root.s(15)) : 0
                            visible: root.swLapData.length > 0
                            color: "transparent"
                            clip: true

                            ListView {
                                id: lapList
                                anchors.fill: parent
                                model: root.swLapData.length
                                spacing: root.s(6)

                                delegate: Rectangle {
                                    width: lapList.width
                                    height: root.s(32)
                                    radius: ThemeBackend.borderRadius
                                    color: (tileGlass3.active ? "transparent" : ThemeBackend.surface0)
                                    GlassFill { id: tileGlass3; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
                                    border.width: 1
                                    border.color: ThemeBackend.surface1

                                    property int trueIdx: root.swLapData.length - 1 - index
                                    property var lapItem: root.swLapData[trueIdx]

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: root.s(15); anchors.rightMargin: root.s(15)
                                        Text { text: I18n.t("quickactions.timer.stopwatch.lap", { number: trueIdx + 1 }); color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12); font.bold: true; Layout.fillWidth: true }
                                        Text { text: lapItem ? "+" + root.formatTime(lapItem.diff, true) : ""; color: ThemeBackend.mauve; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12) }
                                        Text { text: lapItem ? root.formatTime(lapItem.total, true) : ""; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12); font.bold: true; Layout.alignment: Qt.AlignRight }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: swControlsRow
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.s(10)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: root.s(64)

                    IconButton {
                        size: root.s(50)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: stopwatchView.isRunning ? "\uF024" : "\uF0E2"
                        iconFontSize: root.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        anchors.right: swPlayBtn.left
                        anchors.rightMargin: root.s(20)
                        anchors.verticalCenter: swPlayBtn.verticalCenter
                        onClicked: {
                            if (stopwatchView.isRunning) {
                                let nowMs = stopwatchView.currentDisplayMs;
                                let lastMs = root.swLapData.length > 0 ? root.swLapData[root.swLapData.length - 1].total : 0;
                                let temp = root.swLapData.slice();
                                temp.push({ total: nowMs, diff: nowMs - lastMs });
                                TimerState.swLapData = temp;
                            } else {
                                stateCache.swStartEpoch = 0;
                                stateCache.swAccumulatedMs = 0;
                                TimerState.swLapData = [];
                                TimerState.swDisplayMs = 0;
                            }
                            root.saveFullState();
                            root.updateExportedState();
                        }
                    }

                    IconButton {
                        id: swPlayBtn
                        size: root.s(64)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: stopwatchView.isRunning ? "\uF04C" : "\uF04B"
                        iconFontSize: root.s(24)
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.mantle
                        anchors.centerIn: parent
                        onClicked: root.toggleActiveTabState()
                    }
                }
            }

            Item {
                id: pomodoroView
                anchors.fill: parent
                visible: stateCache.activeMode === 2
                opacity: visible ? 1.0 : 0.0
                Behavior on opacity { NumberAnimation { duration: 250 } }

                property bool isRunning: stateCache.pomoTargetEpoch > 0
                property bool showSettings: false

                function getPhaseColor() {
                    if (stateCache.pomoState === 0) return ThemeBackend.mauve;
                    if (stateCache.pomoState === 1) return Qt.rgba(166/255, 227/255, 161/255, 1.0);
                    return ThemeBackend.surface1;
                }

                function getPhaseLabel() {
                    if (stateCache.pomoState === 0) return I18n.t("quickactions.timer.pomodoro.phases.focus");
                    if (stateCache.pomoState === 1) return I18n.t("quickactions.timer.pomodoro.phases.short_break");
                    return I18n.t("quickactions.timer.pomodoro.phases.long_break");
                }

                function handleSessionComplete() { TimerState.handleSessionComplete(); }

                Item {
                    anchors.top: parent.top
                    anchors.bottom: pomoControlsRow.top
                    anchors.left: parent.left
                    anchors.right: parent.right

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: root.s(10)
                        visible: !pomodoroView.showSettings

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: pomodoroView.getPhaseLabel() + " (" + stateCache.pomoSessionsCount + "/" + stateCache.pomoTargetSessions + ")"
                            font.family: ThemeBackend.fontFamily; font.bold: true; font.pixelSize: root.s(14)
                            color: pomodoroView.getPhaseColor()
                        }

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.formatTime(stateCache.pomoRemainingMs, false)
                            font.family: ThemeBackend.fontFamily; font.weight: Font.Black; font.pixelSize: root.s(68)
                            color: ThemeBackend.text
                        }
                    }

                    Rectangle {
                        anchors.centerIn: parent
                        width: root.s(270)
                        height: root.s(160)
                        radius: ThemeBackend.borderRadius
                        color: (tileGlass4.active ? "transparent" : ThemeBackend.surface0)
                        GlassFill { id: tileGlass4; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
                        border.width: 1
                        border.color: ThemeBackend.surface1
                        visible: pomodoroView.showSettings

                        Column {
                            anchors.centerIn: parent
                            spacing: root.s(12)

                            Repeater {
                                model: [
                                    { label: I18n.t("quickactions.timer.pomodoro.settings.work"), target: "pomoWorkLimit", step: 5, min: 5, max: 60 },
                                    { label: I18n.t("quickactions.timer.pomodoro.settings.short_break"), target: "pomoShortBreakLimit", step: 1, min: 1, max: 15 },
                                    { label: I18n.t("quickactions.timer.pomodoro.settings.long_break"), target: "pomoLongBreakLimit", step: 5, min: 5, max: 45 },
                                    { label: I18n.t("quickactions.timer.pomodoro.settings.sessions"), target: "pomoTargetSessions", step: 1, min: 1, max: 10 }
                                ]
                                RowLayout {
                                    width: root.s(230)
                                    Text { text: modelData.label; color: ThemeBackend.subtext0; font.family: ThemeBackend.fontFamily; font.pixelSize: root.s(12); Layout.fillWidth: true }
                                    IconButton {
                                        size: root.s(24)
                                        cornerRadius: ThemeBackend.borderRadius
                                        buttonIcon: "-"
                                        iconFontSize: root.s(14)
                                        accentColor: ThemeBackend.surface1
                                        textColor: ThemeBackend.text
                                        onClicked: {
                                            stateCache[modelData.target] = Math.max(modelData.min, stateCache[modelData.target] - modelData.step);
                                            root.saveFullState();
                                        }
                                    }
                                    Text { text: stateCache[modelData.target]; color: ThemeBackend.text; font.family: ThemeBackend.fontFamily; font.bold: true; font.pixelSize: root.s(14); Layout.minimumWidth: root.s(24); horizontalAlignment: Text.AlignHCenter }
                                    IconButton {
                                        size: root.s(24)
                                        cornerRadius: ThemeBackend.borderRadius
                                        buttonIcon: "+"
                                        iconFontSize: root.s(14)
                                        accentColor: ThemeBackend.surface1
                                        textColor: ThemeBackend.text
                                        onClicked: {
                                            stateCache[modelData.target] = Math.min(modelData.max, stateCache[modelData.target] + modelData.step);
                                            root.saveFullState();
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: pomoControlsRow
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.s(10)
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: root.s(64)

                    IconButton {
                        size: root.s(50)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "\uF013"
                        iconFontSize: root.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: pomodoroView.showSettings ? ThemeBackend.mauve : ThemeBackend.text
                        anchors.right: pomoPlayBtn.left
                        anchors.rightMargin: root.s(20)
                        anchors.verticalCenter: pomoPlayBtn.verticalCenter
                        onClicked: pomodoroView.showSettings = !pomodoroView.showSettings
                    }

                    IconButton {
                        id: pomoPlayBtn
                        size: root.s(64)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: pomodoroView.isRunning ? "\uF04C" : "\uF04B"
                        iconFontSize: root.s(24)
                        accentColor: pomodoroView.getPhaseColor()
                        textColor: ThemeBackend.mantle
                        anchors.centerIn: parent
                        onClicked: {
                            if (pomodoroView.showSettings) pomodoroView.showSettings = false;
                            root.toggleActiveTabState();
                        }
                    }

                    IconButton {
                        size: root.s(50)
                        cornerRadius: ThemeBackend.borderRadius
                        buttonIcon: "\uF051"
                        iconFontSize: root.s(16)
                        accentColor: ThemeBackend.surface0
                        textColor: ThemeBackend.text
                        anchors.left: pomoPlayBtn.right
                        anchors.leftMargin: root.s(20)
                        anchors.verticalCenter: pomoPlayBtn.verticalCenter
                        onClicked: {
                            stateCache.pomoTargetEpoch = 0;
                            let phase = stateCache.pomoState;
                            if (phase === 0) {
                                root.notify(
                                    I18n.t("quickactions.timer.notification.pomo_skipped_title"),
                                    I18n.t("quickactions.timer.notification.pomo_skipped_focus_body"),
                                    "media-skip-forward"
                                );
                            } else {
                                root.notify(
                                    I18n.t("quickactions.timer.notification.pomo_skipped_title"),
                                    I18n.t("quickactions.timer.notification.pomo_skipped_break_body"),
                                    "media-skip-forward"
                                );
                            }
                            pomodoroView.handleSessionComplete();
                        }
                    }
                }
            }
        }
    }
}
