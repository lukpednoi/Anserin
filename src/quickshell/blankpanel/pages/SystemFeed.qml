import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "../../"

// Live data for the System pages: SysData sampled every second while `active` (it drops back to its normal
// interval, or stops, when no page needs it), a short history for the graphs, and the battery from UPower.
// The numbers glide to each new sample.
Item {
    id: feed
    property bool active: false
    property bool subscribed: false
    function sync() {
        if (active === subscribed) return;
        subscribed = active;
        if (active) { SysData.subscribeFast(); uptimeFile.reload(); }
        else SysData.unsubscribeFast();
    }
    onActiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (subscribed) SysData.unsubscribeFast()

    readonly property int capacity: 40
    readonly property int interval: 1000
    property var cpuHist: []
    property var ramHist: []
    property var tempHist: []

    function push(list, v) {
        const out = list.slice(-(capacity - 1));
        out.push(v);
        return out;
    }
    Connections {
        target: SysData
        enabled: feed.active
        function onSampled() {
            feed.cpuHist = feed.push(feed.cpuHist, SysData.cpu);
            feed.ramHist = feed.push(feed.ramHist, SysData.ramPercent);
            feed.tempHist = feed.push(feed.tempHist, SysData.temp);
            feed.uptimeSec += 1;
        }
    }

    // ---------- system (glides between samples at a steady pace, so nothing stops and starts each second) ----------
    property real cpu: SysData.cpu
    property real ram: SysData.ramPercent
    property real temp: SysData.temp
    Behavior on cpu { NumberAnimation { duration: feed.interval; easing.type: Easing.Linear } }
    Behavior on ram { NumberAnimation { duration: feed.interval; easing.type: Easing.Linear } }
    Behavior on temp { NumberAnimation { duration: feed.interval; easing.type: Easing.Linear } }
    readonly property real ramUsedGb: SysData.ramGb
    readonly property real ramTotalGb: SystemInfo.totalRamGb > 0 ? SystemInfo.totalRamGb : (SysData.ramPercent > 0 ? SysData.ramGb * 100 / SysData.ramPercent : 0)
    readonly property int disk: SysData.diskPercent
    readonly property real diskUsedGb: SysData.diskGb
    readonly property real diskTotalGb: SysData.diskTotalGb

    property int uptimeSec: 0
    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        onLoaded: feed.uptimeSec = Math.round(parseFloat(text().split(" ")[0]) || 0)
    }
    readonly property string uptimeText: fmtDur(uptimeSec)

    // ---------- battery ----------
    readonly property var bat: UPower.displayDevice
    readonly property int batPct: bat && bat.ready ? Math.round(bat.percentage * 100) : 0
    readonly property bool charging: bat && bat.ready && (bat.state === UPowerDeviceState.Charging || bat.state === UPowerDeviceState.PendingCharge)
    readonly property bool full: bat && bat.ready && bat.state === UPowerDeviceState.FullyCharged
    readonly property bool plugged: charging || full
    readonly property real watts: bat && bat.ready ? Math.abs(bat.changeRate) : 0
    readonly property string batState: full ? "Fully charged" : (charging ? "Charging" : "On battery")
    readonly property string batTime: {
        if (!bat || !bat.ready) return "";
        if (full) return "Plugged in";
        if (charging) return bat.timeToFull > 0 ? fmtDur(bat.timeToFull) + " to full" : "Calculating…";
        return bat.timeToEmpty > 0 ? fmtDur(bat.timeToEmpty) + " left" : "Calculating…";
    }

    function fmtDur(sec) {
        sec = Math.max(0, Math.round(sec));
        const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
        if (d > 0) return d + "d " + h + "h";
        if (h > 0) return h + "h " + m + "m";
        return m + "m";
    }
}
