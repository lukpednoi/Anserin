import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import ".."
import "../../../"
import "../../../guide/theme"
import "../../../reusables"
import "../../../lock/redactor"
import "../../../lock/redactor/elements"

// 4D. THEME -> LOCK SCREEN
// Clean live background preview (WallpaperMedia + Select/Reset + swapIn animation);
// when Simple style is selected, overlays the user's real arranged Simple UI (LockLayoutView + Simple prompt).
// Custom lockscreen launches lock-redactor (single-page when Simple). Login screen uses real SddmStyles (no duplicate header).
Column {
    id: page
    property var app: null
    spacing: 11

    readonly property string primaryMonitor: (Quickshell.cursorScreen && Quickshell.cursorScreen.name) ? Quickshell.cursorScreen.name : (Quickshell.screens.length ? Quickshell.screens[0].name : "")
    readonly property string customBackground: Config.getSetting("lockscreen.backgroundMode", "follow") === "custom" ? Config.getSetting("lockscreen.customBackground", "") : ""
    readonly property string desktopBackground: {
        const path = Wallpaper.getWallpaperPath(primaryMonitor);
        return (!path || /\.(mp4|mkv|mov|webm)$/i.test(path) || path.indexOf("000_") !== -1)
            ? (Caching.getCacheDir("wallpaper") + "/current_wallpaper.png")
            : path;
    }
    readonly property string backgroundPath: customBackground || desktopBackground
    readonly property int lockStyleIdx: Config.getSetting("lockscreen.style", "dashboard") === "simple" ? 1 : 0
    readonly property bool isSimple: lockStyleIdx === 1
    readonly property var lockAnims: ["default", "padlock", "portal", "portal-large"]
    readonly property int lockAnimIdx: Math.max(0, lockAnims.indexOf(Config.getSetting("lockscreen.animation", "padlock")))

    function selectBackground(filePath) {
        if (filePath !== "" && (!filePath.startsWith("/") || !/\.(png|jpg|jpeg|webp|svg|gif|bmp|avif|mp4|mkv|mov|webm)$/i.test(filePath))) return;
        Config.updateJsonBulk({ "lockscreen.backgroundMode": filePath ? "custom" : "follow", "lockscreen.customBackground": filePath });
    }
    function openWidgetEditor(mon) {
        Quickshell.execDetached(["quickshell", "-p", Caching.mainQml, "ipc", "call", "lock-redactor", "open", mon || page.primaryMonitor]);
        if (page.app) page.app.closeRequested();
    }

    Component.onDestruction: { if (Wallpaper.lockPickInline) Wallpaper.closeLockPicker(); }

    Connections {
        target: Wallpaper
        ignoreUnknownSignals: true
        function onLockPicked(path, cardRect, picture) { page.swapIn(path, cardRect, picture); }
    }

    // Flying swap animation when picking a wallpaper from the inline Select Wallpaper panel (as original LockscreenPage)
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
            ClippingRectangle {
                id: goingDown
                radius: ThemeBackend.borderRadius; color: ThemeBackend.mantle
                opacity: 1 - swap.t * 0.9
                Image { anchors.fill: parent; source: swap.old; fillMode: Image.PreserveAspectCrop; asynchronous: false }
            }
            ClippingRectangle {
                id: goingUp
                radius: ThemeBackend.borderRadius; color: ThemeBackend.mantle
                Image { anchors.fill: parent; source: swap.picked; fillMode: Image.PreserveAspectCrop; asynchronous: false }
            }
            SequentialAnimation {
                id: swapAnim
                NumberAnimation { target: swap; property: "t"; from: 0; to: 1; duration: 520; easing.type: Easing.InOutCubic }
                PauseAnimation { duration: 120 }
                ScriptAction { script: swap.destroy() }
            }
            Component.onCompleted: {
                t = 0.0001;
                swapAnim.restart();
            }
        }
    }

    function swapIn(path, cardRect, picture) {
        const host = typeof masterWindow !== "undefined" && masterWindow.contentItem ? masterWindow.contentItem : null;
        if (!host || !cardRect || cardRect.width <= 0 || !picture) {
            page.selectBackground(path);
            return;
        }
        const tl = previewBox.mapToItem(host, 0, 0);
        const oldPath = page.backgroundPath;
        const oldUrl = oldPath && !/\.(mp4|mkv|mov|webm)$/i.test(oldPath) ? ("file://" + oldPath) : "";
        swapComp.createObject(host, {
            rowRect: cardRect,
            previewRect: Qt.rect(tl.x, tl.y, previewBox.width, previewBox.height),
            picked: picture,
            old: oldUrl
        });
        page.selectBackground(path);
    }

    // Live Simple lockscreen layout store (only instantiated while Simple style is active)
    Loader {
        id: simpleStoreLoader
        active: page.visible && page.isSimple
        sourceComponent: LockLayoutStore { monitorName: page.primaryMonitor || "default" }
    }

    // Read-only context matching LockScreen.qml for previewing the user's Simple layout
    QtObject {
        id: previewCtx
        readonly property string currentUser: SystemInfo.username !== "" ? SystemInfo.username : I18n.t("lock.default_user", "User")
        readonly property string faceIconPath: SystemInfo.avatarPath !== "" ? (SystemInfo.avatarPath.startsWith("file://") ? SystemInfo.avatarPath : "file://" + SystemInfo.avatarPath) : ""
        function s(v) { return Scaler.s(v); }
    }

    component SCard: SmartCard {
        cornerRadius: page.app.cornerRadius; darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cCard; accent: page.app.cAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SChoice: SmartChoiceTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SAction: SmartActionTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }

    SCard {
        title: "Background"; icon: "󰸉"; statusText: page.isSimple ? "SIMPLE" : "DASHBOARD"
        ClippingRectangle {
            id: previewBox
            width: parent.width; height: Math.round(width * 9 / 16)
            radius: Math.min(ThemeBackend.borderRadius, 14)
            color: ThemeBackend.mantle

            WallpaperMedia {
                id: media
                anchors.fill: parent
                path: page.backgroundPath
                active: page.visible
            }

            // Live scaled preview of the user's real arranged Simple lockscreen UI (ONLY in Simple mode!)
            Item {
                id: simpleStage
                visible: page.isSimple && simpleStoreLoader.item !== null
                anchors.fill: parent
                enabled: false
                readonly property var st: simpleStoreLoader.item
                readonly property real refW: st && st.refW > 0 ? st.refW : 1920
                readonly property real refH: st && st.refH > 0 ? st.refH : 1080
                readonly property real fit: Math.min(width / refW, height / refH)

                Item {
                    width: simpleStage.refW
                    height: simpleStage.refH
                    anchors.centerIn: parent
                    scale: simpleStage.fit

                    // Subtle readability dim like LockBackdrop
                    Rectangle { anchors.fill: parent; color: Qt.rgba(ThemeBackend.crust.r, ThemeBackend.crust.g, ThemeBackend.crust.b, 0.22) }

                    // User's real arranged widgets on the Simple screen (clock, etc.)
                    Loader {
                        anchors.fill: parent
                        active: simpleStage.visible && simpleStage.st !== null
                        sourceComponent: LockLayoutView {
                            store: simpleStage.st
                            scope: "screen"
                            ctx: previewCtx
                        }
                    }

                    // Real Simple prompt (avatar + username pill + password field), matching LockScreen.qml
                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height * 0.6 - height / 2
                        spacing: Scaler.s(14)
                        LockAvatarElement {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Scaler.s(96); height: width
                            ctx: previewCtx
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: pvUser.implicitWidth + Scaler.s(32); height: Scaler.s(36)
                            radius: height / 2
                            color: Qt.alpha(ThemeBackend.surface0, 0.8)
                            border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.12)
                            Text {
                                id: pvUser; anchors.centerIn: parent
                                text: previewCtx.currentUser
                                font.family: ThemeBackend.fontFamily; font.pixelSize: Scaler.s(16); font.bold: true
                                color: ThemeBackend.text
                            }
                        }
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Scaler.s(300); height: Scaler.s(46)
                            radius: Math.min(ThemeBackend.borderRadius, height / 2)
                            color: Qt.alpha(ThemeBackend.surface0, 0.82)
                            border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.16)
                            Text {
                                anchors.centerIn: parent
                                text: "••••••••"
                                font.family: ThemeBackend.fontFamily; font.pixelSize: Scaler.s(16); font.letterSpacing: 3
                                color: ThemeBackend.subtext0
                            }
                        }
                    }
                }
            }

            // Bottom readability gradient (as original LockscreenPage)
            Rectangle {
                anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: 64
                gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.alpha(ThemeBackend.base, 0.82) } }
            }

            Text {
                visible: media.failed
                anchors.centerIn: parent
                text: I18n.t("guide.display.lockscreen.background_error", "Failed to load background")
                font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.subtext0
            }

            Row {
                anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 10; spacing: 6
                Repeater {
                    model: [{ glyph: "󰸉", label: "Select", act: "select" }, { glyph: "󰑓", label: "Reset", act: "reset" }]
                    Rectangle {
                        required property var modelData
                        width: br.implicitWidth + 22; height: 28; radius: 14
                        color: bMa.pressed ? ThemeBackend.surface2 : (bMa.containsMouse ? ThemeBackend.surface1 : Qt.alpha(ThemeBackend.base, 0.78))
                        border.width: 1; border.color: Qt.alpha(ThemeBackend.text, 0.16)
                        Behavior on color { ColorAnimation { duration: 140 } }
                        Row { id: br; anchors.centerIn: parent; spacing: 5
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.glyph; font.family: ThemeBackend.iconFont; font.pixelSize: 12; color: ThemeBackend.text }
                            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData.label; font.family: ThemeBackend.fontFamily; font.pixelSize: 11; font.bold: true; color: ThemeBackend.text } }
                        MouseArea {
                            id: bMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                page.app.sfx.playClick();
                                if (modelData.act === "select") Wallpaper.openForLockHere();
                                else page.selectBackground("");
                            }
                        }
                    }
                }
            }
        }
    }

    SCard {
        title: "Lock screen"; icon: "󰌾"
        SChoice {
            width: parent.width; icon: "󰍹"; title: "Style"; options: ["Dashboard", "Simple"]
            currentIndex: page.lockStyleIdx
            onPicked: (i) => {
                const v = i === 1 ? "simple" : "dashboard";
                if (v !== Config.getSetting("lockscreen.style", "dashboard")) Config.setSetting("lockscreen.style", v);
                page.app.sfx.playSwitch();
            }
        }
        SChoice {
            width: parent.width; icon: "󰌾"; title: "Animation"
            options: page.isSimple ? ["Default"] : ["Default", "Padlock", "Portal", "Portal Large"]
            currentIndex: page.isSimple ? 0 : page.lockAnimIdx
            onPicked: (i) => {
                if (page.isSimple) return;
                const v = page.lockAnims[i];
                if (v && v !== Config.getSetting("lockscreen.animation", "padlock")) Config.setSetting("lockscreen.animation", v);
                page.app.sfx.playSwitch();
            }
        }
        Repeater {
            model: Quickshell.screens
            SAction {
                required property var modelData
                width: parent.width; icon: "󰋩"
                title: "Custom lockscreen" + (Quickshell.screens.length > 1 ? (" · " + modelData.name) : "")
                actionText: "Edit"
                onTriggered: { page.app.sfx.playQuick(); page.openWidgetEditor(modelData.name); }
            }
        }
    }

    SCard {
        title: "Login screen (SDDM)"; icon: "󰍂"; statusText: SddmTheming.appliedStyle === "new" ? "NEW" : "ORIGINAL"
        SddmStyles { width: parent.width; rootObj: page.app.shim; showHeader: false }
    }
}
