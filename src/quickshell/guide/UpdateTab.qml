import QtQuick
import Quickshell
import Quickshell.Widgets
import "../"
import "../reusables"

// Settings / Control → Update: Anserin's update posts (Updates.qml). Two tabs, centred (Latest shows its version
// on the left of them and its date on the right):
//   Latest — the newest version's posts. All — every version (a row of versions, then that version's posts), with
//   Update (anserin -up) beside the row when a version newer than this copy exists.
// A card is the post's title with its tag below on the left.
// Opening one shows the post (Reddit-like): tag, big title, version and date, its picture, the resources it uses
// (Feature and Improved), the details and a Fix bug's report. Pages change with the Control tab's own fade and
// slide (BoardSettings.qml). Lists scroll only when they do not fit.
Item {
    id: page
    objectName: "update-page"
    required property var rootObj
    required property int tabIndex
    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex

    function s(v) { return rootObj.s(v); }
    readonly property real cardRadius: Math.min(ThemeBackend.borderRadius, s(16))
    readonly property color cardColor: Qt.darker(ThemeBackend.surface0, 1.04)

    property int tab: 0                 // 0 Latest, 1 All
    property real pillX: 0
    property real pillW: 0
    property int pickAll: 0
    readonly property var tabVersions: tab === 1 ? Updates.versions : []
    readonly property int pick: Math.max(0, Math.min(pickAll, tabVersions.length - 1))
    readonly property var current: tab === 0 ? Updates.latest : (tabVersions.length > 0 ? tabVersions[pick] : null)
    readonly property var posts: current ? (current.posts || []) : []

    property var openVersion: null
    property var openPost: null

    function dateText(d) {
        const t = new Date(String(d || "") + "T12:00:00");
        return isNaN(t.getTime()) ? "" : t.toLocaleDateString(Qt.locale("en_GB"), "d MMM yyyy");
    }
    function meta(v) { return v ? "v" + v.version + (v.date ? "  ·  " + dateText(v.date) : "") : ""; }
    function resourcesText(r) {
        if (!r) return "";
        const bits = [];
        if (r.ram) bits.push(r.ram + " RAM");
        if (r.cpu) bits.push(r.cpu + " CPU");
        let line = bits.length > 0 ? bits.join(" · ") + " while open" : "";
        if (r.disk) line += (line ? " · " : "") + r.disk + " on disk";
        return line + (line ? " · nothing when closed" : "");
    }

    function openIt(v, p) {
        Sounds.playSfx("reusables/clickbutton/click.wav");
        swap.target = true; swap.version = v; swap.post = p; swap.dir = 1; swap.restart();
    }
    function back() {
        Sounds.playSfx("reusables/clickbutton/click.wav");
        swap.target = false; swap.dir = -1; swap.restart();
    }
    onTabChanged: if (openPost) { openPost = null; openVersion = null; }

    // ---------- the list ----------
    Item {
        id: listLayer
        width: parent.width; height: parent.height
        visible: page.openPost === null || swap.running

        Column {
            id: head
            x: (parent.width - width) / 2; y: page.s(10)
            width: Math.min(parent.width - page.s(24), page.s(640))
            spacing: page.s(10)

            // the two tabs, a pill sliding under the chosen one (as the Control tab's sub-pages)
            Item {
                width: parent.width; height: page.s(32)
                Rectangle {
                    anchors.fill: tabRow; anchors.margins: -page.s(3)
                    radius: height / 2; color: page.cardColor
                }
                Rectangle {
                    x: tabRow.x + page.pillX; width: page.pillW
                    y: tabRow.y; height: tabRow.height; radius: height / 2
                    color: ThemeBackend.mauve
                    Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                    Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                }
                // Latest: its version on the left and its date on the right, the tabs in the middle
                Text {
                    visible: page.tab === 0 && page.current !== null
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: page.current ? "v" + page.current.version : ""
                    font.family: ThemeBackend.fontFamily; font.pixelSize: page.s(12); font.bold: true
                    color: ThemeBackend.subtext0
                }
                Text {
                    visible: page.tab === 0 && page.current !== null && page.current.date !== undefined
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: page.current ? page.dateText(page.current.date) : ""
                    font.family: ThemeBackend.fontFamily; font.pixelSize: page.s(12); font.bold: true
                    color: ThemeBackend.subtext0
                }
                Row {
                    id: tabRow
                    x: (parent.width - width) / 2; anchors.verticalCenter: parent.verticalCenter
                    height: page.s(26)
                    Repeater {
                        id: tabRep
                        model: ["Latest", "All"]
                        Item {
                            id: tabItem
                            required property var modelData
                            required property int index
                            readonly property bool chosen: index === page.tab
                            width: tabLabel.implicitWidth + page.s(24); height: parent.height
                            // the pill follows the chosen tab
                            function place() { if (chosen) { page.pillX = x; page.pillW = width; } }
                            onChosenChanged: place()
                            onXChanged: place()
                            onWidthChanged: place()
                            Component.onCompleted: place()
                            Text {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: parent.modelData
                                font.family: ThemeBackend.fontFamily; font.pixelSize: page.s(12); font.bold: true
                                color: parent.index === page.tab ? ThemeBackend.crust : ThemeBackend.text
                                Behavior on color { ColorAnimation { duration: 200 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: if (page.tab !== parent.index) { Sounds.playSfx("reusables/switch/sfx.wav"); page.tab = parent.index; }
                            }
                        }
                    }
                }
            }

            // All: the row of versions (Update beside it when a newer version exists)
            Item {
                visible: page.tab === 1 && page.tabVersions.length > 0
                width: parent.width; height: page.s(28)
                ListView {
                    id: verRow
                    anchors.left: parent.left; anchors.right: updateBtn.visible ? updateBtn.left : parent.right
                    anchors.rightMargin: updateBtn.visible ? page.s(8) : 0
                    height: parent.height
                    orientation: ListView.Horizontal
                    spacing: page.s(6)
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    interactive: contentWidth > width
                    model: page.tabVersions
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool chosen: index === page.pick
                        width: verLabel.implicitWidth + page.s(22); height: page.s(28); radius: height / 2
                        color: chosen ? ThemeBackend.mauve : (verMa.containsMouse ? ThemeBackend.surface1 : page.cardColor)
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Text {
                            id: verLabel
                            anchors.centerIn: parent
                            text: "v" + parent.modelData.version
                            font.family: ThemeBackend.fontFamily; font.pixelSize: page.s(12); font.bold: true
                            color: parent.chosen ? ThemeBackend.crust : ThemeBackend.text
                        }
                        MouseArea {
                            id: verMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (!parent.chosen) {
                                Sounds.playSfx("reusables/switch/sfx.wav");
                                page.pickAll = parent.index;
                            }
                        }
                    }
                }
                ClickButton {
                    id: updateBtn
                    visible: Updates.pending.length > 0
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    height: page.s(28)
                    cornerRadius: height / 2
                    buttonIcon: "󰚰"; buttonText: "Update"
                    textFontSize: page.s(12); iconFontSize: page.s(13)
                    accentColor: ThemeBackend.mauve; textColor: ThemeBackend.crust
                    onClicked: Updates.update()
                }
            }
        }

        // the cards
        ListView {
            id: cards
            x: head.x; width: head.width
            y: head.y + head.height + page.s(10)
            height: parent.height - y - page.s(10)
            visible: page.posts.length > 0
            spacing: page.s(6)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            model: page.posts
            delegate: Item {
                id: card
                required property var modelData
                readonly property var info: Updates.tag(modelData.tag)
                width: cards.width; height: page.s(54)
                Rectangle {
                    anchors.fill: parent
                    radius: page.cardRadius
                    color: cardMa.containsMouse ? ThemeBackend.surface1 : page.cardColor
                    scale: cardMa.pressed ? 0.98 : 1
                    Behavior on color { ColorAnimation { duration: 160 } }
                    Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
                    Text {
                        x: page.s(14); y: page.s(9)
                        width: parent.width - x - page.s(14)
                        text: card.modelData.title || ""
                        elide: Text.ElideRight
                        font.family: ThemeBackend.fontFamily; font.pixelSize: page.s(13); font.bold: true
                        color: ThemeBackend.text
                    }
                    // the tag, small, bottom left
                    Rectangle {
                        x: page.s(14); y: parent.height - height - page.s(8)
                        width: tagText.implicitWidth + page.s(12); height: page.s(16); radius: height / 2
                        color: card.info.color
                        Text {
                            id: tagText
                            anchors.centerIn: parent
                            text: card.info.name
                            font.family: ThemeBackend.fontFamily; font.pixelSize: page.s(10); font.bold: true
                            color: ThemeBackend.crust
                        }
                    }
                }
                MouseArea {
                    id: cardMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: page.openIt(page.current, card.modelData)
                }
            }
        }
    }

    // ---------- one post ----------
    Item {
        id: postLayer
        width: parent.width; height: parent.height
        visible: page.openPost !== null
        readonly property var p: page.openPost
        readonly property var v: page.openVersion
        readonly property var info: Updates.tag(p ? p.tag : "")
        readonly property bool installed: !!v && v.installed

        Flickable {
            anchors.fill: parent
            contentHeight: body.height + page.s(24)
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            interactive: contentHeight > height
            Column {
                id: body
                x: (parent.width - width) / 2; y: page.s(10)
                width: Math.min(postLayer.width - page.s(24), page.s(640))
                spacing: page.s(12)

                Item {
                    width: parent.width; height: page.s(30)
                    Rectangle {
                        width: backRow.implicitWidth + page.s(20); height: parent.height; radius: height / 2
                        color: backMa.containsMouse ? ThemeBackend.surface1 : page.cardColor
                        Behavior on color { ColorAnimation { duration: 160 } }
                        Row {
                            id: backRow
                            anchors.centerIn: parent
                            spacing: page.s(6)
                            Text { text: "󰁍"; font.family: ThemeBackend.iconFont; font.pixelSize: page.s(13); color: ThemeBackend.text; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: "Back"; font.family: ThemeBackend.fontFamily; font.pixelSize: page.s(12); font.bold: true; color: ThemeBackend.text; anchors.verticalCenter: parent.verticalCenter }
                        }
                        MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.back() }
                    }
                    Rectangle {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                        width: postTag.implicitWidth + page.s(18); height: page.s(24); radius: height / 2
                        color: postLayer.info.color
                        Text {
                            id: postTag
                            anchors.centerIn: parent
                            text: postLayer.info.name
                            font.family: ThemeBackend.fontFamily; font.pixelSize: page.s(12); font.bold: true
                            color: ThemeBackend.crust
                        }
                    }
                }

                Text {
                    width: parent.width
                    text: postLayer.p ? postLayer.p.title : ""
                    wrapMode: Text.WordWrap
                    font.family: ThemeBackend.fontFamily; font.pixelSize: page.s(22); font.bold: true
                    color: ThemeBackend.text
                }
                Text {
                    text: page.meta(postLayer.v)
                    font.family: ThemeBackend.fontFamily; font.pixelSize: page.s(11); font.bold: true
                    color: ThemeBackend.subtext0
                }

                ClippingRectangle {
                    visible: postImage.source.toString() !== "" && postImage.status !== Image.Error
                    width: parent.width; height: width * 9 / 16
                    radius: page.cardRadius
                    color: page.cardColor
                    Image {
                        id: postImage
                        anchors.fill: parent
                        source: Updates.imageUrl(postLayer.v, postLayer.p)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Math.ceil(width)
                        opacity: status === Image.Ready ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 220 } }
                    }
                }

                // what it costs (Feature and Improved)
                Rectangle {
                    readonly property string line: postLayer.p && (postLayer.p.tag === "feature" || postLayer.p.tag === "improved")
                                                   ? page.resourcesText(postLayer.p.resources) : ""
                    visible: line !== ""
                    width: parent.width; height: resText.implicitHeight + page.s(16)
                    radius: page.cardRadius
                    color: page.cardColor
                    Row {
                        id: resRow
                        x: page.s(12); anchors.verticalCenter: parent.verticalCenter
                        spacing: page.s(8)
                        Text { text: "󰍛"; font.family: ThemeBackend.iconFont; font.pixelSize: page.s(13); color: ThemeBackend.subtext0; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            id: resText
                            width: body.width - page.s(24) - page.s(21)
                            text: parent.parent.line
                            wrapMode: Text.WordWrap
                            font.family: ThemeBackend.fontFamily; font.pixelSize: page.s(11); font.bold: true
                            color: ThemeBackend.subtext0
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: text !== ""
                    text: postLayer.p ? (postLayer.p.details || "") : ""
                    wrapMode: Text.WordWrap
                    lineHeight: 1.3
                    font.family: ThemeBackend.fontFamily; font.pixelSize: page.s(13)
                    color: ThemeBackend.text
                }

                // a Fix bug's report
                Repeater {
                    model: postLayer.p && postLayer.p.tag === "fixbug" && postLayer.p.report
                           ? [["Where", postLayer.p.report.where], ["What went wrong", postLayer.p.report.wrong], ["What changed", postLayer.p.report.changed]].filter(r => !!r[1])
                           : []
                    Rectangle {
                        required property var modelData
                        width: body.width; height: repCol.implicitHeight + page.s(20)
                        radius: page.cardRadius
                        color: page.cardColor
                        Column {
                            id: repCol
                            x: page.s(12); y: page.s(10)
                            width: parent.width - page.s(24)
                            spacing: page.s(4)
                            Text { text: parent.parent.modelData[0]; font.family: ThemeBackend.fontFamily; font.pixelSize: page.s(11); font.bold: true; color: Updates.tag("fixbug").color }
                            Text { width: parent.width; text: parent.parent.modelData[1]; wrapMode: Text.WordWrap; lineHeight: 1.25; font.family: ThemeBackend.fontFamily; font.pixelSize: page.s(12); color: ThemeBackend.text }
                        }
                    }
                }

                // Update, when this version is not here yet
                ClickButton {
                    visible: !postLayer.installed
                    height: page.s(34)
                    cornerRadius: height / 2
                    horizontalPadding: page.s(18)
                    buttonIcon: "󰚰"; buttonText: "Update to get this"
                    textFontSize: page.s(12); iconFontSize: page.s(13)
                    accentColor: ThemeBackend.mauve; textColor: ThemeBackend.crust
                    onClicked: Updates.update()
                }
            }
        }
    }

    // the Control tab's page change: out to one side, in from the other
    SequentialAnimation {
        id: swap
        property bool target: false
        property var version: null
        property var post: null
        property int dir: 1
        ParallelAnimation {
            NumberAnimation { target: page.openPost ? postLayer : listLayer; property: "opacity"; to: 0; duration: 100; easing.type: Easing.InQuad }
            NumberAnimation { target: page.openPost ? postLayer : listLayer; property: "x"; to: -24 * swap.dir; duration: 100; easing.type: Easing.InQuad }
        }
        ScriptAction {
            script: {
                page.openVersion = swap.target ? swap.version : null;
                page.openPost = swap.target ? swap.post : null;
                const into = swap.target ? postLayer : listLayer;
                into.opacity = 0; into.x = 24 * swap.dir;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: swap.target ? postLayer : listLayer; property: "opacity"; to: 1; duration: 220 }
            NumberAnimation { target: swap.target ? postLayer : listLayer; property: "x"; to: 0; duration: 300; easing.type: Easing.OutCubic }
        }
    }
}
