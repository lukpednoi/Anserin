import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import ".."
import "../../../"

// 10. UPDATE — Real Updates.qml + full-page post reader (clean English, zero mock leftovers)
Column {
    id: page
    property var app: null
    spacing: 11

    Component.onCompleted: Updates.check()

    readonly property string installedVer: Updates.localVersion || ""
    readonly property string latestVer: Updates.latest ? Updates.latest.version : installedVer
    readonly property bool hasUpdate: installedVer !== latestVer && latestVer !== ""
    readonly property var allVersions: (Updates.versions || []).map(v => ({ version: v.version, date: v.date || "", posts: v.posts || [] }))
    readonly property var lastRel: allVersions.length > 0 ? allVersions[0] : null
    property int pickedVerIdx: allVersions.length > 1 ? 1 : 0
    readonly property var pickedVer: (pickedVerIdx >= 0 && pickedVerIdx < allVersions.length) ? allVersions[pickedVerIdx] : lastRel

    property bool updating: false
    property bool downloadDone: false
    property real updateProg: 0.0
    property var openVersion: null
    property var openPost: null

    function startUpdate() {
        if (updating) return;
        updating = true;
        downloadDone = false;
        updateProg = 0.05;
        page.app.sfx.playQuick();
        Updates.update();
        updTimer.start();
    }
    Timer {
        id: updTimer; interval: 250; repeat: true
        onTriggered: page.updateProg = Math.min(0.9, page.updateProg + (0.9 - page.updateProg) * 0.04)
    }
    Connections {
        target: Updates
        function onLocalVersionChanged() {
            if (!page.updating || Updates.localVersion !== page.latestVer) return;
            updTimer.stop();
            page.updating = false;
            page.downloadDone = true;
            page.updateProg = 1.0;
            page.app.sfx.playLock();
            page.app.showToast("Download complete ✓");
        }
    }

    SpringVal { id: updSlide; target: 0.0; stiffness: 320; damping: 0.68; eps: 0.2 }

    readonly property var tagStyles: ({
        special:  { name: "Special",  color: "#4dabf7" },
        feature:  { name: "Feature",  color: "#ffd43b" },
        fixbug:   { name: "Fix bug",  color: "#51cf66" },
        improved: { name: "Improved", color: "#4dabf7" },
        removed:  { name: "Removed",  color: "#ff6b6b" }
    })
    function tagInfo(t) { return tagStyles[t] || tagStyles.feature; }
    function formatDate(d) {
        const dt = new Date(String(d || "") + "T12:00:00");
        return isNaN(dt.getTime()) ? String(d || "") : Qt.formatDate(dt, "d MMM yyyy");
    }
    function resourceItems(r) {
        if (!r) return [];
        const out = [];
        if (r.ram)  out.push({ icon: "󰍛", label: "RAM",    value: r.ram + " while open" });
        if (r.cpu)  out.push({ icon: "󰻠", label: "CPU",    value: r.cpu + " while open" });
        if (r.disk) out.push({ icon: "󰋊", label: "Disk",   value: r.disk + " on disk" });
        if (out.length > 0) out.push({ icon: "󰒲", label: "Closed", value: "Nothing when closed" });
        return out;
    }
    function detailParagraphs(p) {
        if (!p || !p.details) return [];
        return String(p.details).split(/\n\s*\n/).map(s => s.replace(/\s*\n\s*/g, " ").trim()).filter(s => s !== "");
    }
    function postImages(p) {
        if (!p || !page.openVersion) return [];
        const v = (Updates.versions || []).find(x => x.version === page.openVersion.version) || page.openVersion;
        return Updates.postImages(v, p);
    }
    function hasAnyImage(p) {
        return !!(p && ((p.images && p.images.length > 0) || p.image));
    }
    function openPostDetail(v, p) {
        openVersion = v;
        openPost = p;
        updSlide.snapAndGo(26, 0);
        page.app.scrollToTop();
        page.app.sfx.playClick();
    }
    function closePostDetail() {
        openPost = null;
        openVersion = null;
        updSlide.snapAndGo(-22, 0);
        page.app.scrollToTop();
        page.app.sfx.playClick();
    }

    component SCard: SmartCard {
        cornerRadius: page.app.cornerRadius; darkMode: page.app.darkMode; liquidGlass: page.app.liquidGlass
        surface: page.app.cCard; accent: page.app.cAccent; textColor: page.app.cText; subColor: page.app.cSub
        uiFont: page.app.uiFont; iconFont: page.app.iconFont
    }

    // ==================== LIST VIEW ====================
    Column {
        visible: page.openPost === null
        width: parent.width; spacing: 11
        transform: Translate { x: updSlide.value }

        SCard {
            title: "Anserin Update"; icon: "󰚰"
            statusText: page.hasUpdate ? ("v" + page.installedVer + " → v" + page.latestVer) : ("v" + page.installedVer + " LATEST")

            Rectangle {
                width: parent.width
                height: page.updating ? 86 : (page.downloadDone ? 74 : 64)
                radius: 14; color: page.app.cTile
                border.width: 1
                border.color: page.downloadDone
                    ? Qt.rgba(0.29, 0.87, 0.50, 0.55)
                    : (page.hasUpdate ? Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.42) : Qt.rgba(1, 1, 1, 0.07))

                Item {
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.leftMargin: 13; anchors.rightMargin: 12; anchors.topMargin: 12; height: 48

                    Row {
                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        Rectangle {
                            visible: page.downloadDone && !page.updating
                            width: 32; height: 32; radius: 16; anchors.verticalCenter: parent.verticalCenter
                            color: Qt.rgba(0.29, 0.87, 0.50, 0.22)
                            border.width: 1.5; border.color: "#4ade80"
                            Text { anchors.centerIn: parent; text: "✓"; font.family: page.app.uiFont; font.pixelSize: 16; font.bold: true; color: "#4ade80" }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Text {
                                text: page.downloadDone && !page.updating
                                    ? "Download complete"
                                    : (page.hasUpdate ? ("Update available · v" + page.latestVer) : ("Up to date · Anserin v" + page.installedVer))
                                font.family: page.app.uiFont; font.pixelSize: 13; font.weight: Font.DemiBold
                                color: (page.downloadDone && !page.updating) ? "#4ade80" : page.app.cText
                            }
                            Text {
                                text: page.downloadDone && !page.updating
                                    ? ("Anserin v" + page.installedVer + " is ready")
                                    : ("Installed: v" + page.installedVer + (page.hasUpdate ? (" · Latest: v" + page.latestVer) : " · Ready"))
                                font.family: page.app.uiFont; font.pixelSize: 10; color: page.app.cSub
                            }
                        }
                    }

                    Row {
                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: 6
                        Rectangle {
                            visible: !page.hasUpdate && !page.updating
                            height: 30; width: 64; radius: 15; color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.16)
                            Text { anchors.centerIn: parent; text: Updates.checking ? "…" : "Check"; font.family: page.app.uiFont; font.pixelSize: 10; font.bold: true; color: page.app.cAccent }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Updates.check(); page.app.sfx.playClick(); } }
                        }
                        Rectangle {
                            visible: page.hasUpdate || page.updating
                            height: 32; width: 84; radius: 16
                            opacity: page.updating ? 0.65 : 1.0
                            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0.0; color: page.app.cAccent } GradientStop { position: 1.0; color: page.app.cAccent2 } }
                            Text { anchors.centerIn: parent; text: page.updating ? "Updating…" : "Update"; font.family: page.app.uiFont; font.pixelSize: 11; font.bold: true; color: page.app.cOnAccent }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; enabled: !page.updating; onClicked: page.startUpdate() }
                        }
                    }
                }

                Rectangle {
                    visible: page.updating
                    anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
                    anchors.leftMargin: 13; anchors.rightMargin: 13; anchors.bottomMargin: 12
                    height: 6; radius: 3; color: Qt.rgba(1, 1, 1, 0.10)
                    Rectangle {
                        width: parent.width * page.updateProg; height: parent.height; radius: 3
                        gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0.0; color: page.app.cAccent } GradientStop { position: 1.0; color: page.app.cAccent2 } }
                    }
                }
            }
        }

        // Last Release card
        SCard {
            visible: page.lastRel !== null
            title: "Last release"; icon: "󰓎"
            statusText: page.lastRel ? ("v" + page.lastRel.version + " · " + page.formatDate(page.lastRel.date)) : ""
            Repeater {
                model: page.lastRel ? (page.lastRel.posts || []) : []
                Rectangle {
                    id: lrRow; required property var modelData
                    readonly property var tInfo: page.tagInfo(modelData.tag)
                    width: parent.width; height: lrCol.implicitHeight + 20; radius: 13
                    color: lrMa.containsMouse ? page.app.cTileHov : page.app.cTile
                    border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, lrMa.containsMouse ? 0.45 : 0.22)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Column {
                        id: lrCol; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10; spacing: 5
                        Row {
                            spacing: 7
                            Rectangle { height: 18; width: lrTag.implicitWidth + 12; radius: 9; color: lrRow.tInfo.color
                                Text { id: lrTag; anchors.centerIn: parent; text: lrRow.tInfo.name; font.family: page.app.uiFont; font.pixelSize: 9; font.bold: true; color: "#0b0e14" } }
                            Text { visible: page.hasAnyImage(lrRow.modelData); text: "󰋩"; font.family: page.app.iconFont; font.pixelSize: 11; color: page.app.cSub; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Text { width: parent.width; wrapMode: Text.WordWrap; text: lrRow.modelData.title || ""; font.family: page.app.uiFont; font.pixelSize: 12; font.weight: Font.DemiBold; color: page.app.cText }
                        Text { visible: !!(lrRow.modelData.resources && lrRow.modelData.resources.ram); text: lrRow.modelData.resources ? ("RAM " + (lrRow.modelData.resources.ram || "") + " · Disk " + (lrRow.modelData.resources.disk || "")) : ""; font.family: page.app.uiFont; font.pixelSize: 10; color: page.app.cSub }
                    }
                    MouseArea { id: lrMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.openPostDetail(page.lastRel, lrRow.modelData) }
                }
            }
        }

        // Release History card
        SCard {
            visible: page.allVersions.length > 0
            title: "Release history"; icon: "󰋚"
            statusText: page.pickedVer ? ("v" + page.pickedVer.version + " · " + page.formatDate(page.pickedVer.date)) : ""

            Flickable {
                width: parent.width; height: 32; contentWidth: verRow.implicitWidth; clip: true
                flickableDirection: Flickable.HorizontalFlick; boundsBehavior: Flickable.StopAtBounds
                Row {
                    id: verRow; spacing: 6
                    Repeater {
                        model: page.allVersions
                        Rectangle {
                            id: vChip; required property var modelData; required property int index
                            readonly property bool on: page.pickedVerIdx === index
                            height: 28; width: vTxt.implicitWidth + 20; radius: 14
                            color: on ? page.app.cAccent : page.app.cTile
                            border.width: on ? 0 : 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.20)
                            Text { id: vTxt; anchors.centerIn: parent; text: "v" + vChip.modelData.version; font.family: page.app.uiFont; font.pixelSize: 10; font.bold: vChip.on; color: vChip.on ? page.app.cOnAccent : page.app.cText }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.pickedVerIdx = vChip.index; page.app.sfx.playSwitch(); } }
                        }
                    }
                }
            }

            Repeater {
                model: page.pickedVer ? (page.pickedVer.posts || []) : []
                Rectangle {
                    id: hRow; required property var modelData
                    readonly property var tInfo: page.tagInfo(modelData.tag)
                    width: parent.width; height: hCol.implicitHeight + 20; radius: 13
                    color: hMa.containsMouse ? page.app.cTileHov : page.app.cTile
                    border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, hMa.containsMouse ? 0.42 : 0.16)
                    Behavior on color { ColorAnimation { duration: 140 } }
                    Column {
                        id: hCol; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10; spacing: 5
                        Row {
                            spacing: 7
                            Rectangle { height: 18; width: hTag.implicitWidth + 12; radius: 9; color: hRow.tInfo.color
                                Text { id: hTag; anchors.centerIn: parent; text: hRow.tInfo.name; font.family: page.app.uiFont; font.pixelSize: 9; font.bold: true; color: "#0b0e14" } }
                            Text { visible: page.hasAnyImage(hRow.modelData); text: "󰋩"; font.family: page.app.iconFont; font.pixelSize: 11; color: page.app.cSub; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Text { width: parent.width; wrapMode: Text.WordWrap; text: hRow.modelData.title || ""; font.family: page.app.uiFont; font.pixelSize: 12; font.weight: Font.Medium; color: page.app.cText }
                    }
                    MouseArea { id: hMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.openPostDetail(page.pickedVer, hRow.modelData) }
                }
            }
        }
    }

    // ==================== FULL POST DETAIL VIEW ====================
    Column {
        id: postDetailView
        visible: page.openPost !== null
        width: parent.width; spacing: 11
        transform: Translate { x: updSlide.value }

        readonly property var p: page.openPost
        readonly property var v: page.openVersion
        readonly property var tInfo: page.tagInfo(p ? p.tag : "feature")
        readonly property var imgs: page.postImages(p)
        readonly property var resItems: page.resourceItems(p ? p.resources : null)
        readonly property var detailParas: page.detailParagraphs(p)
        readonly property bool needsUpdate: v !== null && v.version !== page.installedVer && v.version === page.latestVer

        Item {
            width: parent.width; height: 32
            Rectangle {
                height: 30; width: backR.implicitWidth + 22; radius: 15
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                color: backMa.containsMouse ? page.app.cTileHov : page.app.cCard
                border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, backMa.containsMouse ? 0.50 : 0.24)
                Behavior on color { ColorAnimation { duration: 140 } }
                Row { id: backR; anchors.centerIn: parent; spacing: 6
                    Text { text: "󰁍"; font.family: page.app.iconFont; font.pixelSize: 13; color: page.app.cText; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Back"; font.family: page.app.uiFont; font.pixelSize: 11; font.bold: true; color: page.app.cText; anchors.verticalCenter: parent.verticalCenter } }
                MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: page.closePostDetail() }
            }
            Rectangle {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                height: 24; width: detTagT.implicitWidth + 18; radius: 12; color: postDetailView.tInfo.color
                Text { id: detTagT; anchors.centerIn: parent; text: postDetailView.tInfo.name; font.family: page.app.uiFont; font.pixelSize: 11; font.bold: true; color: "#0b0e14" }
            }
        }

        Rectangle {
            width: parent.width; height: artCol.implicitHeight + 28
            radius: Math.max(14, page.app.cornerRadius); color: page.app.cCard
            border.width: 1; border.color: page.app.darkMode ? Qt.rgba(1, 1, 1, 0.08) : Qt.rgba(0, 0, 0, 0.07)

            Column {
                id: artCol
                anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                anchors.margins: 14; spacing: 11

                Column {
                    width: parent.width; spacing: 4
                    Text { width: parent.width; wrapMode: Text.WordWrap; text: postDetailView.p ? (postDetailView.p.title || "") : ""; font.family: page.app.uiFont; font.pixelSize: 19; font.bold: true; color: page.app.cText }
                    Text { text: postDetailView.v ? ("v" + postDetailView.v.version + "  ·  " + page.formatDate(postDetailView.v.date)) : ""; font.family: page.app.uiFont; font.pixelSize: 11; font.weight: Font.Medium; color: page.app.cSub }
                }

                // Single crisp 16:9 image OR smooth full-width horizontal carousel (e.g. Before / After)
                Item {
                    id: mediaGallery
                    visible: postDetailView.imgs.length > 0
                    width: parent.width
                    readonly property var items: postDetailView.imgs
                    readonly property bool multi: items.length > 1
                    property int activeIdx: 0
                    readonly property real gap: 10
                    readonly property real cardW: width
                    readonly property real cardH: Math.round(cardW * 9 / 16)
                    readonly property real maxOff: Math.max(0, (items.length - 1) * (cardW + gap))
                    readonly property real targetOff: multi ? (activeIdx * (cardW + gap)) : 0
                    property real dragDx: 0
                    property bool dragging: false
                    property real animOff: targetOff
                    Behavior on animOff {
                        enabled: !mediaGallery.dragging
                        NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
                    }
                    height: cardH + (multi ? 34 : 0)

                    onItemsChanged: {
                        activeIdx = 0;
                        dragDx = 0;
                        dragging = false;
                    }
                    function goTo(idx) {
                        const clamped = Math.max(0, Math.min(items.length - 1, idx));
                        if (clamped !== activeIdx) {
                            activeIdx = clamped;
                            page.app.sfx.playSwitch();
                        }
                    }

                    Item {
                        id: clipBox
                        width: parent.width
                        height: mediaGallery.cardH
                        clip: true

                        Row {
                            id: slideRow
                            x: -Math.max(-24, Math.min(mediaGallery.maxOff + 24, mediaGallery.animOff - mediaGallery.dragDx))
                            height: parent.height
                            spacing: mediaGallery.gap

                            Repeater {
                                model: mediaGallery.items
                                delegate: Item {
                                    id: slideCard
                                    required property var modelData
                                    required property int index
                                    width: mediaGallery.cardW
                                    height: mediaGallery.cardH

                                    Rectangle { id: sMask; anchors.fill: parent; radius: 13; visible: false; layer.enabled: true }
                                    Rectangle { anchors.fill: parent; radius: 13; color: page.app.cTile }
                                    Image {
                                        id: sImg
                                        anchors.fill: parent
                                        visible: false
                                        source: slideCard.modelData.url
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: false
                                        sourceSize.width: Math.max(1, Math.round(mediaGallery.cardW * 2))
                                        smooth: true
                                        mipmap: true
                                    }
                                    MultiEffect {
                                        anchors.fill: parent
                                        source: sImg
                                        maskEnabled: true
                                        maskSource: sMask
                                        visible: sImg.status === Image.Ready
                                    }
                                    Rectangle {
                                        anchors.fill: parent; radius: 13; color: "transparent"
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.12)
                                    }
                                }
                            }
                        }

                        // Smooth horizontal drag (or click) without blocking vertical page scroll
                        MouseArea {
                            anchors.fill: parent
                            enabled: mediaGallery.multi
                            cursorShape: Qt.PointingHandCursor
                            property real startX: 0
                            property real startY: 0
                            property bool lockedX: false
                            onPressed: (e) => {
                                startX = e.x;
                                startY = e.y;
                                lockedX = false;
                                mediaGallery.dragDx = 0;
                            }
                            onPositionChanged: (e) => {
                                const dx = e.x - startX;
                                const dy = e.y - startY;
                                if (!lockedX && Math.abs(dx) > 8 && Math.abs(dx) > Math.abs(dy)) {
                                    lockedX = true;
                                    mediaGallery.dragging = true;
                                }
                                if (lockedX) mediaGallery.dragDx = dx;
                            }
                            onReleased: (e) => {
                                const dx = e.x - startX;
                                if (lockedX) {
                                    mediaGallery.dragging = false;
                                    mediaGallery.dragDx = 0;
                                    if (dx < -34 && mediaGallery.activeIdx < mediaGallery.items.length - 1)
                                        mediaGallery.goTo(mediaGallery.activeIdx + 1);
                                    else if (dx > 34 && mediaGallery.activeIdx > 0)
                                        mediaGallery.goTo(mediaGallery.activeIdx - 1);
                                } else {
                                    mediaGallery.goTo((mediaGallery.activeIdx + 1) % mediaGallery.items.length);
                                }
                                lockedX = false;
                            }
                            onCanceled: {
                                mediaGallery.dragging = false;
                                mediaGallery.dragDx = 0;
                                lockedX = false;
                            }
                        }
                    }

                    // Bottom Before / After selector pills
                    Row {
                        visible: mediaGallery.multi
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        spacing: 6

                        Repeater {
                            model: mediaGallery.items
                            delegate: Rectangle {
                                id: dotPill
                                required property var modelData
                                required property int index
                                readonly property bool on: mediaGallery.activeIdx === index
                                height: 24
                                width: dotLbl.implicitWidth + 20
                                radius: 12
                                color: on ? page.app.cAccent : page.app.cTile
                                border.width: on ? 0 : 1
                                border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.24)
                                Behavior on color { ColorAnimation { duration: 180 } }
                                Text {
                                    id: dotLbl; anchors.centerIn: parent
                                    text: dotPill.modelData.label !== "" ? dotPill.modelData.label : String(dotPill.index + 1)
                                    font.family: page.app.uiFont; font.pixelSize: 10; font.bold: dotPill.on
                                    color: dotPill.on ? page.app.cOnAccent : page.app.cText
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: mediaGallery.goTo(dotPill.index)
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: postDetailView.resItems.length > 0
                    width: parent.width; height: resCol.implicitHeight + 22; radius: 13; color: page.app.cTile
                    border.width: 1; border.color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.22)
                    Column {
                        id: resCol; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 11; spacing: 8
                        Repeater {
                            model: postDetailView.resItems
                            Row {
                                required property var modelData; width: resCol.width; spacing: 9
                                Rectangle { width: 22; height: 22; radius: 7; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(page.app.cAccent.r, page.app.cAccent.g, page.app.cAccent.b, 0.16)
                                    Text { anchors.centerIn: parent; text: modelData.icon; font.family: page.app.iconFont; font.pixelSize: 12; color: page.app.cAccent } }
                                Text { width: 48; anchors.verticalCenter: parent.verticalCenter; text: modelData.label; font.family: page.app.uiFont; font.pixelSize: 11; font.bold: true; color: page.app.cSub }
                                Text { width: parent.width - 88; anchors.verticalCenter: parent.verticalCenter; wrapMode: Text.WordWrap; text: modelData.value; font.family: page.app.uiFont; font.pixelSize: 11; font.weight: Font.Medium; color: page.app.cText }
                            }
                        }
                    }
                }

                Column {
                    visible: postDetailView.detailParas.length > 0; width: parent.width; spacing: 11; topPadding: 2
                    Repeater {
                        model: postDetailView.detailParas
                        Row {
                            required property var modelData; width: parent.width; spacing: 10
                            Text { text: "✦"; topPadding: 3; font.family: page.app.uiFont; font.pixelSize: 10; color: page.app.cAccent }
                            Text { width: parent.width - 22; wrapMode: Text.WordWrap; lineHeight: 1.44; text: modelData; font.family: page.app.uiFont; font.pixelSize: 12; color: page.app.cText }
                        }
                    }
                }

                Repeater {
                    model: (postDetailView.p && postDetailView.p.tag === "fixbug" && postDetailView.p.report)
                        ? [["Where", postDetailView.p.report.where], ["What went wrong", postDetailView.p.report.wrong], ["What changed", postDetailView.p.report.changed]].filter(r => !!r[1])
                        : []
                    Rectangle {
                        required property var modelData
                        width: artCol.width; height: repC.implicitHeight + 18; radius: 12; color: page.app.cTile
                        border.width: 1; border.color: Qt.rgba(0.32, 0.81, 0.40, 0.28)
                        Column {
                            id: repC; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 10; spacing: 4
                            Text { text: parent.parent.modelData[0]; font.family: page.app.uiFont; font.pixelSize: 10; font.bold: true; color: "#51cf66" }
                            Text { width: parent.width; wrapMode: Text.WordWrap; lineHeight: 1.28; text: parent.parent.modelData[1]; font.family: page.app.uiFont; font.pixelSize: 11; color: page.app.cText }
                        }
                    }
                }

                Rectangle {
                    visible: postDetailView.needsUpdate
                    height: 36; width: ctaRow.implicitWidth + 30; radius: 18
                    gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0.0; color: page.app.cAccent } GradientStop { position: 1.0; color: page.app.cAccent2 } }
                    Row { id: ctaRow; anchors.centerIn: parent; spacing: 7
                        Text { text: "󰚰"; font.family: page.app.iconFont; font.pixelSize: 13; color: page.app.cOnAccent; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "Update to get this"; font.family: page.app.uiFont; font.pixelSize: 11; font.bold: true; color: page.app.cOnAccent; anchors.verticalCenter: parent.verticalCenter } }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { page.closePostDetail(); page.startUpdate(); } }
                }
            }
        }
    }
}
