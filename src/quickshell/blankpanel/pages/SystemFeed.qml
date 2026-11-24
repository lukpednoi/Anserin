import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../../"

// Live data for the System pages: SysData sampled every second while `active` (it drops back to its normal
// interval, or stops, when no page needs it), a short history for the graphs, and the battery from UPower.
// When `detailed` is true (Minimal / Smart styles), a lightweight 2s helper adds per-core CPU, GPU, Disk,
// Network throughput, Power profile, Ping, and Top-5 Processes — stopping completely when hidden.
Item {
    id: feed
    property bool active: false
    property bool detailed: false
    property bool subscribed: false

    function sync() {
        if (active === subscribed) return;
        subscribed = active;
        if (active) { SysData.subscribeFast(); uptimeFile.reload(); }
        else SysData.unsubscribeFast();
    }
    onActiveChanged: { sync(); syncDetailed(); }
    onDetailedChanged: syncDetailed()
    Component.onCompleted: { sync(); syncDetailed(); }
    Component.onDestruction: {
        if (subscribed) SysData.unsubscribeFast();
        detailTimer.stop();
        detailProc.running = false;
    }

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
    readonly property string ramSub: ramTotalGb > 0 ? (ramUsedGb.toFixed(1) + " / " + ramTotalGb.toFixed(1) + " GB") : "—"
    readonly property string ramFreeText: ramTotalGb > 0 ? (Math.max(0, ramTotalGb - ramUsedGb).toFixed(1) + " GB free") : "—"
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

    // ---------- detailed hardware telemetry (ONLY active for Minimal & Smart styles while shown) ----------
    property int detailTick: 0
    property string cpuSub: "—"
    property string cpuSubShort: "—"
    property real cpuGhz: 0.0
    property var pCores: []
    property var eCores: []

    property var gpus: []
    property int gpuIdx: 0
    readonly property int gpuCount: gpus.length
    readonly property var activeGpu: (gpus.length > 0) ? gpus[gpuIdx % gpus.length] : null
    readonly property string gpuName: activeGpu ? activeGpu.name : "GPU"
    readonly property int gpuPct: activeGpu ? (activeGpu.pct || 0) : 0
    readonly property int gpuTemp: activeGpu ? (activeGpu.temp || 0) : 0
    readonly property string vramText: activeGpu ? (activeGpu.vramText || "Shared") : "—"
    readonly property real vramFrac: activeGpu ? (activeGpu.vramFrac || 0) : 0

    property var disks: []
    property int diskIdx: 0
    readonly property int diskCount: disks.length
    readonly property var activeDisk: (disks.length > 0) ? disks[diskIdx % disks.length] : null
    readonly property string diskMount: activeDisk ? activeDisk.mount : "/"
    readonly property int activeDiskPct: activeDisk ? (activeDisk.pct || 0) : disk
    readonly property string diskSub: activeDisk ? activeDisk.sub : (diskTotalGb > 0 ? (Math.round(diskUsedGb) + "/" + Math.round(diskTotalGb) + " GB") : "—")
    readonly property int diskTemp: activeDisk ? (activeDisk.temp || 0) : 0

    property string netDownText: "0 B/s"
    property string netUpText: "0 B/s"
    property string netPeakText: "0B"
    property var netHist: []

    property string powerProfile: "Balanced"
    property bool hasPowerProfiles: false
    property string powerWatts: watts > 0.05 ? watts.toFixed(1) : "—"
    property string powerStatus: batState

    property int pingMs: -1
    property int procSort: 1  // 0 = CPU, 1 = Memory
    property var topCpuProcs: []
    property var topMemProcs: []

    function cycleGpu() { if (gpus.length > 1) gpuIdx = (gpuIdx + 1) % gpus.length; }
    function cycleDisk() { if (disks.length > 1) diskIdx = (diskIdx + 1) % disks.length; }
    function cyclePower() {
        if (!hasPowerProfiles) return;
        const order = ["Power Saver", "Balanced", "Performance"];
        const cli   = ["power-saver", "balanced", "performance"];
        const idx = (order.indexOf(powerProfile) + 1) % order.length;
        powerProfile = order[idx];
        Quickshell.execDetached(["powerprofilesctl", "set", cli[idx]]);
    }

    function syncDetailed() {
        if (active && detailed) {
            pollDetail(true);
            detailTimer.restart();
        } else {
            detailTimer.stop();
            detailProc.running = false;
        }
    }

    function pollDetail(wantPing) {
        if (!active || !detailed || detailProc.running) return;
        const script = Caching.anserinDir + "/scripts/sys_telemetry.py";
        detailProc.command = wantPing ? ["python3", script, "--ping"] : ["python3", script];
        detailProc.running = true;
    }

    Timer {
        id: detailTimer
        interval: 2000
        repeat: true
        running: false
        onTriggered: feed.pollDetail((feed.detailTick % 4) === 0)
    }

    Process {
        id: detailProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const raw = (this.text || "").trim();
                if (!raw) return;
                try {
                    const d = JSON.parse(raw);
                    if (d.cpu) {
                        feed.cpuSub = d.cpu.sub || "—";
                        feed.cpuSubShort = d.cpu.subShort || "—";
                        feed.cpuGhz = Number(d.cpu.ghz || 0);
                        feed.pCores = d.cpu.pCores || [];
                        feed.eCores = d.cpu.eCores || [];
                    }
                    if (Array.isArray(d.gpus)) {
                        feed.gpus = d.gpus;
                        if (feed.gpuIdx >= d.gpus.length) feed.gpuIdx = 0;
                    }
                    if (Array.isArray(d.disks)) {
                        feed.disks = d.disks;
                        if (feed.diskIdx >= d.disks.length) feed.diskIdx = 0;
                    }
                    if (d.net) {
                        feed.netDownText = d.net.downText || "0 B/s";
                        feed.netUpText = d.net.upText || "0 B/s";
                        feed.netPeakText = d.net.peakText || "0B";
                        feed.netHist = d.net.hist || [];
                    }
                    if (d.power) {
                        feed.powerProfile = d.power.profile || "Balanced";
                        feed.hasPowerProfiles = Boolean(d.power.hasProfiles);
                        feed.powerWatts = (d.power.watts && d.power.watts !== "—") ? String(d.power.watts) : (feed.watts > 0.05 ? feed.watts.toFixed(1) : "—");
                        feed.powerStatus = d.power.status || feed.batState;
                    }
                    if (d.pingMs !== undefined) feed.pingMs = Number(d.pingMs);
                    if (Array.isArray(d.topCpuProcs)) feed.topCpuProcs = d.topCpuProcs;
                    if (Array.isArray(d.topMemProcs)) feed.topMemProcs = d.topMemProcs;
                    feed.detailTick++;
                } catch (e) {}
            }
        }
    }
}
