import QtQuick
import "../../"
import "../../reusables"

// A number with − and + on either side, in the board's look. Holding a button repeats.
Rectangle {
    id: n
    property real value: 0
    property real from: 0
    property real to: 100
    property real step: 1
    property string suffix: ""
    property int decimals: 0
    property color accent: ThemeBackend.mauve
    signal changed(real value)
    implicitWidth: 132
    implicitHeight: 30
    radius: height / 2
    color: (tileGlass1.active ? "transparent" : ThemeBackend.surface0)
    GlassFill { id: tileGlass1; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }

    function bump(d) {
        const v = Math.max(from, Math.min(to, Math.round((value + d * step) / step) * step));
        if (v !== value) { Sounds.playSfx("reusables/draggable/tick.wav", 0.6); changed(v); }
    }
    component Btn: Rectangle {
        id: b
        property int dir: 1
        width: n.height - 6; height: width; radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        readonly property bool can: dir > 0 ? n.value < n.to : n.value > n.from
        color: bMa.pressed ? ThemeBackend.surface2 : (bMa.containsMouse && can ? ThemeBackend.surface1 : "transparent")
        opacity: can ? 1 : 0.38
        Behavior on color { ColorAnimation { duration: 120 } }
        Text { anchors.centerIn: parent; text: b.dir > 0 ? "󰐕" : "󰍴"; font.family: ThemeBackend.iconFont; font.pixelSize: 13; color: ThemeBackend.text }
        MouseArea { id: bMa; anchors.fill: parent; hoverEnabled: true; cursorShape: b.can ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onPressed: { n.bump(b.dir); rep.interval = 380; rep.start(); } onReleased: rep.stop(); onCanceled: rep.stop() }
        Timer { id: rep; repeat: true; onTriggered: { interval = 70; n.bump(b.dir); } }
    }
    Btn { x: 3; dir: -1 }
    Text { anchors.centerIn: parent; text: Number(n.value).toFixed(n.decimals) + n.suffix
           font.family: ThemeBackend.fontFamily; font.pixelSize: 12; font.bold: true; color: ThemeBackend.text }
    Btn { x: n.width - width - 3; dir: 1 }
}
