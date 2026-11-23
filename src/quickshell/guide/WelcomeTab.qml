import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Io
import "../"

Item {
    id: welcomeTabRoot
    required property var rootObj
    required property int tabIndex

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex

    property string shellVersion: "0.0.1"
    // sideways: the logo on the left with the name, a version chip and the author beside it (the Control
    // Center's board); the Settings window keeps the centred layout
    property bool sideways: false
    property color accent: ThemeBackend.mauve
    FileView {
        path: Caching.anserinDir + "/version.txt"
        onLoaded: { let version = text().trim(); if (version) welcomeTabRoot.shellVersion = version; }
    }

    property bool revealed: true
    opacity: revealed ? 1.0 : 0.0
    property real slideY: revealed ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    function activateTab() {
        if (!rootObj.visible || !visible) return;
        revealed = true;
        logoFillLevel = 0.0;
        logoFillAnim.restart();
    }

    Component.onCompleted: {
        if (visible) activateTab();
    }

    property real titleWavePhase: 0.0
    NumberAnimation on titleWavePhase {
        running: welcomeTabRoot.visible && rootObj.visible
        loops: Animation.Infinite
        from: 0
        to: Math.PI * 2
        duration: 7000
    }

    Connections {
        target: rootObj
        function onActivationCounterChanged() {
            if (welcomeTabRoot.visible) {
                activateTab();
            }
        }
        function onVisibleChanged() {
            if (rootObj.visible && welcomeTabRoot.visible) activateTab();
            else logoFillAnim.stop();
        }
    }

    onVisibleChanged: {
        if (visible) activateTab();
        else logoFillAnim.stop();
    }

    property real logoFillLevel: 1.15

    NumberAnimation {
        id: logoFillAnim
        target: welcomeTabRoot
        property: "logoFillLevel"
        from: 0.0
        to: 1.15
        duration: 6500
        easing.type: Easing.OutCubic
    }

    GridLayout {
        anchors.centerIn: welcomeTabRoot.sideways ? undefined : parent
        anchors.left: welcomeTabRoot.sideways ? parent.left : undefined
        anchors.leftMargin: rootObj.s(18)
        anchors.verticalCenter: welcomeTabRoot.sideways ? parent.verticalCenter : undefined
        columns: welcomeTabRoot.sideways ? 2 : 1
        columnSpacing: rootObj.s(20)
        rowSpacing: rootObj.s(12)          // the centred layout's former ColumnLayout spacing

        Item {
            id: logoContainer
            objectName: "welcome-logo"
            Layout.alignment: welcomeTabRoot.sideways ? Qt.AlignVCenter : Qt.AlignHCenter
            Layout.preferredWidth: rootObj.s(welcomeTabRoot.sideways ? 124 : 170)
            Layout.preferredHeight: rootObj.s(welcomeTabRoot.sideways ? 124 : 170)

            Item {
                id: paddedMaskSource
                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.smooth: true

                Image {
                    anchors.centerIn: parent
                    width: rootObj.s(welcomeTabRoot.sideways ? 110 : 150)
                    height: rootObj.s(welcomeTabRoot.sideways ? 110 : 150)
                    source: "file://" + (typeof Caching !== "undefined" && Caching.anserinDir ? Caching.anserinDir : (rootObj && rootObj.appPaths ? rootObj.appPaths.anserinDir : "")) + "/assets/logo.svg"
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    antialiasing: true
                }
            }

            Item {
                id: logoColorBlock
                anchors.fill: parent
                visible: false
                layer.enabled: true
                layer.smooth: true

                Rectangle { anchors.fill: parent; color: ThemeBackend.text }

                ShaderEffect {
                    id: logoWaveCanvas
                    anchors.fill: parent

                    property real wavePhase: 0.0
                    NumberAnimation on wavePhase {
                        running: welcomeTabRoot.visible && rootObj.visible && welcomeTabRoot.logoFillLevel < 1.14
                        loops: Animation.Infinite
                        from: 0; to: Math.PI * 2; duration: 4500
                    }

                    property vector2d itemSize: Qt.vector2d(width, height)
                    property real fillLevel: welcomeTabRoot.logoFillLevel
                    property color baseColor: ThemeBackend.mauve
                    property vector4d params: Qt.vector4d(rootObj.s(12), 0.0, 0.0, 0.0)

                    fragmentShader: "file://" + Caching.anserinDir + "/assets/shaders/fluid/logo_water_wave.frag.qsb"
                }
            }

            MultiEffect {
                source: logoColorBlock
                anchors.fill: parent
                maskEnabled: true
                maskSource: paddedMaskSource
                autoPaddingEnabled: false
                shadowEnabled: true
                shadowColor: ThemeBackend.mauve
                shadowBlur: 1.0
                shadowOpacity: 0.45
                shadowVerticalOffset: 0
            }
        }

        ColumnLayout {
            Layout.alignment: welcomeTabRoot.sideways ? (Qt.AlignLeft | Qt.AlignVCenter) : Qt.AlignHCenter
            spacing: rootObj.s(welcomeTabRoot.sideways ? 8 : 4)

            Row {
                id: titleRow
                objectName: "welcome-title"
                Layout.alignment: welcomeTabRoot.sideways ? Qt.AlignLeft : Qt.AlignHCenter
                spacing: 0

                property string mainTitle: "Anserin"
                property string verText: welcomeTabRoot.sideways ? "" : " v" + welcomeTabRoot.shellVersion
                property string fullText: mainTitle + verText

                Repeater {
                    model: Array.from(parent.fullText)
                    Text {
                        id: charItem
                        required property string modelData
                        required property int index
                        readonly property bool isMain: index < titleRow.mainTitle.length
                        readonly property bool isStarI: isMain && modelData === "i"

                        text: isStarI ? "\u0131" : (modelData === " " ? "\u00A0" : modelData)
                        font.family: ThemeBackend.fontFamily
                        font.weight: isMain ? Font.Black : Font.Bold
                        font.pixelSize: isMain ? rootObj.s(welcomeTabRoot.sideways ? 32 : 24) : rootObj.s(12)
                        color: isMain ? ThemeBackend.text : ThemeBackend.subtext0

                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: isMain ? 0 : rootObj.s(4)

                        transform: Translate {
                            y: Math.sin(welcomeTabRoot.titleWavePhase - index * 0.35) * rootObj.s(2.5)
                        }

                        Shape {
                            id: iStar
                            visible: charItem.isStarI
                            readonly property real sz: rootObj.s(welcomeTabRoot.sideways ? 12 : 9)
                            width: sz
                            height: sz
                            anchors.horizontalCenter: parent.horizontalCenter
                            y: rootObj.s(welcomeTabRoot.sideways ? 2.5 : 2)
                            preferredRendererType: Shape.CurveRenderer

                            ShapePath {
                                strokeWidth: 0
                                strokeColor: "transparent"
                                fillColor: welcomeTabRoot.accent
                                startX: iStar.sz * 0.5; startY: 0
                                PathQuad { x: iStar.sz; y: iStar.sz * 0.5; controlX: iStar.sz * 0.56; controlY: iStar.sz * 0.44 }
                                PathQuad { x: iStar.sz * 0.5; y: iStar.sz; controlX: iStar.sz * 0.56; controlY: iStar.sz * 0.56 }
                                PathQuad { x: 0; y: iStar.sz * 0.5; controlX: iStar.sz * 0.44; controlY: iStar.sz * 0.56 }
                                PathQuad { x: iStar.sz * 0.5; y: 0; controlX: iStar.sz * 0.44; controlY: iStar.sz * 0.44 }
                            }
                        }
                    }
                }
            }

            // the version as a chip (sideways only; centred, it follows the name)
            Rectangle {
                visible: welcomeTabRoot.sideways
                implicitWidth: verChip.implicitWidth + rootObj.s(20); implicitHeight: rootObj.s(24); radius: height / 2
                color: Qt.alpha(welcomeTabRoot.accent, 0.18)
                Text { id: verChip; anchors.centerIn: parent; text: "v" + welcomeTabRoot.shellVersion
                       font.family: ThemeBackend.fontFamily; font.pixelSize: rootObj.s(11); font.bold: true; color: welcomeTabRoot.accent }
            }

            Text {
                text: I18n.t("guide.welcome.by_author", { author: "M<span style='font-size: " + rootObj.s(18) + "px'>✦</span>Mi" })
                textFormat: Text.RichText
                font.family: ThemeBackend.fontFamily
                font.pixelSize: rootObj.s(14)
                color: ThemeBackend.subtext0
                Layout.alignment: welcomeTabRoot.sideways ? Qt.AlignLeft : Qt.AlignHCenter
            }
        }

    }
}
