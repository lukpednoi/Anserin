import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../../reusables"
import "../../reusables/guide"

Item {
    id: root
    objectName: "theme-layout-page"
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 2
    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex && rootObj.currentSubTab === subTabIndex
    readonly property var themeSettings: Config.getSetting("theme", {})
    readonly property string selectedLayout: themeSettings.generalLayout === "orbit" ? "orbit" : "original"
    readonly property var imageStyles: ["rectangle", "circle", "bordered"]
    readonly property string imageStyle: imageStyles.indexOf(themeSettings.orbitImageStyle) >= 0 ? themeSettings.orbitImageStyle : "rectangle"
    readonly property string orbitBackground: themeSettings.orbitBackground === "transparent" ? "transparent" : "wifi"
    readonly property string orbitRingStyle: themeSettings.orbitRingStyle === "wifi" ? "wifi" : "original"
    Flickable {
        anchors.fill: parent
        anchors.margins: rootObj.s(8)
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ColumnLayout {
            id: content
            width: parent.width
            spacing: rootObj.s(16)
            Text {
                text: "Page layout"
                color: ThemeBackend.text
                font { family: ThemeBackend.fontFamily; pixelSize: rootObj.s(16); bold: true }
            }
            PreviewStrip {
                Layout.fillWidth: true
                columns: 2
                columnSpacing: rootObj.s(12)
                carousel: false   // only two cards: both are shown side by side
                Repeater {
                    model: [{key:"original", name:"List"}, {key:"orbit", name:"Orbit"}]
                    Rectangle {
                        id: card
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: previewBox.height + rootObj.s(48)
                        radius: ThemeBackend.clampedBorderRadius
                        color: cardGlass.active ? "transparent" : (cardMouse.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0)
                        GlassFill {
                            id: cardGlass
                            objectName: "theme-style-card-glass-" + card.modelData.key
                            anchors.fill: parent
                            radius: card.radius
                            allowed: !!root.rootObj.compactSettings
                            tintColor: cardMouse.containsMouse ? ThemeBackend.surface1 : ThemeBackend.surface0
                        }
                        border.width: root.selectedLayout === modelData.key ? rootObj.s(2) : 1
                        border.color: root.selectedLayout === modelData.key ? ThemeBackend.mauve : ThemeBackend.surface1
                        property real popScale: 1
                        scale: popScale
                        Behavior on color { ColorAnimation { duration: 180 } }
                        SequentialAnimation {
                            id: pop
                            NumberAnimation { target: card; property: "popScale"; to: .97; duration: 100; easing.type: Easing.OutQuad }
                            NumberAnimation { target: card; property: "popScale"; to: 1; duration: 250; easing.type: Easing.OutBack }
                        }
                        Rectangle {
                            id: previewBox
                            x: rootObj.s(8); y: rootObj.s(8)
                            width: parent.width - rootObj.s(16)
                            height: width * 560 / 880
                            radius: ThemeBackend.clampedBorderRadius
                            color: ThemeBackend.mantle
                            clip: true
                            Loader {
                                objectName: "theme-layout-preview-" + card.modelData.key
                                anchors.fill: parent
                                active: root.visible
                                enabled: false
                                sourceComponent: ThemeLayoutPreview {
                                    appearance: card.modelData.key
                                    imageStyle: root.imageStyle
                                    borderStyle: root.themeSettings.orbitBorderColor === "white" ? "white" : "theme"
                                    connectionStyle: root.themeSettings.orbitConnectionStyle === "wifi" ? "wifi" : "link"
                                    ringStyle: root.orbitRingStyle
                                }
                            }
                        }
                        Text {
                            x: rootObj.s(12); y: previewBox.y + previewBox.height + rootObj.s(10)
                            text: card.modelData.name
                            color: root.selectedLayout === card.modelData.key ? ThemeBackend.mauve : ThemeBackend.text
                            font { family: ThemeBackend.fontFamily; pixelSize: rootObj.s(12); bold: true }
                        }
                        MouseArea {
                            id: cardMouse
                            objectName: "theme-layout-" + card.modelData.key
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                pop.restart();
                                Sounds.playSfx("reusables/clickbutton/click.wav");
                                Config.setSetting("theme.generalLayout", card.modelData.key);
                            }
                        }
                    }
                }
            }
            SettingsRow {
                rootObj: root.rootObj
                title: "Center image"
                icon: "󰸉"
                visible: root.selectedLayout === "orbit"
                Switch {
                    id: imageStyleSwitch
                    objectName: "theme-orbit-image-style"
                    implicitWidth: rootObj.s(240)
                    implicitHeight: rootObj.s(32)
                    options: ["Square", "Round", "Round + ring"]
                    currentIndex: root.imageStyles.indexOf(root.imageStyle)
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    textColor: ThemeBackend.subtext0
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onToggled: index => Config.setSetting("theme.orbitImageStyle", root.imageStyles[index])
                    Connections {
                        target: root
                        function onImageStyleChanged() { imageStyleSwitch.currentIndex = root.imageStyles.indexOf(root.imageStyle); }
                    }
                }
            }
            SettingsRow {
                rootObj: root.rootObj
                title: "Ring color"
                icon: "󰏘"
                visible: root.selectedLayout === "orbit"
                Switch {
                    id: borderColorSwitch
                    objectName: "theme-orbit-border-color"
                    implicitWidth: rootObj.s(144)
                    implicitHeight: rootObj.s(32)
                    options: ["White", "Theme"]
                    currentIndex: root.themeSettings.orbitBorderColor === "white" ? 0 : 1
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    textColor: ThemeBackend.subtext0
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onToggled: index => Config.setSetting("theme.orbitBorderColor", index === 0 ? "white" : "theme")
                    Connections {
                        target: root
                        function onThemeSettingsChanged() { borderColorSwitch.currentIndex = root.themeSettings.orbitBorderColor === "white" ? 0 : 1; }
                    }
                }
            }
            SettingsRow {
                rootObj: root.rootObj
                title: "Links"
                icon: "󰖩"
                visible: root.selectedLayout === "orbit"
                Switch {
                    id: connectionSwitch
                    objectName: "theme-orbit-connection"
                    implicitWidth: rootObj.s(144)
                    implicitHeight: rootObj.s(32)
                    options: ["Flow", "Lightning"]
                    currentIndex: root.themeSettings.orbitConnectionStyle === "wifi" ? 1 : 0
                    accentColor: ThemeBackend.mauve; baseColor: ThemeBackend.surface0
                    textColor: ThemeBackend.subtext0; activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onToggled: index => Config.setSetting("theme.orbitConnectionStyle", index === 1 ? "wifi" : "link")
                    Connections {
                        target: root
                        function onThemeSettingsChanged() { connectionSwitch.currentIndex = root.themeSettings.orbitConnectionStyle === "wifi" ? 1 : 0; }
                    }
                }
            }
            Repeater {
                model: [
                    {title: "Background", name: "theme-orbit-background", setting: "orbitBackground", options: ["Panel", "Transparent"], values: ["wifi", "transparent"]},
                    {title: "Rings", name: "theme-orbit-rings", setting: "orbitRingStyle", options: ["Pulse", "Lightning"], values: ["original", "wifi"]}
                ]
                SettingsRow {
                    id: styleRow
                    required property var modelData
                    rootObj: root.rootObj
                    title: modelData.title
                    icon: "󰖩"
                    visible: root.selectedLayout === "orbit"
                    readonly property int selectedIndex: modelData.values.indexOf(modelData.setting === "orbitBackground" ? root.orbitBackground : root.orbitRingStyle)
                    onSelectedIndexChanged: if (styleSwitch) styleSwitch.currentIndex = selectedIndex
                    Switch {
                        id: styleSwitch
                        objectName: styleRow.modelData.name
                        implicitWidth: rootObj.s(144)
                        implicitHeight: rootObj.s(32)
                        options: styleRow.modelData.options
                        currentIndex: styleRow.selectedIndex
                        accentColor: ThemeBackend.mauve
                        baseColor: ThemeBackend.surface0
                        textColor: ThemeBackend.subtext0
                        activeTextColor: ThemeBackend.crust
                        cornerRadius: ThemeBackend.borderRadius
                        fontPixelSize: rootObj.s(11)
                        onToggled: index => Config.setSetting("theme." + styleRow.modelData.setting, styleRow.modelData.values[index])
                    }
                }
            }
            Text {
                visible: !AnserinMode.active
                text: "Window border"
                color: ThemeBackend.text
                font { family: ThemeBackend.fontFamily; pixelSize: rootObj.s(16); bold: true }
            }
            SettingsRow {
                rootObj: root.rootObj
                visible: !AnserinMode.active
                title: "Style"
                description: "Modern connects panels to the screen frame and opens Quick Actions on hover."
                icon: "󰕰"
                Switch {
                    id: windowBorderSwitch
                    objectName: "theme-window-border"
                    implicitWidth: rootObj.s(192)
                    implicitHeight: rootObj.s(32)
                    options: ["Classic", "Modern"]
                    currentIndex: ScreenEdges.modern ? 1 : 0
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    textColor: ThemeBackend.subtext0
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onToggled: index => Config.setSetting("theme.windowBorder", index === 1 ? "modern" : "classic")
                    Connections {
                        target: ScreenEdges
                        function onModernChanged() { windowBorderSwitch.currentIndex = ScreenEdges.modern ? 1 : 0; }
                    }
                }
            }
            SettingsRow {
                rootObj: root.rootObj
                title: "Border thickness"
                icon: "󰝤"
                visible: ScreenEdges.modern && !AnserinMode.active
                NumberSelector {
                    id: borderThicknessSelector
                    objectName: "theme-window-border-thickness"
                    implicitWidth: rootObj.s(160)
                    implicitHeight: rootObj.s(32)
                    from: 2; to: 32; stepSize: 1
                    value: ScreenEdges.thickness
                    suffix: " px"
                    baseColor: ThemeBackend.surface0
                    buttonColor: ThemeBackend.surface1
                    buttonTextColor: ThemeBackend.text
                    textColor: ThemeBackend.text
                    accentColor: ThemeBackend.mauve
                    cornerRadius: ThemeBackend.borderRadius
                    fontFamily: ThemeBackend.fontFamily
                    fontPixelSize: rootObj.s(11)
                    onTriggered: Config.setSetting("theme.windowBorderThickness", value)
                    Connections {
                        target: ScreenEdges
                        function onThicknessChanged() { borderThicknessSelector.value = ScreenEdges.thickness; }
                    }
                }
            }
            Text {
                text: "Wallpaper"
                color: ThemeBackend.text
                font { family: ThemeBackend.fontFamily; pixelSize: rootObj.s(16); bold: true }
            }
            WallpaperTransitions {
                rootObj: root.rootObj
            }
        }
        ScrollBar.vertical: ScrollBar {}
    }
}
