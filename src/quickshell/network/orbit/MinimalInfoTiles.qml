import QtQuick
import "../../"
import QtQuick.Layouts
import "."

/**
 * Minimal 4-item telemetry block (icon + essential value only, no labels,
 * no subtext, no IP arrow). Supports "verticalList", "grid2x2", and compact "row4".
 */
GridLayout {
    id: grid

    required property NetworkStore store
    property color accentColor: ThemeBackend.mauve
    property string layoutMode: "verticalList" // "verticalList" | "grid2x2" | "row4"
    property real introState: 1.0

    readonly property var conn: store.activeConnection
    readonly property bool isList: layoutMode === "verticalList"
    readonly property bool isRow4: layoutMode === "row4"

    function animWin(t, a, b) {
        if (t <= a) return 0.0;
        if (t >= b) return 1.0;
        return (t - a) / (b - a);
    }
    function easeOut(t) {
        const c = Math.max(0.0, Math.min(1.0, t));
        return 1.0 - Math.pow(1.0 - c, 3);
    }
    function easeBack(t) {
        const c = Math.max(0.0, Math.min(1.0, t));
        return 1.0 + 2.7 * Math.pow(c - 1.0, 3) + 1.7 * Math.pow(c - 1.0, 2);
    }

    columns: isList ? 1 : (isRow4 ? 4 : 2)
    rowSpacing: isList ? 8 : 6
    columnSpacing: 6

    readonly property var items: {
        const c = conn;
        if (!c) return [];

        if (store.activeMode === "wifi") {
            return [
                { icon: "󰩟", text: c.ip || "No IP", accent: grid.accentColor, action: "copyIp", wShare: 1.45 },
                { icon: "󰤨", text: (c.sig || 0) + "%", accent: NetLook.signalColor(c.sig || 0), action: "", wShare: 0.68 },
                { icon: "󰖧", text: c.band || "", accent: ThemeBackend.peach, action: "", wShare: 0.82 },
                { icon: "󰓅", text: c.speed || "", accent: ThemeBackend.teal, action: "", wShare: 1.05 }
            ];
        }

        const hasBat = c.battery !== undefined && c.battery >= 0;
        const batColor = hasBat && c.battery <= 25 ? ThemeBackend.red : ThemeBackend.green;
        const profileShort = c.profile === "Hi-Fi (A2DP)" ? "A2DP" : "HFP";

        return [
            { icon: "󰥉", text: hasBat ? (c.battery + "%") : "—", accent: batColor, action: "", wShare: 0.68 },
            { icon: "󰤨", text: c.sigKnown === false ? "—" : (c.sig || 0) + "%", accent: c.sigKnown === false ? ThemeBackend.subtext0 : NetLook.signalColor(c.sig || 0), action: "", wShare: 0.68 },
            {
                icon: c.hasAudioProfile ? (c.profile === "Hi-Fi (A2DP)" ? "󰓃" : "󰋎") : (c.icon || "󰂯"),
                text: c.hasAudioProfile ? profileShort : (c.kind || "BT"),
                accent: grid.accentColor,
                action: c.hasAudioProfile ? "cycleProfile" : "",
                wShare: 0.84
            },
            { icon: "󰒋", text: c.mac || "", accent: ThemeBackend.subtext0, action: "", wShare: 1.80 }
        ];
    }

    Repeater {
        model: grid.items

        Rectangle {
            id: box
            required property var modelData
            required property int index
            readonly property bool clickable: modelData.action !== ""
            readonly property real wProg: grid.animWin(grid.introState, 0.22 + index * 0.05, 0.56 + index * 0.05)
            readonly property real eOut: grid.easeOut(wProg)
            readonly property real eBack: grid.easeBack(wProg)

            Layout.fillWidth: true
            Layout.preferredWidth: grid.isRow4 ? Math.max(54, Math.round(modelData.wShare * 100)) : -1
            Layout.preferredHeight: grid.isList ? 42 : (grid.isRow4 ? 44 : 46)
            radius: Math.min(ThemeBackend.clampedBorderRadius, 12)
            opacity: eOut
            transform: Translate {
                x: grid.isList ? (1.0 - box.eOut) * -12 : 0
                y: grid.isList ? 0 : (1.0 - box.eOut) * 10
            }
            color: clickable && ma.containsMouse
                ? Qt.tint(ThemeBackend.surface0, Qt.alpha(modelData.accent, 0.18))
                : Qt.rgba(ThemeBackend.base.r, ThemeBackend.base.g, ThemeBackend.base.b, 0.55)
            border.width: 1
            border.color: clickable && ma.containsMouse
                ? Qt.alpha(modelData.accent, 0.65)
                : Qt.alpha(ThemeBackend.surface2, 0.5)
            scale: (0.92 + 0.08 * eBack) * (clickable && ma.pressed ? 0.97 : 1.0)

            Behavior on color { ColorAnimation { duration: 140 } }
            Behavior on border.color { ColorAnimation { duration: 140 } }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: grid.isList ? 12 : (grid.isRow4 ? 8 : 7)
                anchors.rightMargin: grid.isList ? 10 : (grid.isRow4 ? 8 : 7)
                spacing: grid.isList ? 9 : 5

                Text {
                    text: modelData.icon
                    font.family: ThemeBackend.iconFont
                    font.pixelSize: grid.isList ? 14 : (grid.isRow4 ? 12 : 12)
                    color: modelData.accent
                }

                Text {
                    Layout.fillWidth: true
                    text: modelData.text
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: grid.isList
                        ? (modelData.text.length > 14 ? 10 : 12)
                        : (grid.isRow4
                            ? (modelData.text.length > 14 ? 9 : 11)
                            : (modelData.text.length > 14 ? 8 : (modelData.text.length > 10 ? 9 : 11)))
                    font.bold: true
                    color: ThemeBackend.text
                    elide: Text.ElideRight
                }
            }

            MouseArea {
                id: ma
                anchors.fill: parent
                enabled: box.clickable
                hoverEnabled: box.clickable
                cursorShape: box.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: {
                    if (!grid.conn) return;
                    if (modelData.action === "copyIp") grid.store.copyIp(grid.conn.ip);
                    else if (modelData.action === "cycleProfile") grid.store.cycleBtProfile(grid.conn.mac);
                }
            }
        }
    }
}
