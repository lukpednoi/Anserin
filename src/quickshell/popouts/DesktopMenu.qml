import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../reusables"
import "../singletons/widgetcontrols"
import "../"

PanelWindow {
    id: desktopMenuWindow
    readonly property int frameInset: ScreenEdges.inset(screen)
    margins { top: frameInset; bottom: frameInset; left: frameInset; right: frameInset }

    screen: DesktopMenuController.screen

    WlrLayershell.namespace: "desktopmenu"
    WlrLayershell.layer: WlrLayer.Bottom
    focusable: desktopMenuWindow.isVisible
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    onIsVisibleChanged: {
        if (isVisible) {
            rootContainer.forceActiveFocus();
        } else {
            openAnim.stop();
            closeAnim.restart();
        }
    }

    mask: Region {
        item: (desktopMenuWindow.isVisible || menuContainer.animProgress > 0.001) ? maskTarget : null
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) { return (typeof Scaler !== "undefined") ? Scaler.s(val) : val; }

    property bool isVisible: DesktopMenuController.isVisible
    property bool isWidgetMode: DesktopMenuController.mode === "widget"
    property real targetX: DesktopMenuController.targetX - frameInset
    property real targetY: DesktopMenuController.targetY - frameInset

    property int configRevision: 0

    Connections {
        target: DesktopMenuController

        function onMenuTriggered() {
            rootContainer.forceActiveFocus();
            closeAnim.stop();
            openAnim.stop();
            menuContainer.animProgress = 0.0;
            openAnim.restart();
        }
    }

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        ignoreUnknownSignals: true
        function onSettingsLoaded() {
            desktopMenuWindow.configRevision++;
        }
    }

    property real cornerRadius: {
        let dummy = configRevision;
        return (typeof ThemeBackend !== "undefined" && ThemeBackend.borderRadius !== undefined && ThemeBackend.borderRadius !== null)
            ? ThemeBackend.borderRadius
            : s(12);
    }

    property color menuBackgroundColor: {
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.base) {
            return ThemeBackend.base;
        }
        return "#1e1e2e";
    }

    property color buttonColor: {
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.surface0) {
            return ThemeBackend.surface0;
        }
        return "#313244";
    }

    property color primaryButtonColor: {
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.primary) {
            return ThemeBackend.primary;
        }
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.blue) {
            return ThemeBackend.blue;
        }
        return "#89b4fa";
    }

    property color primaryTextColor: {
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.base) {
            return ThemeBackend.base;
        }
        return "#1e1e2e";
    }

    property real menuWidth: s(170)
    property real menuHeight: contentCol.implicitHeight
    property real menuOffset: s(3)

    property real clampedX: {
        let w = menuWidth;
        let margin = s(8);
        let off = (targetX + w > desktopMenuWindow.width - margin) ? -menuOffset : menuOffset;
        if (targetX + w > desktopMenuWindow.width - margin) {
            return Math.max(margin, targetX - w + off);
        }
        return Math.max(margin, Math.min(desktopMenuWindow.width - w - margin, targetX + off));
    }

    property real clampedY: {
        let h = menuHeight;
        let margin = s(8);
        let off = (targetY + h > desktopMenuWindow.height - margin) ? -menuOffset : menuOffset;
        if (targetY + h > desktopMenuWindow.height - margin) {
            return Math.max(margin, targetY - h + off);
        }
        return Math.max(margin, Math.min(desktopMenuWindow.height - h - margin, targetY + off));
    }

    property bool alignRight: (targetX + menuWidth > desktopMenuWindow.width - s(8))

    visible: isVisible || menuContainer.animProgress > 0.001

    function openRedactor(selectedWidgetId) {
        DesktopMenuController.hide();
        let targetId = selectedWidgetId !== undefined ? String(selectedWidgetId) : "";
        let mon = (desktopMenuWindow.screen && desktopMenuWindow.screen.name) ? desktopMenuWindow.screen.name : ((DesktopMenuController.screen && DesktopMenuController.screen.name) ? DesktopMenuController.screen.name : "");
        let dir = (typeof Caching !== "undefined" && Caching.anserinDir) ? Caching.anserinDir : "";
        let scriptPath = dir ? (dir + "/scripts/redactor.sh") : "redactor.sh";
        Quickshell.execDetached(["bash", scriptPath, mon, targetId]);
    }

    function openGuide(tab, openOnly) {
        DesktopMenuController.hide();
        let targetTab = tab !== undefined ? String(tab).trim() : "";
        let dir = (typeof Caching !== "undefined" && Caching.anserinDir) ? Caching.anserinDir : "";
        let args = (openOnly ? "open guide" : "toggle guide") + (targetTab ? (" " + targetTab) : "");
        let cmd = (dir ? ("if [ -f '" + dir + "/scripts/qs_manager.sh' ]; then bash '" + dir + "/scripts/qs_manager.sh' " + args + "; else ") : "")
            + "if command -v anserin >/dev/null 2>&1; then anserin " + args + "; elif command -v qs_manager.sh >/dev/null 2>&1; then qs_manager. " + args + "; fi"
            + (dir ? "; fi" : "");
        Quickshell.execDetached(["bash", "-c", cmd]);
    }

    Item {
        id: rootContainer
        anchors.fill: parent
        focus: desktopMenuWindow.isVisible
        Keys.onEscapePressed: DesktopMenuController.hide()

        onActiveFocusChanged: {
            if (!activeFocus && desktopMenuWindow.isVisible && menuContainer.animProgress > 0.5) {
                DesktopMenuController.hide();
            }
        }

        Item {
            id: maskTarget
            x: desktopMenuWindow.clampedX
            y: desktopMenuWindow.clampedY
            width: desktopMenuWindow.menuWidth
            height: desktopMenuWindow.menuHeight
        }

        Item {
            id: menuContainer

            property real animProgress: 0.0

            NumberAnimation {
                id: openAnim
                target: menuContainer
                property: "animProgress"
                from: 0.0
                to: 1.0
                duration: 90
                easing.type: Easing.OutCubic
            }

            NumberAnimation {
                id: closeAnim
                target: menuContainer
                property: "animProgress"
                from: 1.0
                to: 0.0
                duration: 60
                easing.type: Easing.InQuad
                onFinished: {
                    if (!desktopMenuWindow.isVisible) {
                        menuContainer.animProgress = 0.0;
                    }
                }
            }

            x: desktopMenuWindow.clampedX
            y: desktopMenuWindow.clampedY
            width: desktopMenuWindow.menuWidth
            height: desktopMenuWindow.menuHeight

            opacity: 0.75 + (0.25 * animProgress)

            transform: Scale {
                origin.x: Math.max(0, Math.min(menuContainer.width, desktopMenuWindow.targetX - desktopMenuWindow.clampedX))
                origin.y: Math.max(0, Math.min(menuContainer.height, desktopMenuWindow.targetY - desktopMenuWindow.clampedY))
                xScale: 0.92 + (0.08 * menuContainer.animProgress)
                yScale: 0.92 + (0.08 * menuContainer.animProgress)
            }

            Column {
                id: contentCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                spacing: desktopMenuWindow.s(2)

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 0

                    Item {
                        visible: desktopMenuWindow.alignRight
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        id: iconButtonsBox
                        Layout.preferredWidth: iconRow.implicitWidth + desktopMenuWindow.s(8)
                        Layout.preferredHeight: iconRow.implicitHeight + desktopMenuWindow.s(8)
                        color: iconButtonsBoxGlass.active ? "transparent" : desktopMenuWindow.menuBackgroundColor
                        radius: desktopMenuWindow.cornerRadius
                        WallpaperBlur {
                        id: iconButtonsBoxGlass
                        anchors.fill: parent
                        radius: parent.radius
                    }
                    clip: true

                        Row {
                            id: iconRow
                            anchors.centerIn: parent
                            spacing: desktopMenuWindow.s(3)

                            IconButton {
                                visible: desktopMenuWindow.isWidgetMode
                                width: desktopMenuWindow.s(36)
                                height: desktopMenuWindow.s(36)
                                size: height
                                cornerRadius: desktopMenuWindow.s(8)
                                accentColor: desktopMenuWindow.primaryButtonColor
                                textColor: desktopMenuWindow.primaryTextColor
                                buttonIcon: "󰏫"
                                iconFontSize: desktopMenuWindow.s(16)
                                onClicked: {
                                    desktopMenuWindow.openRedactor(DesktopMenuController.targetWidgetId);
                                }
                            }

                            DeleteButton {
                                visible: desktopMenuWindow.isWidgetMode
                                width: desktopMenuWindow.s(36)
                                height: desktopMenuWindow.s(36)
                                size: height
                                cornerRadius: desktopMenuWindow.s(8)
                                accentColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.red) ? Qt.rgba(ThemeBackend.red.r, ThemeBackend.red.g, ThemeBackend.red.b, 0.22) : "#452026"
                                textColor: (typeof ThemeBackend !== "undefined" && ThemeBackend.red) ? ThemeBackend.red : "#f38ba8"
                                onClicked: {
                                    let wId = DesktopMenuController.targetWidgetId;
                                    if (wId) {
                                        let mon = (desktopMenuWindow.screen && desktopMenuWindow.screen.name) ? desktopMenuWindow.screen.name : ((DesktopMenuController.screen && DesktopMenuController.screen.name) ? DesktopMenuController.screen.name : "");
                                        let safeMon = mon.replace(/[^a-zA-Z0-9_-]/g, "_");
                                        if (typeof WidgetSync !== "undefined") {
                                            WidgetSync.removeWidget(mon, wId);
                                        }
                                        let mainQml = (typeof Caching !== "undefined" && Caching.mainQml) ? Caching.mainQml : "";
                                        if (mainQml) {
                                            Quickshell.execDetached(["quickshell", "-p", mainQml, "ipc", "call", "widgets-" + safeMon, "remove", wId]);
                                        }
                                    }
                                    DesktopMenuController.hide();
                                }
                            }
                        }
                    }

                    Item {
                        visible: !desktopMenuWindow.alignRight
                        Layout.fillWidth: true
                    }
                }

                Rectangle {
                    id: clickButtonsBox
                    width: parent.width
                    height: clickButtonsCol.implicitHeight + desktopMenuWindow.s(8)
                    color: clickButtonsBoxGlass.active ? "transparent" : desktopMenuWindow.menuBackgroundColor
                    radius: desktopMenuWindow.cornerRadius
                    WallpaperBlur {
                        id: clickButtonsBoxGlass
                        anchors.fill: parent
                        radius: parent.radius
                    }
                    clip: true

                    Column {
                        id: clickButtonsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: desktopMenuWindow.s(4)
                        spacing: desktopMenuWindow.s(2)

                        ClickButton {
                            visible: desktopMenuWindow.isWidgetMode
                            width: parent.width
                            height: desktopMenuWindow.s(29)
                            cornerRadius: desktopMenuWindow.s(8)
                            contentAlignment: Qt.AlignLeft
                            horizontalPadding: desktopMenuWindow.s(10)
                            buttonIcon: "󰕰"
                            iconFontSize: desktopMenuWindow.s(15)
                            textFontSize: desktopMenuWindow.s(12)
                            buttonText: {
                                if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
                                    let val = I18n.t("guide.display.widgets.open", "Open Redactor");
                                    if (val && val !== "guide.display.widgets.open") return val;
                                    return "Open Redactor";
                                }
                                return "Open Redactor";
                            }
                            accentColor: desktopMenuWindow.primaryButtonColor
                            textColor: desktopMenuWindow.primaryTextColor
                            onClicked: {
                                desktopMenuWindow.openRedactor("");
                            }
                        }

                    }
                }

                // Settings: only in a widget's menu (no Settings window, and files open from the left panel's File page)
                Rectangle {
                    id: settingsBox
                    visible: desktopMenuWindow.isWidgetMode
                    width: parent.width
                    height: settingsCol.implicitHeight + desktopMenuWindow.s(8)
                    color: settingsBoxGlass.active ? "transparent" : desktopMenuWindow.menuBackgroundColor
                    radius: desktopMenuWindow.cornerRadius
                    WallpaperBlur {
                        id: settingsBoxGlass
                        anchors.fill: parent
                        radius: parent.radius
                    }
                    clip: true

                    Column {
                        id: settingsCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.margins: desktopMenuWindow.s(4)

                        ClickButton {
                            width: parent.width
                            height: desktopMenuWindow.s(29)
                            cornerRadius: desktopMenuWindow.s(8)
                            contentAlignment: Qt.AlignLeft
                            horizontalPadding: desktopMenuWindow.s(10)
                            buttonIcon: "󰒓"
                            iconFontSize: desktopMenuWindow.s(15)
                            textFontSize: desktopMenuWindow.s(12)
                            buttonText: {
                                if (typeof I18n !== "undefined" && typeof I18n.t === "function") {
                                    let val = I18n.t("widgets.guide.name", "Settings");
                                    if (val && val !== "widgets.guide.name") return val;
                                    return "Settings";
                                }
                                return "Settings";
                            }
                            accentColor: desktopMenuWindow.buttonColor
                            textColor: ThemeBackend.text
                            onClicked: {
                                if (desktopMenuWindow.isWidgetMode) {
                                    desktopMenuWindow.openGuide("display_general");
                                } else {
                                    desktopMenuWindow.openGuide("");
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
