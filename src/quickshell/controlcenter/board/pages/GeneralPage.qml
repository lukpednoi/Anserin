import QtQuick
import QtQuick.Effects
import Quickshell
import "../../../"
import "../../../reusables"
import "../../../guide/general"
import ".."
import "../../../guide/shared"

// General as a board. Every option does what guide/general/GeneralTab.qml does: the same settings ("general" saved
// as one object), the same live updates (Sounds, Weather) and the same pickers (ImagePicker, LocationInfo,
// Location.detectAuto / setPlace). Quick Actions is left out as in the Anserin interface's Settings page.
BoardPage {
    id: page

    readonly property var defaults: ({ language: I18n.currentLang, muteSfx: false, sfxVolume: 100, screenshotCaptureOnRelease: false,
                                       quickactions: true, weatherInterval: 15, weatherUnit: "metric" })
    readonly property var gs: Config.getSetting("general", defaults)
    function g(k) { return gs[k] !== undefined ? gs[k] : defaults[k]; }
    readonly property string avatarPath: {
        let p = gs.avatarPath !== undefined && gs.avatarPath !== "" ? gs.avatarPath : (SystemInfo.avatarPath || "");
        return p.startsWith("file://") ? p.substring(7) : p;
    }
    // GeneralTab saves the whole "general" object, keeping the avatar path it shows
    function save(changes) {
        if (!Config.dataReady) return;
        const cur = Object.assign({}, Config.getSetting("general", defaults));
        if (cur.avatarPath === undefined || cur.avatarPath === "") cur.avatarPath = avatarPath;
        Config.setSetting("general", Object.assign(cur, changes));
    }
    property real sfxLive: NaN     // the volume while the wave is dragged (saved on release)

    // a small round button, and a text field (Location's Country / Province)
    component Pill: Rectangle {
        id: pill
        property string glyph: ""
        property string label: ""
        property bool lit: false
        signal hit()
        height: 32; radius: 16; width: pr.implicitWidth + 26
        color: pMa.pressed ? ThemeBackend.surface2 : (pMa.containsMouse ? ThemeBackend.surface1 : (lit ? Qt.alpha(page.accent, 0.3) : ThemeBackend.surface0))
        Behavior on color { ColorAnimation { duration: 140 } }
        Row { id: pr; anchors.centerIn: parent; spacing: 6
            Text { visible: pill.glyph !== ""; anchors.verticalCenter: parent.verticalCenter; text: pill.glyph; font.family: ThemeBackend.iconFont; font.pixelSize: 13; color: ThemeBackend.text }
            Text { visible: pill.label !== ""; anchors.verticalCenter: parent.verticalCenter; text: pill.label; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.text } }
        MouseArea { id: pMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); pill.hit(); } }
    }
    component Entry: Rectangle {
        property alias text: ci.text
        property string hint: ""
        readonly property bool typing: ci.activeFocus
        signal edited(string text)
        width: 150; height: 32; radius: Math.min(ThemeBackend.borderRadius, 10); color: ThemeBackend.surface0
        border.width: ci.activeFocus ? 2 : 0; border.color: page.accent
        TextInput { id: ci; x: 12; width: parent.width - 24; anchors.verticalCenter: parent.verticalCenter; clip: true
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.text; selectionColor: Qt.alpha(page.accent, 0.4)
                    onTextEdited: parent.edited(text) }
        Text { visible: ci.text === ""; x: 12; anchors.verticalCenter: parent.verticalCenter; text: parent.hint; font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.subtext1 }
    }

    extras: [
        ScreenshotDirLogic { id: shotDirs },
        OcrLanguagesLogic { id: ocrLangs },
        WeatherAlertsLogic { id: weatherAlerts },
        ImagePicker {
            id: imagePicker
            rootObj: page.rootObj
            onImageSelected: function(filePath, fileName) { page.save({ avatarPath: filePath }); }
        },
        LocationInfo { id: locationPopup; rootObj: page.rootObj }
    ]

    // ---------- you ----------
    BoardCard {
        title: I18n.t("guide.general.avatar.title") || "Profile picture"; icon: "󰀄"; accent: page.accent
        BoardCell {
            kind: "custom"; wide: true; icon: "󰀄"; title: I18n.t("guide.general.avatar.title") || "Profile picture"; customHeight: 64
            Row {
                spacing: 14
                Item {
                    width: 64; height: 64
                    Rectangle { anchors.fill: parent; radius: 32; color: ThemeBackend.surface1; visible: page.avatarPath === ""
                        Text { anchors.centerIn: parent; text: "󰀄"; font.family: ThemeBackend.iconFont; font.pixelSize: 30; color: ThemeBackend.subtext0 } }
                    Image { id: av; anchors.fill: parent; visible: false; source: page.avatarPath !== "" ? "file://" + page.avatarPath : ""
                            fillMode: Image.PreserveAspectCrop; cache: false; sourceSize: Qt.size(128, 128) }
                    Rectangle { id: avMask; anchors.fill: parent; radius: 32; visible: false; layer.enabled: true }
                    MultiEffect { anchors.fill: parent; source: av; maskEnabled: true; maskSource: avMask; visible: page.avatarPath !== "" && av.status === Image.Ready }
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: selRow.implicitWidth + 28; height: 32; radius: 16
                    color: selMa.pressed ? ThemeBackend.surface2 : (selMa.containsMouse ? ThemeBackend.surface1 : Qt.alpha(page.accent, 0.22))
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Row { id: selRow; anchors.centerIn: parent; spacing: 8
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "󰉋"; font.family: ThemeBackend.iconFont; font.pixelSize: 14; color: ThemeBackend.text }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: I18n.t("guide.general.avatar.select"); font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.text } }
                    MouseArea { id: selMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { Sounds.playSfx("reusables/clickbutton/click.wav"); imagePicker.openPicker(page.avatarPath); } }
                }
            }
        }
    }

    // ---------- sound effects ----------
    BoardCard {
        title: "Sound effects"; icon: "󰕾"; accent: page.accent
        BoardCell {
            kind: "toggle"; icon: "󰝟"; title: I18n.t("guide.general.mutesfx.title") || "Mute SFX"
            value: page.g("muteSfx")
            onPicked: (v) => {
                Sounds.generalSettings = Object.assign({}, Sounds.generalSettings || {}, { "muteSfx": v });
                page.save({ muteSfx: v });
            }
        }
        BoardCell {
            kind: "slider"; icon: "󰕾"; title: I18n.t("guide.general.sfxvolume.title") || "SFX Volume"
            from: 0; to: 100; step: 1; suffix: "%"
            value: isNaN(page.sfxLive) ? page.g("sfxVolume") : page.sfxLive
            onMoving: (v) => {
                const r = Math.round(v);
                page.sfxLive = r;
                Sounds.generalSettings = Object.assign({}, Sounds.generalSettings || {}, { "sfxVolume": r });
            }
            onReleased: { if (!isNaN(page.sfxLive)) page.save({ sfxVolume: page.sfxLive }); page.sfxLive = NaN; }
        }
    }

    // ---------- weather ----------
    BoardCard {
        title: "Weather"; icon: "󰖕"; accent: page.accent
        BoardCell {
            id: loc
            kind: "custom"; wide: true; icon: "󰍎"; title: I18n.t("guide.general.location.title")
            property bool editing: false
            customHeight: editing ? (Location.placeError !== "" ? 96 : 74) : 32
            Column {
                width: parent.width; spacing: 10
                Row {
                    spacing: 8
                    Pill { glyph: Location.isDetecting ? "󰑓" : "󰢹"; label: "Auto-detect"; onHit: { loc.editing = false; Location.detectAuto(); } }
                    Pill { glyph: "󰍎"; label: Location.city; onHit: locationPopup.open() }
                    Pill { glyph: "󰏫"; lit: loc.editing; onHit: loc.editing = !loc.editing }
                }
                // a province of a country: the location is locked there (Auto-detect unlocks it)
                Row {
                    visible: loc.editing; opacity: loc.editing ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    spacing: 8
                    // names offered while typing (Open-Meteo, the same lookup Apply uses); a pick only fills the field
                    Entry {
                        id: placeCountry; hint: "Country"; text: Location.placeCountry
                        onEdited: (t) => Location.suggest("country", t, "")
                        SuggestList {
                            shown: placeCountry.typing
                            items: Location.suggestKind === "country" ? Location.suggestions : []
                            current: placeCountry.text
                            onPicked: (n) => { placeCountry.text = n; Location.clearSuggestions(); }
                        }
                    }
                    Entry {
                        id: placeProvince; hint: "Province"; text: Location.placeProvince
                        onEdited: (t) => Location.suggest("province", t, placeCountry.text)
                        SuggestList {
                            shown: placeProvince.typing
                            items: Location.suggestKind === "province" ? Location.suggestions : []
                            current: placeProvince.text
                            onPicked: (n) => { placeProvince.text = n; Location.clearSuggestions(); }
                        }
                    }
                    Pill { label: "Apply"; lit: true; onHit: Location.setPlace(placeCountry.text, placeProvince.text) }
                }
                Text {
                    visible: loc.editing && Location.placeError !== ""
                    text: Location.placeError
                    font.family: ThemeBackend.fontFamily; font.pixelSize: 12; color: ThemeBackend.red
                }
            }
            Connections {
                target: Location
                function onLocationUpdated() {
                    placeCountry.text = Location.placeCountry;
                    placeProvince.text = Location.placeProvince;
                }
            }
        }
        BoardCell {
            kind: "stepper"; icon: "󰔛"; title: I18n.t("guide.general.weatherinterval.title") || "Weather Polling Interval"
            from: 1; to: 1440; step: 1; suffix: " min"
            value: page.g("weatherInterval")
            onPicked: (v) => {
                const val = Math.round(v);
                if (val < 1 || val === page.g("weatherInterval")) return;
                page.save({ weatherInterval: val });
                if (typeof Weather !== "undefined") Weather.refreshInterval = val * 60000;
            }
        }
        BoardCell {
            kind: "select"; icon: "󰔏"; title: I18n.t("guide.general.weatherunit.title") || "Weather Unit"
            options: ["Celsius", "Fahrenheit", "Kelvin"]; values: ["metric", "imperial", "standard"]
            value: page.g("weatherUnit")
            onPicked: (v) => {
                page.save({ weatherUnit: v });
                if (typeof Weather !== "undefined") Weather.unit = v;
            }
        }
    }

    // ---------- weather alerts (guide/shared/WeatherAlertsLogic.qml) ----------
    BoardCard {
        title: "Weather alerts"; icon: "󰀦"; accent: page.accent
        BoardCell { kind: "toggle"; icon: "󰀦"; title: "Weather alerts"; value: weatherAlerts.alertsOn
                    onPicked: (v) => weatherAlerts.set("enabled", v) }
        BoardCell { kind: "toggle"; icon: "󰖕"; title: "Twice-daily forecast"; available: weatherAlerts.alertsOn
                    value: weatherAlerts.settings.dailyForecast === true; onPicked: (v) => weatherAlerts.set("dailyForecast", v) }
        BoardCell { kind: "toggle"; icon: "󰒡"; title: "Government warnings"; available: weatherAlerts.alertsOn
                    value: weatherAlerts.settings.governmentWarnings === true; onPicked: (v) => weatherAlerts.set("governmentWarnings", v) }
        BoardCell { kind: "toggle"; icon: "󰂛"; title: "Quiet hours"; available: weatherAlerts.alertsOn
                    value: weatherAlerts.settings.quietHours === true; onPicked: (v) => weatherAlerts.set("quietHours", v) }
        BoardCell {
            kind: "custom"; wide: true; icon: "󰔛"; title: "Quiet period"; customHeight: 56
            hidden: !weatherAlerts.quietOn
            TimeRangeSlider {
                width: parent.width
                start: weatherAlerts.settings.quietStart
                end: weatherAlerts.settings.quietEnd
                accentColor: page.accent
                trackColor: ThemeBackend.surface2
                textColor: ThemeBackend.text
                subTextColor: ThemeBackend.subtext0
                onCommitted: function(st, en) { weatherAlerts.setQuiet(st, en); }
            }
        }
        BoardCell {
            kind: "select"; multi: true; icon: "󰖕"; title: "Alert types"; available: weatherAlerts.alertsOn
            options: weatherAlerts.kinds.map(k => k.title); values: weatherAlerts.kinds.map(k => k.key)
            value: weatherAlerts.pickedKinds
            onPicked: (v) => weatherAlerts.setKinds(v)
        }
        BoardCell {
            kind: "info"; icon: "󰋼"; title: "Warning source status"
            hidden: !weatherAlerts.alertsOn || weatherAlerts.settings.governmentWarnings !== true
            info: weatherAlerts.govStatusText()
        }
    }

    // ---------- screenshot and settings ----------
    BoardCard {
        title: "More"; icon: "󰒓"; accent: page.accent
        BoardCell {
            kind: "toggle"; icon: "󰹑"; title: I18n.t("guide.general.screenshot_on_release.title") || "Capture region on mouse release"
            value: page.g("screenshotCaptureOnRelease")
            onPicked: (v) => page.save({ screenshotCaptureOnRelease: v })
        }
        // what Anserin opens folders with (singletons/system/FileManager.qml)
        BoardCell {
            kind: "seg"; icon: "󰉋"; title: "File manager"
            hidden: FileManager.available.length < 2
            options: FileManager.available.map(c => c.name); values: FileManager.available.map(c => c.id)
            value: FileManager.chosen
            onPicked: (v) => FileManager.setChosen(v)
        }
        BoardCell {
            kind: "select"; icon: "󰉋"; title: "Screenshot folder"
            options: shotDirs.dirs; values: shotDirs.dirs
            value: shotDirs.currentDir
            onPicked: (v) => shotDirs.setDir(v)
        }
        BoardCell {
            kind: "action"; icon: "󰉋"; title: "Open screenshot folder"; actionText: "Open"
            onActivated: shotDirs.openDir()
        }
        // the screenshot tool's text recognition (the 󱄽 button)
        BoardCell {
            kind: "select"; multi: true; icon: "󱄽"; title: "Text recognition"
            available: !ocrLangs.busy
            options: ocrLangs.languages.map(l => l.name); values: ocrLangs.languages.map(l => l.code)
            value: ocrLangs.installed
            onPicked: (v) => ocrLangs.setLanguages(v)
        }
        BoardCell {
            kind: "info"; icon: ocrLangs.error ? "󰀪" : "󰇚"; title: "Text recognition"
            hidden: !ocrLangs.busy && ocrLangs.error === ""
            info: ocrLangs.error || ("Downloading " + ocrLangs.nameOf(ocrLangs.busyCode) + "…")
        }
        BoardCell {
            kind: "action"; icon: "󰆏"; title: I18n.t("guide.general.copysettings.title") || "Copy settings"; actionText: "Copy settings"
            onActivated: Quickshell.execDetached(["bash", "-c", "cat \"" + Config.settingsJsonPath + "\" | wl-copy"])
        }
    }
}
