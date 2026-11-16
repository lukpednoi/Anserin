import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import "../../"
import "../../reusables"
import "../../reusables/guide"
import "../shared"

Item {
    id: generalTabRoot
    objectName: "general-settings-page"
    required property var rootObj
    required property int tabIndex

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    onVisibleChanged: {
        if (!visible) {
            if (weatherUnitDropdown.isOpen) weatherUnitDropdown.closePopup();
            locationPopup.close();
            isLocEditOpen = false;
        }
    }

    property var defaultGeneralSettings: {
        "language": "en",
        "openGuideAtStartup": false,
        "wallpaperDir": "",
        "workspaceCount": 8,
        "avatarPath": "",
        "muteSfx": false,
        "sfxVolume": 100,
        "screenshotCaptureOnRelease": false,
        "weatherInterval": 15,
        "weatherUnit": "metric",
        "quickactions": true
    }

    property var generalSettings: Config.getSetting("general", defaultGeneralSettings)
    property string currentLanguage: generalSettings.language !== undefined ? generalSettings.language : I18n.currentLang
    property bool muteSfx: generalSettings.muteSfx !== undefined ? generalSettings.muteSfx : false
    property real sfxVolume: generalSettings.sfxVolume !== undefined ? generalSettings.sfxVolume : 100
    property bool screenshotCaptureOnRelease: generalSettings.screenshotCaptureOnRelease !== undefined ? generalSettings.screenshotCaptureOnRelease : false
    property bool quickactions: generalSettings.quickactions !== undefined ? generalSettings.quickactions : true
    property int weatherInterval: generalSettings.weatherInterval !== undefined ? generalSettings.weatherInterval : 15
    property string weatherUnit: generalSettings.weatherUnit !== undefined ? generalSettings.weatherUnit : "metric"
    property bool isLocEditOpen: false
    Timer {
        id: sfxVolumeDebounceTimer
        interval: 100
        repeat: false
        onTriggered: {
            generalTabRoot.updateGeneralSettings();
        }
    }

    property string currentAvatarSourcePath: {
        let saved = (generalSettings && generalSettings.avatarPath !== undefined) ? generalSettings.avatarPath : "";
        let path = saved !== "" ? saved : (SystemInfo.avatarPath || "");
        if (path.startsWith("file://")) {
            path = path.substring(7);
        }
        return path;
    }

    property var weatherUnitCodes: ["metric", "imperial", "standard"]
    property var weatherUnitNames: ["Celsius", "Fahrenheit", "Kelvin"]

    Connections {
        target: Config
        function onSettingsLoaded() {
            let gs = Config.getSetting("general", generalTabRoot.defaultGeneralSettings);
            generalTabRoot.currentLanguage = gs.language !== undefined ? gs.language : I18n.currentLang;
            generalTabRoot.muteSfx = gs.muteSfx !== undefined ? gs.muteSfx : false;
            generalTabRoot.sfxVolume = gs.sfxVolume !== undefined ? gs.sfxVolume : 100;
            generalTabRoot.screenshotCaptureOnRelease = gs.screenshotCaptureOnRelease !== undefined ? gs.screenshotCaptureOnRelease : false;
            generalTabRoot.quickactions = gs.quickactions !== undefined ? gs.quickactions : true;
            generalTabRoot.weatherInterval = gs.weatherInterval !== undefined ? gs.weatherInterval : 15;
            generalTabRoot.weatherUnit = gs.weatherUnit !== undefined ? gs.weatherUnit : "metric";
            generalTabRoot.generalSettings = gs;
            if (weatherIntervalSelector.value !== generalTabRoot.weatherInterval) {
                weatherIntervalSelector.value = generalTabRoot.weatherInterval;
            }
        }
    }

    Connections {
        target: Location
        function onLocationUpdated() {
            countryInput.text = Location.placeCountry;
            provinceInput.text = Location.placeProvince;
        }
    }

    function updateGeneralSettings() {
        if (typeof Config !== "undefined" && !Config.dataReady) return;
        let current = Object.assign({}, Config.getSetting("general", generalTabRoot.defaultGeneralSettings));
        current.language = generalTabRoot.currentLanguage;
        current.avatarPath = generalTabRoot.currentAvatarSourcePath;
        current.muteSfx = generalTabRoot.muteSfx;
        current.sfxVolume = generalTabRoot.sfxVolume;
        current.screenshotCaptureOnRelease = generalTabRoot.screenshotCaptureOnRelease;
        current.quickactions = generalTabRoot.quickactions;
        current.weatherInterval = generalTabRoot.weatherInterval;
        current.weatherUnit = generalTabRoot.weatherUnit;
        Config.setSetting("general", current);
    }

    ImagePicker {
        id: imagePicker
        rootObj: generalTabRoot.rootObj
        onImageSelected: function(filePath, fileName) {
            let gs = Object.assign({}, generalTabRoot.generalSettings);
            gs.avatarPath = filePath;
            generalTabRoot.generalSettings = gs;
            generalTabRoot.updateGeneralSettings();
        }
    }

    LocationInfo {
        id: locationPopup
        rootObj: generalTabRoot.rootObj
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
                rootObj: generalTabRoot.rootObj
                icon: "󰀄"
                title: I18n.t("guide.general.avatar.title") || "Profile picture"
                description: I18n.t("guide.general.avatar.desc") || "Choose profile picture"
                searchKeywords: "avatar profile picture photo image"

                RowLayout {
                    spacing: rootObj.s(12)

                    ColumnLayout {
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        spacing: rootObj.s(8)

                        ClickButton {
                            Layout.alignment: Qt.AlignRight
                            implicitHeight: rootObj.s(32)
                            buttonText: I18n.t("guide.general.avatar.select")
                            buttonIcon: "󰉋"
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.crust
                            cornerRadius: ThemeBackend.borderRadius
                            horizontalPadding: rootObj.s(14)
                            iconFontSize: rootObj.s(15)
                            textFontSize: rootObj.s(11)
                            onTriggered: imagePicker.openPicker(generalTabRoot.currentAvatarSourcePath)
                        }
                    }

                    Rectangle {
                        id: avatarPreviewRect
                        Layout.preferredWidth: rootObj.s(72)
                        Layout.preferredHeight: rootObj.s(72)
                        radius: ThemeBackend.borderRadius
                        color: ThemeBackend.surface0
                        border.color: Qt.alpha(ThemeBackend.surface2, 0.6)
                        border.width: 1

                        Rectangle {
                            id: maskRect
                            anchors.fill: parent
                            radius: ThemeBackend.borderRadius
                            color: "black"
                            visible: false
                            layer.enabled: true
                        }

                        Canvas {
                            id: personaCanvas
                            anchors.fill: parent
                            visible: generalTabRoot.currentAvatarSourcePath === ""
                            renderTarget: Canvas.FramebufferObject
                            renderStrategy: Canvas.Immediate

                            Connections {
                                target: ThemeBackend
                                function onSurface2Changed() { personaCanvas.requestPaint(); }
                                function onSubtext0Changed() { personaCanvas.requestPaint(); }
                                function onTextChanged() { personaCanvas.requestPaint(); }
                            }

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.clearRect(0, 0, width, height);

                                var cx = width / 2;
                                var headRadius = width * 0.19;
                                var headCenterY = height * 0.36;

                                ctx.fillStyle = ThemeBackend.surface2;

                                ctx.beginPath();
                                ctx.arc(cx, headCenterY, headRadius, 0, Math.PI * 2);
                                ctx.fill();

                                ctx.beginPath();
                                ctx.moveTo(cx - width * 0.32, height * 0.88);
                                ctx.bezierCurveTo(cx - width * 0.28, height * 0.58, cx + width * 0.28, height * 0.58, cx + width * 0.32, height * 0.88);
                                ctx.bezierCurveTo(cx + width * 0.20, height * 0.94, cx - width * 0.20, height * 0.94, cx - width * 0.32, height * 0.88);
                                ctx.closePath();
                                ctx.fill();
                            }
                        }

                        Loader {
                            id: avatarLoader
                            anchors.fill: parent
                            visible: false
                            active: generalTabRoot.currentAvatarSourcePath !== ""
                            sourceComponent: Image {
                                source: generalTabRoot.currentAvatarSourcePath !== "" ? "file://" + generalTabRoot.currentAvatarSourcePath : ""
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                            }
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: avatarLoader.item
                            maskEnabled: true
                            maskSource: maskRect
                            visible: generalTabRoot.currentAvatarSourcePath !== ""
                        }
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󱓞"
                visible: rootObj.anserinInterface !== true
                title: I18n.t("guide.general.quickactions.title") || "Quickactions"
                description: I18n.t("guide.general.quickactions.desc") || "Enable floating quickactions overlay"

                Toggle {
                    checked: generalTabRoot.quickactions
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        generalTabRoot.quickactions = c;
                        generalTabRoot.updateGeneralSettings();
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰝟"
                title: I18n.t("guide.general.mutesfx.title") || "Mute SFX"
                description: I18n.t("guide.general.mutesfx.desc") || "Disable user interface sound effects"

                Toggle {
                    checked: generalTabRoot.muteSfx
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        generalTabRoot.muteSfx = c;
                        if (typeof Sounds !== "undefined") {
                            Sounds.generalSettings = Object.assign({}, Sounds.generalSettings || {}, { "muteSfx": c });
                        }
                        generalTabRoot.updateGeneralSettings();
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰕾"
                stackedControlFill: true
                title: I18n.t("guide.general.sfxvolume.title") || "SFX Volume"
                description: I18n.t("guide.general.sfxvolume.desc") || "Volume level for user interface sound effects"

                Draggable {
                    id: sfxVolumeSlider
                    Layout.fillWidth: true
                    implicitWidth: rootObj.s(180)
                    implicitHeight: rootObj.s(18)
                    from: 0
                    to: 100
                    stepSize: 1
                    defaultValue: 100
                    showValueBubble: true
                    valueFormatter: function(v) { return Math.round(v) + "%" }
                    value: generalTabRoot.sfxVolume
                    backgroundColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    handleColor: ThemeBackend.text
                    handleBorderColor: ThemeBackend.mantle
                    onMoved: function(val) {
                        let rounded = Math.round(val);
                        if (generalTabRoot.sfxVolume !== rounded) {
                            generalTabRoot.sfxVolume = rounded;
                            if (typeof Sounds !== "undefined") {
                                Sounds.generalSettings = Object.assign({}, Sounds.generalSettings || {}, { "sfxVolume": rounded });
                            }
                            sfxVolumeDebounceTimer.restart();
                        }
                    }
                    onDragFinished: {
                        sfxVolumeDebounceTimer.stop();
                        generalTabRoot.updateGeneralSettings();
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰍎"
                title: I18n.t("guide.general.location.title")
                description: I18n.t("guide.general.location.desc")
                searchKeywords: "location coordinates city country province gps"
                showDivider: generalTabRoot.isLocEditOpen
                dividerColor: Qt.alpha(ThemeBackend.surface1, 0.2)
                innerSpacing: generalTabRoot.isLocEditOpen ? rootObj.s(12) : 0
                Behavior on innerSpacing { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                animateHeight: true
                animationDuration: 300

                LoaderIcon {
                    id: detectLoader
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    running: Location.isDetecting
                    visible: Location.isDetecting
                    accentColor: ThemeBackend.mauve
                }

                ClickButton {
                    implicitHeight: rootObj.s(32)
                    buttonText: "Auto-detect"
                    buttonIcon: "󰢹"
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(12)
                    iconFontSize: rootObj.s(15)
                    textFontSize: rootObj.s(12)
                    onTriggered: {
                        generalTabRoot.isLocEditOpen = false;
                        Location.detectAuto();
                    }
                }

                ClickButton {
                    implicitHeight: rootObj.s(32)
                    buttonText: Location.city
                    buttonIcon: "󰍎"
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(12)
                    iconFontSize: rootObj.s(15)
                    textFontSize: rootObj.s(12)
                    onTriggered: locationPopup.open()
                }

                IconButton {
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    cornerRadius: ThemeBackend.borderRadius
                    buttonIcon: "󰏫"
                    iconFontSize: rootObj.s(16)
                    accentColor: generalTabRoot.isLocEditOpen ? ThemeBackend.surface1 : ThemeBackend.surface0
                    textColor: generalTabRoot.isLocEditOpen ? ThemeBackend.mauve : ThemeBackend.text
                    onClicked: generalTabRoot.isLocEditOpen = !generalTabRoot.isLocEditOpen
                }

                bottomContent: [
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(12)
                        visible: generalTabRoot.isLocEditOpen || opacity > 0.01
                        opacity: generalTabRoot.isLocEditOpen ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

                        Input {
                            id: countryInput
                            Layout.fillWidth: true
                            placeholderText: "Country"
                            text: Location.placeCountry
                            onTextEdited: (t) => Location.suggest("country", t, "")
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            horizontalPadding: rootObj.s(12)
                            verticalPadding: rootObj.s(6)
                            fontPixelSize: rootObj.s(12)
                        }

                        Input {
                            id: provinceInput
                            Layout.fillWidth: true
                            placeholderText: "Province"
                            text: Location.placeProvince
                            onTextEdited: (t) => Location.suggest("province", t, countryInput.text)
                            baseColor: ThemeBackend.surface0
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.text
                            subTextColor: ThemeBackend.subtext0
                            borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                            cornerRadius: ThemeBackend.borderRadius
                            horizontalPadding: rootObj.s(12)
                            verticalPadding: rootObj.s(6)
                            fontPixelSize: rootObj.s(12)
                        }

                        // names offered while typing (Open-Meteo, the same lookup Apply uses); a pick only fills the field
                        SuggestList {
                            parent: countryInput
                            shown: countryInput.hasFocus
                            items: Location.suggestKind === "country" ? Location.suggestions : []
                            current: countryInput.text
                            fontPixelSize: rootObj.s(12)
                            onPicked: (n) => { countryInput.text = n; Location.clearSuggestions(); }
                        }
                        SuggestList {
                            parent: provinceInput
                            shown: provinceInput.hasFocus
                            items: Location.suggestKind === "province" ? Location.suggestions : []
                            current: provinceInput.text
                            fontPixelSize: rootObj.s(12)
                            onPicked: (n) => { provinceInput.text = n; Location.clearSuggestions(); }
                        }

                        ClickButton {
                            Layout.preferredHeight: rootObj.s(32)
                            buttonText: "Apply"
                            accentColor: ThemeBackend.mauve
                            textColor: ThemeBackend.crust
                            cornerRadius: ThemeBackend.borderRadius
                            horizontalPadding: rootObj.s(16)
                            textFontSize: rootObj.s(12)
                            onTriggered: {
                                Location.setPlace(countryInput.text, provinceInput.text);
                            }
                        }
                    },
                    // why the lock did not apply ("Not found")
                    Text {
                        visible: generalTabRoot.isLocEditOpen && Location.placeError !== ""
                        text: Location.placeError
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: rootObj.s(12)
                        color: ThemeBackend.red
                    }
                ]
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰔛"
                title: I18n.t("guide.general.weatherinterval.title") || "Weather Polling Interval"
                description: I18n.t("guide.general.weatherinterval.desc") || "Polling frequency in minutes"

                NumberSelector {
                    id: weatherIntervalSelector
                    implicitWidth: rootObj.s(180)
                    implicitHeight: rootObj.s(32)
                    from: 1
                    to: 1440
                    stepSize: 1
                    decimals: 0
                    suffix: " min"
                    value: generalTabRoot.weatherInterval
                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    buttonColor: ThemeBackend.surface1
                    buttonTextColor: ThemeBackend.text
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: {
                        let val = Math.round(value);
                        if (val !== generalTabRoot.weatherInterval && val >= 1) {
                            generalTabRoot.weatherInterval = val;
                            generalTabRoot.updateGeneralSettings();
                            if (typeof Weather !== "undefined") {
                                Weather.refreshInterval = generalTabRoot.weatherInterval * 60000;
                            }
                        }
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰔏"
                title: I18n.t("guide.general.weatherunit.title") || "Weather Unit"
                description: I18n.t("guide.general.weatherunit.desc") || "Temperature scale for weather displays"

                Dropdown {
                    id: weatherUnitDropdown
                    implicitWidth: rootObj.s(180)
                    implicitHeight: rootObj.s(32)
                    options: generalTabRoot.weatherUnitNames
                    currentIndex: {
                        let idx = generalTabRoot.weatherUnitCodes.indexOf(generalTabRoot.weatherUnit);
                        return idx !== -1 ? idx : 0;
                    }
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(index, value) {
                        generalTabRoot.weatherUnit = generalTabRoot.weatherUnitCodes[index];
                        generalTabRoot.updateGeneralSettings();
                        if (typeof Weather !== "undefined") {
                            Weather.unit = generalTabRoot.weatherUnit;
                        }
                    }
                }
            }

            WeatherAlertsLogic { id: weatherAlerts }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰀦"
                title: "Weather alerts"
                description: "Warn about rain, storms, heat and other changes in the forecast"

                Toggle {
                    
                    checked: weatherAlerts.alertsOn
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) { weatherAlerts.set("enabled", c); }
                }
            }
            SettingsRow {
                rootObj: generalTabRoot.rootObj
                opacity: weatherAlerts.alertsOn ? 1 : 0.5
                icon: "󰖕"
                title: "Twice-daily forecast"
                description: "A short forecast in the morning and the evening"

                Toggle {
                    enabled: weatherAlerts.alertsOn
                    checked: weatherAlerts.settings.dailyForecast === true
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) { weatherAlerts.set("dailyForecast", c); }
                }
            }
            SettingsRow {
                rootObj: generalTabRoot.rootObj
                opacity: weatherAlerts.alertsOn ? 1 : 0.5
                icon: "󰒡"
                title: "Government warnings"
                description: "Official warnings for your location, where a source is available"

                Toggle {
                    enabled: weatherAlerts.alertsOn
                    checked: weatherAlerts.settings.governmentWarnings === true
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) { weatherAlerts.set("governmentWarnings", c); }
                }
            }
            SettingsRow {
                rootObj: generalTabRoot.rootObj
                visible: weatherAlerts.alertsOn && weatherAlerts.settings.governmentWarnings === true
                icon: "󰋼"
                title: "Warning source status"
                description: weatherAlerts.govStatusText()
            }
            SettingsRow {
                rootObj: generalTabRoot.rootObj
                opacity: weatherAlerts.alertsOn ? 1 : 0.5
                icon: "󰂛"
                title: "Quiet hours"
                description: "Hold alerts back at night; severe warnings still come through"

                Toggle {
                    enabled: weatherAlerts.alertsOn
                    checked: weatherAlerts.settings.quietHours === true
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) { weatherAlerts.set("quietHours", c); }
                }
            }
            SettingsRow {
                rootObj: generalTabRoot.rootObj
                visible: weatherAlerts.quietOn
                icon: "󰔛"
                title: "Quiet period"
                description: "Drag the handles to choose when alerts are held back"

                TimeRangeSlider {
                    start: weatherAlerts.settings.quietStart
                    end: weatherAlerts.settings.quietEnd
                    accentColor: ThemeBackend.mauve
                    trackColor: ThemeBackend.surface2
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    onCommitted: function(st, en) { weatherAlerts.setQuiet(st, en); }
                }
            }

            Repeater {
                model: weatherAlerts.kinds
                delegate: SettingsRow {
                    required property var modelData
                    rootObj: generalTabRoot.rootObj
                    opacity: weatherAlerts.alertsOn ? 1 : 0.5
                    icon: "󰖕"
                    title: modelData.title
                    description: "Alert type"
                    Toggle {
                        enabled: weatherAlerts.alertsOn
                        checked: weatherAlerts.settings[modelData.key] === true
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface1
                        handleColor: ThemeBackend.crust
                        handleOffColor: ThemeBackend.text
                        onToggled: function(c) { weatherAlerts.set(modelData.key, c); }
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰹑"
                title: I18n.t("guide.general.screenshot_on_release.title") || "Capture region on mouse release"
                description: I18n.t("guide.general.screenshot_on_release.desc") || "Take the screenshot as soon as you finish dragging, without clicking the shutter"

                Toggle {
                    checked: generalTabRoot.screenshotCaptureOnRelease
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface1
                    handleColor: ThemeBackend.crust
                    handleOffColor: ThemeBackend.text
                    onToggled: function(c) {
                        generalTabRoot.screenshotCaptureOnRelease = c;
                        generalTabRoot.updateGeneralSettings();
                    }
                }
            }

            // what Anserin opens folders with (singletons/system/FileManager.qml)
            SettingsRow {
                rootObj: generalTabRoot.rootObj
                visible: FileManager.available.length > 1
                icon: "󰉋"
                title: "File manager"
                description: "Opens folders from Anserin: the desktop menu's Files, screenshots, wallpapers and the launcher"

                Switch {
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    implicitWidth: rootObj.s(200)
                    implicitHeight: rootObj.s(32)
                    options: FileManager.available.map(c => c.name)
                    currentIndex: Math.max(0, FileManager.available.findIndex(c => c.id === FileManager.chosen))
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    textColor: ThemeBackend.subtext0
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onToggled: (index) => FileManager.setChosen(FileManager.available[index].id)
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰉋"
                title: "Screenshot folder"
                description: "Where screenshots are saved"

                ScreenshotDirLogic { id: shotDirs }

                IconButton {
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    cornerRadius: rootObj.s(6)
                    buttonIcon: "󰉋"
                    iconFontSize: rootObj.s(14)
                    accentColor: ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                    onClicked: shotDirs.openDir()
                }

                Dropdown {
                    Layout.preferredWidth: rootObj.s(260)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    options: shotDirs.dirs
                    currentIndex: Math.max(0, options.indexOf(shotDirs.currentDir))
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onSelected: (index, value) => shotDirs.setDir(value)
                    onClicked: shotDirs.scan()
                }
            }

            OcrLanguagesLogic { id: ocrLangs }

            // the screenshot tool's text recognition (the 󱄽 button): which languages it can read
            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󱄽"
                title: "Text recognition"
                description: ocrLangs.error || (ocrLangs.busy ? "Downloading " + ocrLangs.nameOf(ocrLangs.busyCode) + "…" : "Languages the screenshot tool can read; others download when picked")

                bottomContent: Flow {
                    Layout.fillWidth: true
                    spacing: rootObj.s(6)
                    Repeater {
                        model: ocrLangs.languages
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool picked: ocrLangs.installed.indexOf(modelData.code) >= 0
                            readonly property bool loading: ocrLangs.busyCode === modelData.code
                            width: chipText.implicitWidth + rootObj.s(20)
                            height: rootObj.s(28)
                            radius: height / 2
                            color: picked ? ThemeBackend.mauve : (chipMouse.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
                            opacity: loading ? 0.6 : 1
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: (parent.loading ? "󰇚 " : "") + modelData.name
                                color: parent.picked ? ThemeBackend.crust : ThemeBackend.text
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                            }
                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: modelData.code === "eng" ? Qt.ArrowCursor : Qt.PointingHandCursor
                                enabled: modelData.code !== "eng"
                                onClicked: {
                                    Sounds.playSfx("reusables/switch/sfx.wav");
                                    let next = ocrLangs.installed.filter(c => c !== modelData.code);
                                    if (!parent.picked) next.push(modelData.code);
                                    ocrLangs.setLanguages(next);
                                }
                            }
                        }
                    }
                }
            }

            SettingsRow {
                rootObj: generalTabRoot.rootObj
                icon: "󰆏"
                title: I18n.t("guide.general.copysettings.title") || "Copy settings"
                description: I18n.t("guide.general.copysettings.desc") || "Copy configuration JSON to clipboard"

                ClickButton {
                    implicitHeight: rootObj.s(32)
                    buttonText: "Copy settings"
                    buttonIcon: "󰆏"
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    cornerRadius: ThemeBackend.borderRadius
                    horizontalPadding: rootObj.s(14)
                    iconFontSize: rootObj.s(15)
                    textFontSize: rootObj.s(12)
                    onTriggered: {
                        Quickshell.execDetached(["bash", "-c", "cat \"" + Config.settingsJsonPath + "\" | wl-copy"]);
                    }
                }
            }
        }
    }
}
