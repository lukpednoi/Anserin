import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../"
import "../reusables"

Item {
    id: nav
    objectName: "compact-navigation"
    required property var rootObj
    readonly property var current: rootObj.tabsModel[rootObj.currentTab] || rootObj.tabsModel[0]

    Rectangle {
        objectName: "settings-compact-rail"
        x: rootObj.s(12); y: rootObj.s(12)
        width: rootObj.s(64); height: parent.height - rootObj.s(24)
        radius: ThemeBackend.clampedBorderRadius
        color: railGlass.active ? "transparent" : ThemeBackend.surface0
        GlassFill {
            id: railGlass
            objectName: "settings-compact-rail-glass"
            anchors.fill: parent
            radius: parent.radius
            tintColor: ThemeBackend.surface0
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: rootObj.s(6)
            spacing: rootObj.s(6)
            DistroLogo {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: rootObj.s(40)
                Layout.preferredHeight: rootObj.s(40)
            }
            Flickable {
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: categories.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: categories
                    width: parent.width
                    spacing: rootObj.s(4)
                    Repeater {
                        model: rootObj.tabsModel
                        IconButton {
                            required property var modelData
                            required property int index
                            objectName: "compact-category-" + modelData.key
                            readonly property string label: I18n.t("guide.tabs." + modelData.key, modelData.name)
                            anchors.horizontalCenter: parent.horizontalCenter
                            size: rootObj.s(40)
                            buttonIcon: modelData.icon
                            iconFontSize: rootObj.s(18)
                            accentColor: index === rootObj.currentTab ? ThemeBackend.mauve : ThemeBackend.surface0
                            textColor: index === rootObj.currentTab ? ThemeBackend.crust : ThemeBackend.subtext0
                            Accessible.name: label
                            onClicked: {
                                rootObj.currentTab = index;
                                rootObj.currentSubTab = 0;
                                rootObj.expandedTab = modelData.subtabs ? index : -1;
                            }
                        }
                    }
                }
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            }
        }
    }

    ColumnLayout {
        x: rootObj.s(96); y: rootObj.s(16)
        width: parent.width - x - rootObj.s(24)
        spacing: rootObj.s(8)
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: I18n.t("guide.tabs." + nav.current.key, nav.current.name)
                color: ThemeBackend.text
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(19)
                font.bold: true
                elide: Text.ElideRight
            }
        }
        Flickable {
            objectName: "compact-subcategories"
            visible: !rootObj.orbitTheme
            Layout.fillWidth: true
            implicitHeight: rootObj.s(28)
            contentWidth: subcategories.implicitWidth
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            onContentWidthChanged: contentX = 0
            Row {
                id: subcategories
                spacing: rootObj.s(6)
                Repeater {
                    model: nav.current.subtabs || []
                    ClickButton {
                        required property var modelData
                        required property int index
                        objectName: "compact-subcategory-" + modelData.key
                        width: implicitWidth
                        height: rootObj.s(28)
                        horizontalPadding: rootObj.s(12)
                        // the Theme's first sub-page is the Orbit only with the Orbit page layout; with List it is General
                        buttonText: modelData.id === "ThemeGeneral" && Config.getSetting("theme.generalLayout", "original") !== "orbit" ? I18n.t("guide.tabs.general", "General") : I18n.t("guide.tabs." + modelData.key, modelData.name)
                        textFontSize: rootObj.s(11)
                        accentColor: rootObj.currentSubTab === index ? ThemeBackend.mauve : ThemeBackend.surface0
                        textColor: rootObj.currentSubTab === index ? ThemeBackend.crust : ThemeBackend.subtext0
                        onTriggered: {
                            rootObj.currentSubTab = index;
                            rootObj.expandedTab = rootObj.currentTab;
                        }
                    }
                }
            }
        }
    }
}
