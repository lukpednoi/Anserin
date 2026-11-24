import QtQuick
import QtQuick.Layouts
import Quickshell
import ".."
import "../../../"
import "../../../guide/shared"
import "../../../reusables"

// 2. GENERAL — Profile Account, Sound Effects (with Preview Pad), Weather, Weather Alerts, More
Column {
    id: page
    property var app: null
    spacing: 11

    // ---- real General logic (loaded only while this page is open) ----
    readonly property var gDefaults: ({ muteSfx: false, sfxVolume: 100, screenshotCaptureOnRelease: false, weatherInterval: 15, weatherUnit: "metric" })
    readonly property var gs: Config.getSetting("general", gDefaults)
    function g(k) { return gs[k] !== undefined ? gs[k] : gDefaults[k]; }
    readonly property string avatarPath: {
        const p = gs.avatarPath !== undefined && gs.avatarPath !== "" ? gs.avatarPath : (SystemInfo.avatarPath || "");
        return p.startsWith("file://") ? p.substring(7) : p;
    }
    readonly property string avatarUrl: avatarPath !== "" ? "file://" + avatarPath : ""
    function saveGeneral(changes) {
        if (!Config.dataReady) return;
        const cur = Object.assign({}, Config.getSetting("general", gDefaults));
        if (cur.avatarPath === undefined || cur.avatarPath === "") cur.avatarPath = avatarPath;
        Config.setSetting("general", Object.assign(cur, changes));
    }

    property bool sfxMuted: g("muteSfx")
    onSfxMutedChanged: if (sfxMuted !== g("muteSfx")) {
        Sounds.generalSettings = Object.assign({}, Sounds.generalSettings || {}, { "muteSfx": sfxMuted });
        saveGeneral({ muteSfx: sfxMuted });
    }
    property real sfxVol: g("sfxVolume") / 100
    onSfxVolChanged: {
        const v = Math.round(sfxVol * 100);
        if (v === g("sfxVolume")) return;
        Sounds.generalSettings = Object.assign({}, Sounds.generalSettings || {}, { "sfxVolume": v });
        sfxSave.restart();
    }
    Timer { id: sfxSave; interval: 400; onTriggered: page.saveGeneral({ sfxVolume: Math.round(page.sfxVol * 100) }) }

    readonly property string locCity: Location.city
    property string locCountry: Location.placeCountry
    property string locProvince: Location.placeProvince
    property bool locEditing: false
    readonly property string weatherDesc: (typeof Weather !== "undefined" && Weather.data && Weather.data.desc) ? Weather.data.desc : ""
    readonly property string weatherTemp: (typeof Weather !== "undefined" && Weather.currentTempFormatted) ? Weather.currentTempFormatted : "--°"
    property real weatherPoll: g("weatherInterval")
    onWeatherPollChanged: {
        const v = Math.round(weatherPoll);
        if (v < 1 || v === g("weatherInterval")) return;
        saveGeneral({ weatherInterval: v });
        if (typeof Weather !== "undefined") Weather.refreshInterval = v * 60000;
    }
    readonly property var weatherUnits: ["metric", "imperial", "standard"]
    property int weatherUnitIdx: Math.max(0, weatherUnits.indexOf(g("weatherUnit")))
    onWeatherUnitIdxChanged: {
        const u = weatherUnits[weatherUnitIdx];
        if (!u || u === g("weatherUnit")) return;
        saveGeneral({ weatherUnit: u });
        if (typeof Weather !== "undefined") Weather.unit = u;
    }

    WeatherAlertsLogic { id: weatherAlerts }
    property bool weatherAlertsOn: weatherAlerts.alertsOn
    onWeatherAlertsOnChanged: if (weatherAlertsOn !== weatherAlerts.alertsOn) weatherAlerts.set("enabled", weatherAlertsOn)
    property bool wDaily: weatherAlerts.settings.dailyForecast === true
    onWDailyChanged: if (wDaily !== (weatherAlerts.settings.dailyForecast === true)) weatherAlerts.set("dailyForecast", wDaily)
    property bool wGov: weatherAlerts.settings.governmentWarnings === true
    onWGovChanged: if (wGov !== (weatherAlerts.settings.governmentWarnings === true)) weatherAlerts.set("governmentWarnings", wGov)
    property bool wQuiet: weatherAlerts.settings.quietHours === true
    onWQuietChanged: if (wQuiet !== (weatherAlerts.settings.quietHours === true)) weatherAlerts.set("quietHours", wQuiet)
    property real quietStartFrac: Math.max(0, Math.min(1, Number(weatherAlerts.settings.quietStart || 0) / 23))
    onQuietStartFracChanged: quietSave.restart()
    Timer { id: quietSave; interval: 400
            onTriggered: { const h = Math.floor(page.quietStartFrac * 23);
                           if (h !== Number(weatherAlerts.settings.quietStart)) weatherAlerts.setQuiet(h, weatherAlerts.settings.quietEnd); } }
    readonly property var alertKindTitles: weatherAlerts.kinds.map(k => k.title)
    property var alertTypes: weatherAlerts.kinds.filter(k => weatherAlerts.pickedKinds.indexOf(k.key) >= 0).map(k => k.title)
    onAlertTypesChanged: {
        const keys = weatherAlerts.kinds.filter(k => alertTypes.indexOf(k.title) >= 0).map(k => k.key);
        if (keys.slice().sort().join() !== weatherAlerts.pickedKinds.slice().sort().join()) weatherAlerts.setKinds(keys);
    }

    ScreenshotDirLogic { id: shotDirs }
    OcrLanguagesLogic { id: ocrLogic }
    property bool shotOnRelease: g("screenshotCaptureOnRelease")
    onShotOnReleaseChanged: if (shotOnRelease !== g("screenshotCaptureOnRelease")) saveGeneral({ screenshotCaptureOnRelease: shotOnRelease })
    readonly property var fileManagerNames: FileManager.available.map(c => c.name)
    property int fileMgrIdx: Math.max(0, FileManager.available.map(c => c.id).indexOf(FileManager.chosen))
    onFileMgrIdxChanged: { const c = FileManager.available[fileMgrIdx]; if (c && c.id !== FileManager.chosen) FileManager.setChosen(c.id); }
    readonly property var shotDirNames: shotDirs.dirs.map(d => d.replace(Quickshell.env("HOME") || "\u0000", "~"))
    property int shotDirIdx: Math.max(0, shotDirs.dirs.indexOf(shotDirs.currentDir))
    onShotDirIdxChanged: { const d = shotDirs.dirs[shotDirIdx]; if (d && d !== shotDirs.currentDir) shotDirs.setDir(d); }
    readonly property var ocrLangNames: ocrLogic.languages.map(l => l.name)
    property var ocrLangs: ocrLogic.languages.filter(l => ocrLogic.installed.indexOf(l.code) >= 0).map(l => l.name)
    onOcrLangsChanged: {
        const codes = ocrLogic.languages.filter(l => ocrLangs.indexOf(l.name) >= 0).map(l => l.code);
        if (codes.slice().sort().join() !== ocrLogic.installed.slice().sort().join() && !ocrLogic.busyCode) ocrLogic.setLanguages(codes);
    }

    Item {
        width: 0; height: 0; visible: false
        ImagePicker {
            id: imagePicker
            rootObj: page.app ? page.app.shim : null
            onOpened: if (page.app) page.app.modalOpened()
            onClosed: if (page.app) page.app.modalClosed()
            onImageSelected: function(filePath, fileName) { page.saveGeneral({ avatarPath: filePath }); }
        }
    }

    component SCard: SmartCard {
        cornerRadius: page.app.cornerRadius; darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cCard; accent: page.app.cAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SToggle: SmartGeoToggleTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SSlider: SmartSliderTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; accent: page.app.cAccent; accent2: page.app.cAccent2
        textColor: page.app.cText; subColor: page.app.cSub; uiFont: page.app.uiFont; iconFont: page.app.iconFont
        active: visible; onStepped: page.app.sfx.playTick(); onLockedFull: page.app.sfx.playLock()
    }
    component SChoice: SmartChoiceTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SStepper: SmartStepperTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent
        textColor: page.app.cText; subColor: page.app.cSub; uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SAction: SmartActionTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component SField: SmartFieldTile {
        cornerRadius: Math.max(10, page.app.cornerRadius - 2); darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cTile; surfaceHover: page.app.cTileHov; accent: page.app.cAccent; accent2: page.app.cAccent2
        inkAccent: page.app.cOnAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }
    component TileGrid: GridLayout { width: parent.width; columns: 2; columnSpacing: 8; rowSpacing: 8 }

    // ---- Profile Account ----
    SCard {
        title: "Profile Account"; icon: "󰀄"; statusText: "ACTIVE"
        Rectangle {
            width: parent.width; height: 64; radius: 14
            color: page.app.cTile
            border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.36)
            Row {
                anchors.left: parent.left; anchors.leftMargin: 11; anchors.verticalCenter: parent.verticalCenter; spacing: 12
                Rectangle {
                    width: 44; height: 44; radius: 12
                    color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.16)
                    border.width: 1.2; border.color: page.app.cAccent; clip: true
                    Image { anchors.fill: parent; visible: page.avatarUrl !== ""; source: page.avatarUrl; cache: false; fillMode: Image.PreserveAspectCrop }
                    Text { visible: page.avatarUrl === ""; anchors.centerIn: parent; text: "󰀄"; font.family: page.app.iconFont; font.pixelSize: 20; color: page.app.cAccent }
                }
                Column {
                    anchors.verticalCenter: parent.verticalCenter; spacing: 2
                    Row {
                        spacing: 6
                        Text { text: page.app.profileName; font.family: page.app.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold; color: page.app.cText }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter; height: 16; width: 44; radius: 8
                            color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.22)
                            Text { anchors.centerIn: parent; text: "Active"; font.family: page.app.uiFont; font.pixelSize: 9; font.bold: true; color: page.app.cAccent }
                        }
                    }
                    Text { text: "Local Account"; font.family: page.app.uiFont; font.pixelSize: 10; color: page.app.cSub }
                }
            }
            Rectangle {
                anchors.right: parent.right; anchors.rightMargin: 11; anchors.verticalCenter: parent.verticalCenter
                height: 30; width: 64; radius: 15
                color: selH.hovered ? page.app.cTileHov : Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.18)
                border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.40)
                Text { anchors.centerIn: parent; text: "Select"; font.family: page.app.uiFont; font.pixelSize: 11; font.bold: true; color: page.app.cAccent }
                HoverHandler { id: selH }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.app.sfx.playClick(); imagePicker.openPicker(page.avatarPath); } }
            }
        }
    }

    // ---- Sound Effects ----
    SCard {
        title: "Sound effects"; icon: "󰕾"; statusText: page.sfxMuted ? "MUTED" : Math.round(page.sfxVol * 100) + "%"
        RowLayout {
            width: parent.width; spacing: 7
            Repeater {
                model: [
                    { name: "Chime",  icon: "󰂚", fn: "on" },
                    { name: "Drop",   icon: "󰖌", fn: "off" },
                    { name: "Detent", icon: "󰓅", fn: "tick" },
                    { name: "Lock",   icon: "󰌾", fn: "lock" }
                ]
                Item {
                    id: padB; required property var modelData
                    Layout.fillWidth: true; Layout.preferredWidth: 1; height: 44
                    SpringVal { id: pSc; target: pMa.pressed ? 0.92 : (pH.hovered ? 1.04 : 1.0); stiffness: 520; damping: 0.42; eps: 0.001 }
                    SpringVal { id: rip; target: 0.0; stiffness: 180; damping: 0.65; eps: 0.01 }
                    scale: pSc.value
                    Rectangle {
                        anchors.fill: parent; radius: 13; color: pH.hovered ? page.app.cTileHov : page.app.cTile; clip: true
                        border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, pH.hovered ? 0.48 : 0.16)
                        Rectangle { anchors.centerIn: parent; width: parent.width * 1.4 * rip.value; height: width; radius: width * 0.5; color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, Math.max(0, 0.25 * (1.0 - rip.value))); visible: rip.value > 0.02 }
                        Row { anchors.centerIn: parent; spacing: 5
                            Text { text: padB.modelData.icon; font.family: page.app.iconFont; font.pixelSize: 12; color: page.app.cAccent; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: padB.modelData.name; font.family: page.app.uiFont; font.pixelSize: 11; font.weight: Font.Medium; color: page.app.cText; anchors.verticalCenter: parent.verticalCenter } }
                    }
                    HoverHandler { id: pH }
                    MouseArea { id: pMa; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: { pSc.kick(0.9); rip.snapAndGo(0.05, 1.0); if (padB.modelData.fn === "on") page.app.sfx.playToggle(true); else if (padB.modelData.fn === "off") page.app.sfx.playToggle(false); else if (padB.modelData.fn === "tick") page.app.sfx.playTick(); else page.app.sfx.playLock(); } }
                }
            }
        }
        SToggle { width: parent.width; icon: "󰝟"; title: "Mute SFX"; geoShape: "pentagon"; checked: page.sfxMuted; onToggled: (v) => { page.sfxMuted = v; if (!v) page.app.sfx.playToggle(true); } }
        SSlider { icon: "󰕾"; title: "SFX Volume"; value: page.sfxVol; valueText: Math.round(page.sfxVol * 100) + "%"; onMoved: (v) => page.sfxVol = v }
    }

    // ---- Weather ----
    SCard {
        title: "Weather"; icon: "󰖕"; statusText: page.locCity.toUpperCase()
        Rectangle {
            width: parent.width; height: 64; radius: 14; color: page.app.cTile; clip: true
            border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.22)
            Rectangle {
                anchors.fill: parent; radius: 14; opacity: 0.16
                gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0.0; color: page.app.cAccent } GradientStop { position: 1.0; color: "transparent" } }
            }
            Row {
                anchors.left: parent.left; anchors.leftMargin: 14; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                Text { text: "󰖕"; font.family: page.app.iconFont; font.pixelSize: 24; color: page.app.cAccent; anchors.verticalCenter: parent.verticalCenter }
                Column { spacing: 1
                    Text { text: page.weatherTemp + "  ·  " + page.locCity; font.family: page.app.uiFont; font.pixelSize: 15; font.weight: Font.Light; color: page.app.cText }
                    Text { text: page.weatherDesc + " · poll " + Math.round(page.weatherPoll) + "m"; font.family: page.app.uiFont; font.pixelSize: 10; color: page.app.cSub } }
            }
            Row {
                anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 5
                Rectangle { height: 26; width: 62; radius: 13; color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.16)
                    Text { anchors.centerIn: parent; text: "Auto"; font.family: page.app.uiFont; font.pixelSize: 10; font.bold: true; color: page.app.cAccent }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.locEditing = false; Location.detectAuto(); page.app.sfx.playQuick(); page.app.showToast("Detecting location…"); } } }
                Rectangle { height: 26; width: 26; radius: 13; color: page.locEditing ? page.app.cAccent : (page.app.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.08))
                    Text { anchors.centerIn: parent; text: "󰏫"; font.family: page.app.iconFont; font.pixelSize: 12; color: page.locEditing ? page.app.cOnAccent : page.app.cText }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.locEditing = !page.locEditing; page.app.sfx.playClick(); } } }
            }
        }
        RowLayout {
            visible: page.locEditing; width: parent.width; spacing: 8
            SField { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰍎"; title: "Country"; text: page.locCountry; placeholder: "Country"; onEdited: (v) => page.locCountry = v }
            SField { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰍎"; title: "Province"; text: page.locProvince; placeholder: "Province"; actionText: "Apply"; onEdited: (v) => page.locProvince = v; onSubmitted: (v) => { Location.setPlace(page.locCountry, v || page.locProvince); page.locEditing = false; page.app.sfx.playQuick(); } }
        }
        SStepper { width: parent.width; icon: "󰔛"; title: "Weather Polling Interval"; value: page.weatherPoll; from: 1; to: 1440; step: 5; suffix: " min"; onChanged: (v) => { page.weatherPoll = v; page.app.sfx.playStepper(); } }
        SChoice { width: parent.width; icon: "󰔏"; title: "Weather Unit"; options: ["Celsius (°C)", "Fahrenheit (°F)", "Kelvin (K)"]; currentIndex: page.weatherUnitIdx; onPicked: (i) => { page.weatherUnitIdx = i; page.app.sfx.playSwitch(); } }
    }

    // ---- Weather alerts ----
    SCard {
        title: "Weather alerts"; icon: "󰀦"
        TileGrid {
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰀦"; title: "Weather alerts"; geoShape: "softburst"; checked: page.weatherAlertsOn; onToggled: (v) => { page.weatherAlertsOn = v; page.app.sfx.playToggle(v); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰖕"; title: "Twice-daily forecast"; geoShape: "flower5"; available: page.weatherAlertsOn; checked: page.wDaily; onToggled: (v) => { page.wDaily = v; page.app.sfx.playToggle(v); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰒡"; title: "Gov warnings"; geoShape: "shield"; available: page.weatherAlertsOn; checked: page.wGov; onToggled: (v) => { page.wGov = v; page.app.sfx.playToggle(v); } }
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰂛"; title: "Quiet hours"; geoShape: "arch"; available: page.weatherAlertsOn; checked: page.wQuiet; onToggled: (v) => { page.wQuiet = v; page.app.sfx.playToggle(v); } }
        }
        SSlider { visible: page.weatherAlertsOn && page.wQuiet; icon: "󰔛"; title: "Quiet period start"; value: page.quietStartFrac; valueText: String(Math.floor(page.quietStartFrac * 23)).padStart(2, "0") + ":00"; onMoved: (v) => page.quietStartFrac = v }
        SChoice {
            width: parent.width; icon: "󰖕"; title: "Alert types"; multi: true; enabled: page.weatherAlertsOn; opacity: enabled ? 1.0 : 0.45
            options: page.alertKindTitles; selectedList: page.alertTypes
            onMultiToggled: (lab) => { const c = page.alertTypes.slice(); const i = c.indexOf(lab); if (i >= 0) c.splice(i, 1); else c.push(lab); page.alertTypes = c; page.app.sfx.playClick(); }
        }
    }

    // ---- More ----
    SCard {
        title: "More"; icon: "󰒓"
        TileGrid {
            SToggle { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰹑"; title: "Capture on release"; geoShape: "diamond"; checked: page.shotOnRelease; onToggled: (v) => { page.shotOnRelease = v; page.app.sfx.playToggle(v); } }
            SChoice { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰉋"; title: "File manager"; options: page.fileManagerNames; currentIndex: page.fileMgrIdx; onPicked: (i) => { page.fileMgrIdx = i; page.app.sfx.playSwitch(); } }
        }
        SChoice { width: parent.width; icon: "󰉋"; title: "Screenshot folder"; options: page.shotDirNames; currentIndex: page.shotDirIdx; onPicked: (i) => { page.shotDirIdx = i; page.app.sfx.playSwitch(); } }
        SChoice {
            width: parent.width; icon: "󱄽"; title: "Text recognition (OCR)"; multi: true; options: page.ocrLangNames; selectedList: page.ocrLangs
            onMultiToggled: (lab) => { const c = page.ocrLangs.slice(); const i = c.indexOf(lab); if (i >= 0) c.splice(i, 1); else c.push(lab); page.ocrLangs = c; page.app.sfx.playClick(); }
        }
        TileGrid {
            SAction { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰉋"; title: "Screenshot folder"; actionText: "Open"; onTriggered: { page.app.sfx.playClick(); shotDirs.openDir(); } }
            SAction { Layout.fillWidth: true; Layout.preferredWidth: 1; icon: "󰆏"; title: "Copy settings"; actionText: "Copy"; onTriggered: { page.app.sfx.playQuick(); Quickshell.execDetached(["bash", "-c", "cat \"" + Config.settingsJsonPath + "\" | wl-copy"]); page.app.showToast("Settings copied ✓"); } }
        }
    }
}
