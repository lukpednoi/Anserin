import QtQuick
import Quickshell
import "../../../"
import "../../../reusables"
import "../../../guide/theme"
import ".."

// Theme → Orbit in the Original layout as a board (with the Orbit layout the real page is shown, as a preview:
// BoardSettings.qml). It runs the Settings page's own logic (guide/theme/ThemeLogic.qml): the wallpaper folder,
// the font (the list, installing one, the fonts folder), the border radius (snapped, debounced), Theme style and
// Apps (GeneralExtras), and the colour themes (search, new theme, the real preview cards).
BoardPage {
    id: page
    function esc(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); }
    extras: [
        ThemeLogic { id: tl; rootObj: page.rootObj; onFontInstalled: fontPicker.close() },
        FontPicker {
            id: fontPicker
            rootObj: page.rootObj
            onFontSelected: function(filePath, fileName) {
                if (filePath && filePath.trim() !== "" && fileName && fileName.trim() !== "") tl.installFont(filePath, fileName);
            }
        },
        ThemeEditor {
            id: themeEditor
            rootObj: page.rootObj
            tileWidth: Math.max(80, (page.width - 48 - 20) / 3)
            onSaveRequested: function(themeObj) { tl.saveCustomTheme(themeObj); tl.applyPreset(themeObj); }
        }
    ]
    Component.onCompleted: { tl.loadAvailableFonts(); tl.activateTab(); }
    onVisibleChanged: {
        if (visible) tl.activateTab();
        else { tl.activateDebounceTimer.stop(); themeEditor.close(); fontPicker.close(); }
    }

    component Pill: Rectangle {
        id: pill
        property string glyph: ""
        property string label: ""
        signal hit()
        height: 32; radius: 16; width: pr.implicitWidth + 24
        color: pMa.pressed ? ThemeBackend.surface2 : (pMa.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
        Behavior on color { ColorAnimation { duration: 140 } }
        Row { id: pr; anchors.centerIn: parent; spacing: 6
            Text { visible: pill.glyph !== ""; anchors.verticalCenter: parent.verticalCenter; text: pill.glyph; font.family: ThemeBackend.iconFont; font.pixelSize: 14; color: ThemeBackend.text }
            Text { visible: pill.label !== ""; anchors.verticalCenter: parent.verticalCenter; text: pill.label; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.text } }
        MouseArea { id: pMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); pill.hit(); } }
    }

    // ---------- wallpaper folder ----------
    BoardCard {
        title: I18n.t("guide.theme.wallpaper.title") || "Wallpaper Directory"; icon: "󰸉"; accent: page.accent
        BoardCell {
            kind: "select"; icon: "󰸉"; title: I18n.t("guide.theme.wallpaper.title") || "Wallpaper Directory"
            options: tl.availableWallpaperDirs.length ? tl.availableWallpaperDirs : [tl.currentWallpaperDir]
            value: tl.currentWallpaperDir
            onPicked: (v) => { tl.currentWallpaperDir = v; tl.updateWallpaperDirSetting(); }
            values: options
        }
        BoardCell {
            kind: "action"; icon: "󰉋"; title: "Open folder"; actionText: "Open"
            onActivated: if (tl.currentWallpaperDir !== "") FileManager.openFolder(tl.currentWallpaperDir, true)
        }
    }

    // ---------- text and shape ----------
    BoardCard {
        title: "Text and shape"; icon: "󰛖"; accent: page.accent
        BoardCell {
            kind: "custom"; wide: true; icon: "󰛖"; title: I18n.t("guide.theme.font.title"); customHeight: 34
            Row {
                width: parent.width; spacing: 8
                Dropdown {
                    id: fontDropdown
                    width: parent.width - 2 * 40 - 16
                    options: tl.availableFonts
                    currentIndex: options.indexOf(tl.currentFontFamily) >= 0 ? options.indexOf(tl.currentFontFamily) : 0
                    useOptionAsFontFamily: true
                    onValueChanged: function(index, value) { tl.currentFontFamily = value; tl.updateFontSetting(); }
                    onClicked: tl.loadAvailableFonts()
                }
                Pill { glyph: "󰉋"; width: 40
                       onHit: {
                           const p = Caching.stateDir ? (Caching.stateDir + "/fonts") : (Caching.home + "/.local/state/anserin/fonts");
                           FileManager.openFolder(p, true);
                       } }
                Pill { glyph: "󰐕"; width: 40; onHit: fontPicker.openPicker() }
            }
        }
        BoardCell {
            kind: "stepper"; icon: "󰞁"; title: I18n.t("guide.theme.radius.title")
            from: 0; to: 64; step: 1; suffix: "px"
            value: tl.currentBorderRadius
            onPicked: (v) => {
                const snapped = tl.getSnappedRadius(Math.round(v));
                if (!isNaN(snapped) && snapped >= 0 && snapped <= 64 && tl.currentBorderRadius !== snapped) {
                    tl.currentBorderRadius = snapped;
                    tl.borderRadiusDebounceTimer.restart();
                }
            }
        }
    }

    // ---------- Theme style and Apps (guide/theme/GeneralExtras.qml) ----------
    BoardCard {
        title: "Theme style"; icon: "󰏘"; accent: page.accent
        BoardCell {
            kind: "seg"; icon: "󰔎"; title: "Color mode"
            options: ["Light", "Dark"]; values: ["light", "dark"]
            value: Matugen.colorMode
            // a fixed colour theme decides the mode itself
            available: Matugen.matugenActive && !Matugen.isRunning
            onPicked: (v) => Matugen.setColorMode(v)
        }
        BoardCell {
            kind: "seg"; icon: "󰏘"; title: "Theme style"
            options: ["Default", "Liquid Glass"]; values: ["default", "liquid"]
            value: ThemeBackend.liquidGlass ? "liquid" : "default"
            onPicked: (v) => Config.setSetting("theme.material", v)
        }
        BoardCell {
            // apps that follow Anserin's colours; only installed ones are offered
            kind: "select"; multi: true; icon: "󰀻"; title: "Apps"
            options: AppTheming.installedApps.map(a => a.name); values: AppTheming.installedApps.map(a => a.id)
            value: AppTheming.enabledIds
            available: !AppTheming.busy
            onPicked: (v) => AppTheming.setApps(v)
        }
        BoardCell {
            kind: "info"; icon: AppTheming.error ? "󰀪" : "󰑓"; title: "Apps"
            hidden: !AppTheming.error && !AppTheming.busy
            info: AppTheming.error || "Applying theme…"
        }
    }

    // ---------- colour themes ----------
    BoardCard {
        title: I18n.t("guide.theme.colors.title"); icon: "󰏘"; accent: page.accent
        BoardCell {
            kind: "custom"; wide: true; icon: "󰍉"; title: I18n.t("guide.theme.colors.search"); customHeight: 34
            Row {
                width: parent.width; spacing: 8
                Rectangle {
                    width: parent.width - newBtn.width - 8; height: 34; radius: 17; color: ThemeBackend.surface0
                    border.width: search.activeFocus ? 2 : 0; border.color: page.accent
                    TextInput { id: search; x: 14; width: parent.width - 28; anchors.verticalCenter: parent.verticalCenter; clip: true
                                text: tl.themeSearchText; onTextEdited: tl.themeSearchText = text
                                font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.text; selectionColor: Qt.alpha(page.accent, 0.4)
                                Keys.onEscapePressed: focus = false }
                    Text { visible: search.text === "" && !search.activeFocus; x: 14; anchors.verticalCenter: parent.verticalCenter
                           text: I18n.t("guide.theme.colors.search"); font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.subtext1 }
                }
                Pill { id: newBtn; glyph: "󰐕"; label: "New"; onHit: themeEditor.openForNew() }
            }
        }
        ThemePresetGrid { page: tl; rootObj: page.rootObj }
    }
}
