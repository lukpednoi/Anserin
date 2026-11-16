import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../"
import "../reusables"
import "../reusables/guide"
import "./shared"

Item {
    id: idleTabRoot
    required property var rootObj
    required property int tabIndex

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    // the page's logic lives in IdleLogic.qml (shared with the Control Center's board); the names below keep
    // the page reading it as before
    IdleLogic { id: logic; rootObj: idleTabRoot.rootObj }
    property alias expandedActionMap: logic.expandedActionMap
    property alias idleEnabled: logic.idleEnabled
    property alias manualInhibit: logic.manualInhibit
    property alias actionIdsList: logic.actionIdsList
    function toggleActionExpanded(id) { return logic.toggleActionExpanded(id); }
    function isCustomAction(actId) { return logic.isCustomAction(actId); }
    function getActionData(actId) { return logic.getActionData(actId); }
    function getActionTimeout(act) { return logic.getActionTimeout(act); }
    function isActionPipelineValid(actionObj) { return logic.isActionPipelineValid(actionObj); }
    function getActionTitle(act, actId) { return logic.getActionTitle(act, actId); }
    function getActionDescription(act, actId) { return logic.getActionDescription(act, actId); }
    function getDefaultResumeCommand(actId) { return logic.getDefaultResumeCommand(actId); }
    function deleteCustomAction(actionId) { return logic.deleteCustomAction(actionId); }
    function createNewAction() { return logic.createNewAction(); }
    function updateActionProp(actionId, isCustom, propKey, value) { return logic.updateActionProp(actionId, isCustom, propKey, value); }
    function updateRootSetting(propKey, value) { return logic.updateRootSetting(propKey, value); }






















    Component {
        id: actionCardDelegate
        SettingsRow {
            id: actionCard
            required property var modelData
            required property int index

            rootObj: idleTabRoot.rootObj
            Layout.fillWidth: true

            property string actId: typeof modelData === "string" ? modelData : (modelData ? (modelData.id || "") : "")
            property bool isCustomAct: idleTabRoot.isCustomAction(actId)
            property var actData: idleTabRoot.getActionData(actId)

            property bool isExpanded: !!idleTabRoot.expandedActionMap[actId]
            property int holdOpenCount: 0
            readonly property bool isCardOpen: isExpanded || holdOpenCount > 0
            readonly property bool isOpen: isCardOpen

            function holdOpen() {
                holdOpenCount++;
            }
            function releaseOpen() {
                if (holdOpenCount > 0) holdOpenCount--;
            }

            property bool actEnabled: actData && actData.enabled !== undefined ? actData.enabled : true
            property int actTimeout: idleTabRoot.getActionTimeout(actData)
            property int actWarningTimeout: actData && actData.warningTimeout !== undefined && actData.warningTimeout !== null ? Math.max(0, Number(actData.warningTimeout)) : 0
            property bool actRespectInhibitors: actData && actData.respectInhibitors !== undefined ? actData.respectInhibitors : true
            property bool actMprisInhibit: actData && actData.mprisInhibit !== undefined ? actData.mprisInhibit : true
            property string actCmd: actData ? (actData.command || "") : ""
            property string actWarningCmd: actData ? (actData.warningCommand || "") : ""
            property string actBeforeCmd: actData ? (actData.beforeCommand || "") : ""
            property string actResumeCmd: actData ? (actData.resumeCommand || "") : ""
            property string actTitle: idleTabRoot.getActionTitle(actData, actId)
            property string actDesc: idleTabRoot.getActionDescription(actData, actId)
            property bool isPipelineValid: idleTabRoot.isActionPipelineValid(actData)

            readonly property string actIcon: {
                if (actId === "dim") return "󰃛";
                if (actId === "lock") return "󰌾";
                if (actId === "dpms") return "󰍹";
                if (actId === "suspend") return "󰒲";
                return "󰆍";
            }

            settingId: "idle_action_" + actId
            searchKeywords: actId + " idle timeout power action"
            title: isCustomAct ? "" : actTitle
            description: isCustomAct ? "" : actDesc
            icon: isCustomAct ? "" : actIcon
            showIcon: !isCustomAct
            iconSize: 32
            iconFontSize: 16
            iconAccentColor: ThemeBackend.surface0
            iconTextColor: "#ffffff"

            baseColor: Qt.alpha(ThemeBackend.surface0, 0.4)
            borderColor: isPipelineValid ? Qt.alpha(ThemeBackend.surface1, 0.4) : Qt.alpha(ThemeBackend.red, 0.6)
            borderWidth: 1
            horizontalPadding: rootObj.s(12)
            verticalPadding: rootObj.s(10)
            spacing: rootObj.s(12)
            innerSpacing: actionCard.isCardOpen ? rootObj.s(12) : 0
            Behavior on innerSpacing { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
            bottomSpacing: 0

            customLeftContent: actionCard.isCustomAct ? customLeftRowComponent : null

            Component {
                id: customLeftRowComponent
                RowLayout {
                    Layout.fillWidth: true
                    spacing: rootObj.s(8)

                    Input {
                        Layout.preferredWidth: rootObj.s(160)
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        text: (actionCard.actData && actionCard.actData.name) ? actionCard.actData.name : ""
                        placeholderText: I18n.t("guide.idle.action_name_placeholder", "Action Name")
                        fontPixelSize: rootObj.s(12)
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        onAccepted: function(t) {
                            let val = (typeof t === "string") ? t : text;
                            idleTabRoot.updateActionProp(actionCard.actId, true, "name", val);
                        }
                    }

                    Input {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        implicitHeight: rootObj.s(32)
                        text: actionCard.actCmd
                        placeholderText: I18n.t("guide.idle.command_placeholder", "Command to run")
                        baseColor: ThemeBackend.surface0
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.text
                        subTextColor: ThemeBackend.subtext0
                        borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(11)
                        onAccepted: function(t) {
                            let val = (typeof t === "string") ? t : text;
                            idleTabRoot.updateActionProp(actionCard.actId, true, "command", val);
                        }
                    }
                }
            }

            titleBadge: Component {
                Rectangle {
                    visible: !actionCard.isPipelineValid && actionCard.actEnabled
                    implicitWidth: invalidBadgeText.implicitWidth + rootObj.s(8)
                    implicitHeight: rootObj.s(18)
                    radius: rootObj.s(4)
                    color: Qt.alpha(ThemeBackend.red, 0.15)
                    border.color: Qt.alpha(ThemeBackend.red, 0.4)
                    border.width: 1

                    Text {
                        id: invalidBadgeText
                        anchors.centerIn: parent
                        text: I18n.t("guide.idle.order_violation", "Order")
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(10)
                        font.bold: true
                        color: ThemeBackend.red
                    }
                }
            }

            Timer {
                id: cardDebounceTimer
                interval: 200
                repeat: false
                property var callback: null
                onTriggered: {
                    if (callback) {
                        callback();
                        callback = null;
                    }
                }
            }

            function debounceAction(cb) {
                cardDebounceTimer.callback = cb;
                cardDebounceTimer.restart();
            }

            NumberSelector {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: rootObj.s(115)
                implicitHeight: rootObj.s(32)
                from: 10
                to: 7200
                stepSize: 10
                decimals: 0
                suffix: "s"
                value: actionCard.actTimeout
                baseColor: ThemeBackend.surface0
                accentColor: ThemeBackend.mauve
                buttonColor: ThemeBackend.surface1
                buttonTextColor: ThemeBackend.text
                textColor: ThemeBackend.text
                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                cornerRadius: ThemeBackend.borderRadius
                fontFamily: ThemeBackend.fontFamily
                fontPixelSize: rootObj.s(11)
                onValueChanged: function(val) {
                    let num = (typeof val === "number" && !isNaN(val)) ? val : value;
                    let rounded = Math.round(num);
                    if (!isNaN(rounded) && rounded >= 10 && rounded <= 7200 && actionCard.actTimeout !== rounded) {
                        let targetId = actionCard.actId;
                        let isCustom = actionCard.isCustomAct;
                        actionCard.debounceAction(function() {
                            idleTabRoot.updateActionProp(targetId, isCustom, "timeout", rounded);
                        });
                    }
                }
            }

            Toggle {
                Layout.alignment: Qt.AlignVCenter
                checked: actionCard.actEnabled
                accentColor: ThemeBackend.mauve
                baseColor: ThemeBackend.surface1
                handleColor: ThemeBackend.crust
                handleOffColor: ThemeBackend.text
                onToggled: function(c) {
                    idleTabRoot.updateActionProp(actionCard.actId, actionCard.isCustomAct, "enabled", c);
                }
            }

            DeleteButton {
                visible: actionCard.isCustomAct
                Layout.alignment: Qt.AlignVCenter
                size: rootObj.s(28)
                cornerRadius: rootObj.s(8)
                iconFontSize: rootObj.s(14)
                onClicked: {
                    idleTabRoot.deleteCustomAction(actionCard.actId);
                }
            }

            FlipIcon {
                Layout.alignment: Qt.AlignVCenter
                size: rootObj.s(28)
                cornerRadius: rootObj.s(8)
                accentColor: ThemeBackend.surface0
                iconColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                autoToggle: false
                flipped: actionCard.isCardOpen
                onClicked: {
                    idleTabRoot.toggleActionExpanded(actionCard.actId);
                }
            }

            bottomContent: Item {
                id: expandableSettingsWrapper
                Layout.fillWidth: true
                readonly property bool isGroupSubWrapper: true
                readonly property var ownerGroup: actionCard
                clip: true
                visible: actionCard.isCardOpen || implicitHeight > 0
                opacity: actionCard.isCardOpen ? 1.0 : 0.0
                implicitHeight: actionCard.isCardOpen ? expandedInnerCol.implicitHeight : 0

                Behavior on opacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                Behavior on implicitHeight { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }

                ColumnLayout {
                    id: expandedInnerCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    spacing: rootObj.s(6)

                    SettingsRow {
                        rootObj: idleTabRoot.rootObj
                        settingId: "idle_" + actionCard.actId + "_respect_inhibitors"
                        searchKeywords: "respect inhibitors lock " + actionCard.actId
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰌿"
                        iconSize: 28
                        iconFontSize: 14
                        title: I18n.t("guide.idle.respect_inhibitors.title", "Respect App Inhibitors")
                        description: I18n.t("guide.idle.respect_inhibitors.desc", "Honor Wayland idle inhibitor locks from applications")
                        titlePixelSize: 12
                        descriptionPixelSize: 10
                        verticalPadding: rootObj.s(10)

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: actionCard.actRespectInhibitors
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                idleTabRoot.updateActionProp(actionCard.actId, actionCard.isCustomAct, "respectInhibitors", c);
                            }
                        }
                    }

                    SettingsRow {
                        rootObj: idleTabRoot.rootObj
                        settingId: "idle_" + actionCard.actId + "_mpris_inhibit"
                        searchKeywords: "mpris media audio video inhibit " + actionCard.actId
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰝚"
                        iconSize: 28
                        iconFontSize: 14
                        title: I18n.t("guide.idle.mpris_inhibit.title", "Inhibit on Media")
                        description: I18n.t("guide.idle.mpris_inhibit.desc", "Prevent idle trigger while MPRIS audio/video is playing")
                        titlePixelSize: 12
                        descriptionPixelSize: 10
                        verticalPadding: rootObj.s(10)

                        Toggle {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            checked: actionCard.actMprisInhibit
                            accentColor: ThemeBackend.mauve
                            baseColor: ThemeBackend.surface1
                            handleColor: ThemeBackend.crust
                            handleOffColor: ThemeBackend.text
                            onToggled: function(c) {
                                idleTabRoot.updateActionProp(actionCard.actId, actionCard.isCustomAct, "mprisInhibit", c);
                            }
                        }
                    }

                    SettingsRow {
                        rootObj: idleTabRoot.rootObj
                        settingId: "idle_" + actionCard.actId + "_warning_command"
                        searchKeywords: "warning command offset notify " + actionCard.actId
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰀪"
                        iconSize: 28
                        iconFontSize: 14
                        title: I18n.t("guide.idle.warning_command.title", "Warning Command")
                        description: I18n.t("guide.idle.warning_command.desc", "Offset and command to execute before action")
                        titlePixelSize: 12
                        descriptionPixelSize: 10
                        verticalPadding: rootObj.s(10)
                        controlSpacing: rootObj.s(6)

                        Input {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: rootObj.s(220)
                            implicitHeight: rootObj.s(30)
                            text: actionCard.actWarningCmd
                            placeholderText: I18n.t("guide.idle.warning_command.placeholder", "Warning command")
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            fontPixelSize: rootObj.s(11)
                            onAccepted: function(t) {
                                let val = (typeof t === "string") ? t : text;
                                idleTabRoot.updateActionProp(actionCard.actId, actionCard.isCustomAct, "warningCommand", val);
                            }
                        }

                        NumberSelector {
                            Layout.alignment: Qt.AlignVCenter
                            implicitWidth: rootObj.s(90)
                            implicitHeight: rootObj.s(30)
                            from: 0
                            to: Math.max(0, actionCard.actTimeout - 5)
                            stepSize: 5
                            decimals: 0
                            suffix: "s"
                            value: actionCard.actWarningTimeout
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            buttonColor: ThemeBackend.surface1
                            buttonTextColor: ThemeBackend.text
                            textColor: ThemeBackend.text
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            fontFamily: ThemeBackend.fontFamily
                            fontPixelSize: rootObj.s(11)
                            onValueChanged: function(val) {
                                let num = (typeof val === "number" && !isNaN(val)) ? val : value;
                                let rounded = Math.max(0, Math.round(num));
                                if (!isNaN(rounded) && actionCard.actWarningTimeout !== rounded) {
                                    let targetId = actionCard.actId;
                                    let isCustom = actionCard.isCustomAct;
                                    actionCard.debounceAction(function() {
                                        idleTabRoot.updateActionProp(targetId, isCustom, "warningTimeout", rounded);
                                    });
                                }
                            }
                        }
                    }

                    SettingsRow {
                        visible: actionCard.actId !== "suspend"
                        rootObj: idleTabRoot.rootObj
                        settingId: "idle_" + actionCard.actId + "_before_command"
                        searchKeywords: "before command trigger " + actionCard.actId
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰆍"
                        iconSize: 28
                        iconFontSize: 14
                        title: I18n.t("guide.idle.before_command.title", "Before Command")
                        description: I18n.t("guide.idle.before_command.desc", "Executed right before the action triggers")
                        titlePixelSize: 12
                        descriptionPixelSize: 10
                        verticalPadding: rootObj.s(10)

                        Input {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: rootObj.s(280)
                            implicitHeight: rootObj.s(30)
                            text: actionCard.actBeforeCmd
                            placeholderText: I18n.t("guide.idle.before_command.placeholder", "Before action command")
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            fontPixelSize: rootObj.s(11)
                            onAccepted: function(t) {
                                let val = (typeof t === "string") ? t : text;
                                idleTabRoot.updateActionProp(actionCard.actId, actionCard.isCustomAct, "beforeCommand", val);
                            }
                        }
                    }

                    SettingsRow {
                        visible: actionCard.actId !== "suspend"
                        rootObj: idleTabRoot.rootObj
                        settingId: "idle_" + actionCard.actId + "_resume_command"
                        searchKeywords: "resume command wake activity " + actionCard.actId
                        baseColor: Qt.alpha(ThemeBackend.surface1, 0.35)
                        icon: "󰑐"
                        iconSize: 28
                        iconFontSize: 14
                        title: I18n.t("guide.idle.resume_command.title", "Resume Command")
                        description: I18n.t("guide.idle.resume_command.desc", "Executed when user activity resumes")
                        titlePixelSize: 12
                        descriptionPixelSize: 10
                        verticalPadding: rootObj.s(10)

                        Input {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            implicitWidth: rootObj.s(280)
                            implicitHeight: rootObj.s(30)
                            text: actionCard.actResumeCmd
                            placeholderText: idleTabRoot.getDefaultResumeCommand(actionCard.actId)
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            fontPixelSize: rootObj.s(11)
                            onAccepted: function(t) {
                                let val = (typeof t === "string") ? t : text;
                                idleTabRoot.updateActionProp(actionCard.actId, actionCard.isCustomAct, "resumeCommand", val);
                            }
                        }
                    }
                }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(8)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(8)
        contentHeight: settingsCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            width: parent.width
            spacing: rootObj.s(6)

            SettingsRow {
                rootObj: idleTabRoot.rootObj
                settingId: "idle_enabled"
                searchKeywords: "idle enable system power sleep timeout"
                icon: "󰒲"
                title: I18n.t("guide.idle.enabled.title", "Enable Idle System")
                description: I18n.t("guide.idle.enabled.desc", "Activate power management and lock timeouts")

                Toggle {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: idleTabRoot.idleEnabled
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) { idleTabRoot.updateRootSetting("enabled", c); }
                }
            }

            SettingsRow {
                rootObj: idleTabRoot.rootObj
                settingId: "idle_manual_inhibit"
                searchKeywords: "do not disturb keep awake inhibit idle sleep"
                visible: idleTabRoot.idleEnabled
                icon: "󰅶"
                title: I18n.t("guide.idle.manual_inhibit.title", "Do Not Disturb (Keep Awake)")
                description: I18n.t("guide.idle.manual_inhibit.desc", "Manually prevent the system from idling")

                Toggle {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    checked: idleTabRoot.manualInhibit
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) { idleTabRoot.updateRootSetting("manualInhibit", c); }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: actionsBoxCol.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0
                visible: idleTabRoot.idleEnabled

                ColumnLayout {
                    id: actionsBoxCol
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: rootObj.s(12)
                    spacing: rootObj.s(10)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(12)

                        IconButton {
                            enabled: false
                            size: rootObj.s(32)
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            Layout.alignment: Qt.AlignVCenter
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰔛"
                            iconFontSize: rootObj.s(16)
                            accentColor: ThemeBackend.surface0
                            textColor: "#ffffff"
                        }

                        ColumnLayout {
                            Layout.alignment: Qt.AlignVCenter
                            spacing: rootObj.s(2)

                            Text {
                                text: I18n.t("guide.idle.actions_header.title", "Idle Timeout Objects")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(14)
                                color: ThemeBackend.text
                            }

                        }

                        Item {
                            Layout.fillWidth: true
                        }

                        IconButton {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            size: rootObj.s(32)
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            cornerRadius: rootObj.s(8)
                            buttonIcon: "󰐕"
                            iconFontSize: rootObj.s(14)
                            accentColor: ThemeBackend.surface0
                            textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                            onClicked: {
                                idleTabRoot.createNewAction();
                            }
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(8)

                        Repeater {
                            model: idleTabRoot.actionIdsList
                            delegate: actionCardDelegate
                        }
                    }

                }
            }
        }
    }
}
