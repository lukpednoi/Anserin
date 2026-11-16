import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../../"
import "../../../reusables"
import "../../../guide/theme" as ThemeUi
import ".."

// Theme → Lock screen as a board, doing what guide/display/DisplayLockscreenTab.qml does: the lock screen's
// wallpaper (shown live; Select opens Select Wallpaper for the lock screen, Reset follows the desktop), the Dashboard animation,
// each screen's widget editor (lock-redactor), and the login screen's style (the real SddmStyles).
BoardPage {
    id: page
    readonly property var animationStyles: ["default", "padlock", "portal", "portal-large"]
    readonly property string animationStyle: Config.getSetting("lockscreen.animation", "padlock")
    // Dashboard (the card with widgets) or Simple (the clock, the profile picture, the name and the password); each has
    // its own animations (Simple: Default only) and its own widgets
    readonly property bool simple: Config.getSetting("lockscreen.style", "dashboard") === "simple"
    readonly property string customBackground: Config.getSetting("lockscreen.backgroundMode", "follow") === "custom" ? Config.getSetting("lockscreen.customBackground", "") : ""
    readonly property string desktopBackground: {
        const path = Wallpaper.getWallpaperPath(Quickshell.cursorScreen ? Quickshell.cursorScreen.name : "");
        return !path || /\.(mp4|mkv|mov|webm)$/i.test(path) || path.indexOf("000_") !== -1
            ? Caching.getCacheDir("wallpaper") + "/current_wallpaper.png" : path;
    }
    readonly property string backgroundPath: customBackground || desktopBackground
    function selectBackground(filePath) {
        if (filePath !== "" && (!filePath.startsWith("/") || !/\.(png|jpg|jpeg|webp|svg|gif|bmp|avif|mp4|mkv|mov|webm)$/i.test(filePath))) return;
        Config.updateJsonBulk({ "lockscreen.backgroundMode": filePath ? "custom" : "follow", "lockscreen.customBackground": filePath });
    }
    // Select brings up Select Wallpaper beside the Control Center, which stays open (Main.qml's lock picker; only the
    // lock screen's background changes). A pick swaps places with the preview: the picked card flies over into it while
    // the old background flies out to where the card was, as Select goes away.
    function openBackgroundPicker() { Wallpaper.openForLockHere(); }
    onVisibleChanged: if (!visible && Wallpaper.lockPickInline) Wallpaper.closeLockPicker()
    Connections {
        target: Wallpaper
        function onLockPicked(path, card, picture) { page.swapIn(path, card, picture); }
    }

    Component {
        id: swapComp
        Item {
            id: swap
            anchors.fill: parent
            z: 100000
            enabled: false
            property rect rowRect
            property rect previewRect
            property url picked
            property url old
            property real t: 0
            function lerp(a, b, k) { return a + (b - a) * k; }
            function place(item, from, to, k) {
                item.x = lerp(from.x, to.x, k); item.y = lerp(from.y, to.y, k);
                item.width = lerp(from.width, to.width, k); item.height = lerp(from.height, to.height, k);
            }
            onTChanged: { place(goingUp, rowRect, previewRect, t); place(goingDown, previewRect, rowRect, t); }
            // the old background, on its way out to the picked card's place (fading with Select)
            ClippingRectangle {
                id: goingDown
                radius: ThemeBackend.borderRadius
                color: ThemeBackend.mantle
                opacity: 1 - swap.t * 0.9
                Image { anchors.fill: parent; source: swap.old; fillMode: Image.PreserveAspectCrop; asynchronous: false }
            }
            // the picked one, over into the preview, above the other
            ClippingRectangle {
                id: goingUp
                radius: ThemeBackend.borderRadius
                color: ThemeBackend.mantle
                Image { anchors.fill: parent; source: swap.picked; fillMode: Image.PreserveAspectCrop; asynchronous: false }
            }
            SequentialAnimation {
                running: true
                NumberAnimation { target: swap; property: "t"; from: 0; to: 1; duration: 520; easing.type: Easing.InOutCubic }
                PauseAnimation { duration: 120 }       // the preview has the new background under it by now
                ScriptAction { script: swap.destroy() }
            }
            Component.onCompleted: t = 0.0001
        }
    }
    function swapIn(path, cardRect, picture) {
        const host = typeof masterWindow !== "undefined" && masterWindow.contentItem ? masterWindow.contentItem : null;
        if (!host || cardRect.width <= 0) { selectBackground(path); return; }
        const previewRect = previewBox.mapToItem(host, 0, 0, previewBox.width, previewBox.height);
        // the preview as it is now (a video's frame too), for the old background's flight
        previewBox.grabToImage(result => {
            swapComp.createObject(host, { rowRect: cardRect, previewRect: previewRect, picked: picture, old: result.url });
            page.selectBackground(path);
        });
    }
    function openWidgetEditor(monitorName) {
        Quickshell.execDetached(["quickshell", "-p", Caching.mainQml, "ipc", "call", "lock-redactor", "open", monitorName]);
        if (typeof rootObj.closePopup === "function") rootObj.closePopup();
    }

    BoardCard {
        title: I18n.t("guide.display.lockscreen.background"); icon: "󰸉"; accent: page.accent
        ClippingRectangle {
            id: previewBox
            implicitHeight: 200
            radius: Math.min(ThemeBackend.borderRadius, 14)
            color: ThemeBackend.mantle
            WallpaperMedia {
                id: media
                anchors.fill: parent
                path: page.backgroundPath
                active: page.visible && page.rootObj.visible
            }
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 70
                gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.alpha(ThemeBackend.base, 0.8) } }
            }
            Text {
                visible: media.failed
                anchors.centerIn: parent
                text: I18n.t("guide.display.lockscreen.background_error")
                font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.subtext0
            }
            Row {
                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 12; spacing: 8
                Repeater {
                    model: [{ glyph: "󰸉", label: "Select", act: "select" }, { glyph: "󰑓", label: I18n.t("guide.display.lockscreen.reset"), act: "reset" }]
                    Rectangle {
                        required property var modelData
                        width: br.implicitWidth + 26; height: 32; radius: 16
                        color: bMa.pressed ? ThemeBackend.surface2 : (bMa.containsMouse ? ThemeBackend.surface1 : Qt.alpha(ThemeBackend.base, 0.75))
                        border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.12)
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Row { id: br; anchors.centerIn: parent; spacing: 6
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.glyph; font.family: ThemeBackend.iconFont; font.pixelSize: 14; color: ThemeBackend.text }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.text } }
                        MouseArea { id: bMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); if (modelData.act === "select") page.openBackgroundPicker(); else page.selectBackground(""); } }
                    }
                }
            }
        }
    }
    BoardCard {
        title: "Lock screen"; icon: "󰌾"; accent: page.accent
        BoardCell {
            kind: "seg"; icon: "󰍹"; title: "Style"
            options: ["Dashboard", "Simple"]; values: ["dashboard", "simple"]
            value: page.simple ? "simple" : "dashboard"
            onPicked: (v) => Config.setSetting("lockscreen.style", v)
        }
        // one cell: the style in use's own animations
        BoardCell {
            kind: "select"; icon: "󰌾"; title: I18n.t("guide.display.lockscreen.animation")
            options: page.simple ? [I18n.t("guide.display.lockscreen.default")]
                                 : [I18n.t("guide.display.lockscreen.default"), I18n.t("guide.display.lockscreen.padlock"), I18n.t("guide.display.lockscreen.portal"), I18n.t("guide.display.lockscreen.portal_large")]
            values: page.simple ? ["default"] : page.animationStyles
            value: page.simple ? "default" : (page.animationStyles.includes(page.animationStyle) ? page.animationStyle : "padlock")
            onPicked: (v) => { if (!page.simple) Config.setSetting("lockscreen.animation", v); }
        }
        Repeater {
            model: Quickshell.screens
            BoardCell {
                required property var modelData
                kind: "action"; icon: "󰋩"
                title: I18n.t("guide.display.lockscreen.screen_widgets") + (Quickshell.screens.length > 1 ? " · " + modelData.name : "")
                actionText: I18n.t("guide.display.lockscreen.edit_widgets")
                onActivated: page.openWidgetEditor(modelData.name)
            }
        }
    }
    BoardCard {
        title: "Login screen"; icon: "󰍂"; accent: page.accent
        ThemeUi.SddmStyles { rootObj: page.rootObj }
    }
}
