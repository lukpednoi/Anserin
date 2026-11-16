import QtQuick
import QtQuick.Layouts
import "../"
import "../reusables"

// A month view in the look of the Calendar popup: today is highlighted, the arrows change the month.
Rectangle {
    id: root

    property real cornerRadius: 20
    property color accent: ThemeBackend.mauve
    property int monthOffset: 0
    property int targetOffset: 0
    property string monthName: ""
    property real contentOpacity: 1
    property real contentOffset: 0
    property int direction: 1
    readonly property bool hovered: pointer.hovered

    HoverHandler { id: pointer }

    function setMonth(next) {
        if (next === targetOffset) return;
        if (monthChange.running) {
            monthChange.stop();
            monthOffset = targetOffset;
            contentOpacity = 1;
            contentOffset = 0;
        }
        direction = next > targetOffset ? 1 : -1;
        targetOffset = next;
        monthChange.start();
    }

    SequentialAnimation {
        id: monthChange
        ParallelAnimation {
            NumberAnimation { target: root; property: "contentOpacity"; to: 0; duration: 200; easing.type: Easing.InSine }
            NumberAnimation { target: root; property: "contentOffset"; to: -root.s(20) * root.direction; duration: 200; easing.type: Easing.InSine }
        }
        ScriptAction {
            script: {
                root.monthOffset = root.targetOffset;
                root.contentOffset = root.s(20) * root.direction;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: root; property: "contentOpacity"; to: 1; duration: 350; easing.type: Easing.OutQuint }
            NumberAnimation { target: root; property: "contentOffset"; to: 0; duration: 350; easing.type: Easing.OutQuint }
        }
    }

    function s(v) { return Scaler.s(v); }

    radius: cornerRadius
    color: (tileGlass1.active ? "transparent" : Qt.darker(ThemeBackend.surface0, 1.04))
    GlassFill { id: tileGlass1; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
    clip: true

    function update() {
        const first = new Date();
        first.setDate(1);
        first.setMonth(first.getMonth() + monthOffset);
        const month = first.getMonth();
        const year = first.getFullYear();
        const now = new Date();
        const isThisMonth = now.getMonth() === month && now.getFullYear() === year;
        monthName = first.toLocaleDateString(Qt.locale(I18n.currentLang), "MMMM yyyy");

        const lead = (new Date(year, month, 1).getDay() + 6) % 7;
        const days = new Date(year, month + 1, 0).getDate();
        const previousDays = new Date(year, month, 0).getDate();
        days_.clear();
        for (let i = lead - 1; i >= 0; i--) days_.append({ dayNum: String(previousDays - i), current: false, today: false });
        for (let i = 1; i <= days; i++) days_.append({ dayNum: String(i), current: true, today: isThisMonth && i === now.getDate() });
        for (let i = 1; days_.count < 42; i++) days_.append({ dayNum: String(i), current: false, today: false });
    }

    onMonthOffsetChanged: update()
    onVisibleChanged: if (visible) update()
    Component.onCompleted: update()

    ListModel { id: days_ }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: root.s(10)
        spacing: root.s(2)

        RowLayout {
            Layout.fillWidth: true
            IconButton {
                Layout.preferredWidth: root.s(24)
                Layout.preferredHeight: root.s(24)
                size: root.s(24)
                cornerRadius: root.s(8)
                buttonIcon: I18n.rtl ? "" : ""
                iconFontSize: root.s(12)
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                onClicked: root.setMonth(root.targetOffset - 1)
            }
            Text {
                Layout.fillWidth: true
                text: root.monthName.toUpperCase()
                font.family: ThemeBackend.fontFamily
                font.weight: Font.Black
                font.pixelSize: root.s(13)
                color: ThemeBackend.text
                horizontalAlignment: Text.AlignHCenter
                opacity: root.contentOpacity
                transform: Translate { x: root.contentOffset }
            }
            IconButton {
                Layout.preferredWidth: root.s(24)
                Layout.preferredHeight: root.s(24)
                size: root.s(24)
                cornerRadius: root.s(8)
                buttonIcon: I18n.rtl ? "" : ""
                iconFontSize: root.s(12)
                accentColor: ThemeBackend.surface0
                textColor: ThemeBackend.text
                onClicked: root.setMonth(root.targetOffset + 1)
            }
        }

        RowLayout {
            Layout.fillWidth: true
            layoutDirection: I18n.layoutDirection
            Repeater {
                model: ["mo", "tu", "we", "th", "fr", "sa", "su"]
                Text {
                    required property string modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    text: I18n.t("calendar.days." + modelData)
                    font.family: ThemeBackend.fontFamily
                    font.weight: Font.Black
                    font.pixelSize: root.s(10.5)
                    color: ThemeBackend.overlay0
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 7
            rowSpacing: root.s(1)
            columnSpacing: root.s(3)
            layoutDirection: I18n.layoutDirection
            opacity: root.contentOpacity
            transform: Translate { x: root.contentOffset }
            Repeater {
                model: days_
                ClickButton {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 1
                    enabled: false
                    buttonText: dayNum
                    textFontSize: root.s(11)
                    cornerRadius: root.s(5)
                    horizontalPadding: 0
                    accentColor: today ? root.accent : "transparent"
                    textColor: today ? ThemeBackend.base : (current ? ThemeBackend.text : ThemeBackend.surface1)
                }
            }
        }
    }
}
