import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Networking
import "../../"

// The Radar and Gargantua Network styles' state: the real Wi-Fi (NetworkManager, through Quickshell.Networking) and
// Bluetooth (BlueZ, through Quickshell.Bluetooth), in the shape the styles were drawn for (the WS 8 preview's
// PreviewNetworkData): wifiNetworks [{ id, name, sourceType, sig, band, channel, sec, speed, ip, mac, locked, saved,
// connected }] and btDevices [{ id, mac, name, kind, icon, sig, sigKnown, battery, profile, hasAudioProfile, paired,
// connected }], the mode, power, the search (Scan) state and the actions.
// It watches and scans only while `live` (the style is shown and not a still preview): Wi-Fi scanning and Bluetooth
// discovery stop, and the connection details stop being read, as soon as it is not.
// A Wi-Fi password is checked by connecting with it: submitPassword() starts that, and passwordChecked(id, ok)
// gives the answer (a wrong password's new, failed profile is forgotten again).
Item {
    id: store
    visible: false

    property bool live: false
    property string activeMode: "wifi"           // "wifi" | "bt"
    property bool enableToasts: false
    property bool manualScanOnOpen: false
    property string soundProfile: "B"

    // ---------- power ----------
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool wifiPower: Networking.wifiEnabled
    readonly property bool btPower: !!adapter && adapter.enabled
    property string powerPendingMode: ""         // "" | "wifi" | "bt"
    property bool powerPendingTarget: true
    readonly property bool currentPower: activeMode === "wifi" ? wifiPower : btPower
    readonly property bool isPowerPending: powerPendingMode === activeMode

    // ---------- the views' state ----------
    property bool searchOpen: false
    property bool scanning: false
    property string connectingId: ""
    property string passwordPromptId: ""
    property string passwordError: ""
    property string selectedId: ""
    property string focusedBtMac: ""
    property string confirmUnpairMac: ""
    property string toastText: ""
    property bool modeSwitching: false
    property string _pendingMode: ""
    property double _lastHoverMs: 0
    signal passwordChecked(string id, bool ok)

    // ---------- the lists ----------
    property var wifiNetworks: []
    property var btDevices: []
    readonly property var currentList: activeMode === "wifi" ? wifiNetworks : btDevices
    readonly property var connectedWifi: firstMatch(wifiNetworks, d => d.connected)
    readonly property var connectedBtList: btDevices.filter(d => d.connected)
    readonly property var activeConnection: {
        if (!currentPower) return null;
        if (activeMode === "wifi") return connectedWifi;
        if (connectedBtList.length === 0) return null;
        return firstMatch(connectedBtList, d => d.mac === focusedBtMac) || connectedBtList[0];
    }
    readonly property var selectedItem: firstMatch(currentList, d => d.id === selectedId) || activeConnection || (currentList.length > 0 ? currentList[0] : null)
    readonly property bool wifiConnected: wifiPower && !!connectedWifi
    readonly property bool btConnected: btPower && connectedBtList.length > 0

    function firstMatch(arr, pred) {
        for (let i = 0; i < arr.length; i++) if (pred(arr[i])) return arr[i];
        return null;
    }
    function modeConnected(modeId) { return modeId === "wifi" ? wifiConnected : btConnected; }
    function modeIcon(modeId) {
        if (modeId === "wifi") return wifiPower ? "󰤨" : "󰤭";
        return btPower ? "󰂯" : "󰂲";
    }
    function signalTier(sig) { return sig >= 75 ? "Strong" : sig >= 45 ? "Fair" : "Weak"; }

    // ---------- the devices ----------
    function listOf(model) {
        if (!model) return [];
        const v = model.values || model;
        const out = [];
        const n = v.length !== undefined ? v.length : 0;
        for (let i = 0; i < n; i++) if (v[i]) out.push(v[i]);
        return out;
    }
    // looked up again on every rebuild: the device object can be replaced while Wi-Fi is switched off and on
    property var wifiDevice: null
    function findWifiDevice() {
        const d = listOf(Networking.devices).find(x => x.type === DeviceType.Wifi) || null;
        if (d !== wifiDevice) wifiDevice = d;
    }
    readonly property string wifiIface: wifiDevice ? (wifiDevice.name || "") : ""
    function findNet(id) { return wifiDevice ? listOf(wifiDevice.networks).find(n => n.name === id) || null : null; }
    function findBt(mac) { return adapter ? listOf(adapter.devices).find(d => d.address === mac) || null : null; }

    // scanning runs only while the style is shown, in its own mode, with the radio on
    Binding { target: store.wifiDevice; property: "scannerEnabled"; value: store.activeMode === "wifi" && store.wifiPower; when: !!store.wifiDevice && store.live }
    Binding { target: store.adapter; property: "discovering"; value: store.activeMode === "bt" && store.btPower; when: !!store.adapter && store.live }

    // ---------- rebuilding the lists (debounced; every change of a network or device asks for it) ----------
    function requestRebuild() { rebuildTimer.restart(); }
    Timer { id: rebuildTimer; interval: 120; onTriggered: store.rebuild() }
    onLiveChanged: if (live) { rebuild(); readSaved(); }
    onWifiDeviceChanged: requestRebuild()
    onAdapterChanged: requestRebuild()

    // ---------- keeping the previous network on screen while another is tried ----------
    property string heldId: ""          // shown as connected while a new network is tried
    property string prevId: ""          // reconnected if the new one fails
    property string assumeId: ""        // shown as connected after the style's animation, until NM confirms
    function holdCurrent(newId) {
        const cur = nets_connectedName();
        if (cur !== "" && cur !== newId) { heldId = cur; prevId = cur; }
        else if (heldId === "") prevId = "";
        holdTimeout.restart();
    }
    function nets_connectedName() {
        const n = wifiDevice ? listOf(wifiDevice.networks).find(x => x.connected) : null;
        return n ? n.name : (heldId !== "" ? heldId : "");
    }
    // the new one failed: go back to the previous network and keep showing it until it is back
    function restorePrevious() {
        assumeId = "";
        if (prevId === "") { heldId = ""; requestRebuild(); return; }
        heldId = prevId;
        const prev = findNet(prevId);
        if (prev && !prev.connected) prev.connect();
        holdTimeout.restart();
        requestRebuild();
    }
    Timer { id: holdTimeout; interval: 25000; onTriggered: { store.heldId = ""; store.assumeId = ""; store.requestRebuild(); } }
    onHeldIdChanged: requestRebuild()
    onAssumeIdChanged: requestRebuild()

    // the connected network's details (iw link and ip addr), read on connecting and every 10 s while shown
    property var linkInfo: ({ bssid: "", freq: 0, bitrate: "", ip: "" })
    function phoneLike(name) { return /iphone|android|pixel|galaxy|hotspot|phone|redmi|oppo|vivo|xiaomi/i.test(name); }
    function bandOf(freq) { return freq >= 5925 ? "6 GHz" : freq >= 4900 ? "5 GHz" : freq > 0 ? "2.4 GHz" : ""; }
    function channelOf(freq) {
        if (freq <= 0) return "";
        const ch = freq >= 5955 ? (freq - 5950) / 5 : freq >= 5000 ? (freq - 5000) / 5 : freq === 2484 ? 14 : (freq - 2407) / 5;
        return "Ch " + Math.round(ch) + " · " + freq + " MHz";
    }

    function rebuild() {
        findWifiDevice();
        const nets = wifiDevice && wifiPower ? listOf(wifiDevice.networks) : [];
        const wifi = [];
        // While another network is being tried, NetworkManager drops the current one at once (one radio). The
        // styles keep showing it connected (`heldId`) until their animation takes it out, and show the new one
        // connected once that animation has landed (`assumeId`) while NetworkManager finishes.
        const realOther = nets.some(n => n.connected);
        for (const n of nets) {
            if (!n.name) continue;
            const open = n.security === WifiSecurityType.Open || n.security === WifiSecurityType.Owe;
            const conn = n.connected || n.name === assumeId
                || (n.name === heldId && assumeId === "" && !realOther);
            wifi.push({
                id: n.name, name: n.name,
                sourceType: phoneLike(n.name) ? "phone" : "router",
                sig: Math.round((n.signalStrength || 0) * 100),
                band: conn ? bandOf(linkInfo.freq) : "",
                channel: conn ? channelOf(linkInfo.freq) : "",
                sec: open ? "Open" : WifiSecurityType.toString(n.security),
                speed: conn ? linkInfo.bitrate : "",
                ip: conn ? linkInfo.ip : "",
                mac: conn ? linkInfo.bssid : "",
                // a network whose typed password is still being tried stays locked (NetworkManager already
                // holds its new profile meanwhile, which must not turn the prompt into a Connect button)
                locked: !open, saved: isSaved(n) && n.name !== pskId, connected: conn
            });
        }
        wifi.sort((a, b) => (b.connected - a.connected) || (b.sig - a.sig));

        const bt = [];
        const devs = adapter && btPower ? listOf(adapter.devices) : [];
        for (const d of devs) {
            const mac = d.address || "";
            if (!mac) continue;
            const paired = d.paired || d.bonded;
            const name = d.deviceName || d.name || "";
            if (!name && !paired) continue;
            const kind = btKind(d.icon || "", name);
            const profile = btProfiles[mac.toLowerCase()] || "";
            bt.push({
                id: mac, mac: mac, name: name || mac,
                kind: kind.name, icon: kind.glyph,
                sig: paired ? 72 : 55, sigKnown: false,
                battery: d.batteryAvailable ? Math.round(d.battery * 100) : -1,
                profile: profile, hasAudioProfile: profile === "Hi-Fi (A2DP)" || profile === "Headset (HFP)",
                paired: paired, connected: d.connected
            });
        }
        bt.sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name));

        if (JSON.stringify(wifi) !== JSON.stringify(wifiNetworks)) wifiNetworks = wifi;
        if (JSON.stringify(bt) !== JSON.stringify(btDevices)) btDevices = bt;
        if (focusedBtMac === "" || !connectedBtList.some(d => d.mac === focusedBtMac))
            focusedBtMac = connectedBtList.length > 0 ? connectedBtList[0].mac : "";
        settlePending();
    }

    function btKind(type, name) {
        const t = (type + " " + name).toLowerCase();
        if (/headset|headphone|buds|pods|earbud/.test(t)) return { name: "Headphones", glyph: "󰋋" };
        if (/speaker|audio|card/.test(t)) return { name: "Speaker", glyph: "󰓃" };
        if (/phone/.test(t)) return { name: "Phone", glyph: "󰄜" };
        if (/mouse/.test(t)) return { name: "Mouse", glyph: "󰍽" };
        if (/keyboard/.test(t)) return { name: "Keyboard", glyph: "󰌌" };
        if (/controller|gamepad|joystick/.test(t)) return { name: "Gamepad", glyph: "󰊴" };
        if (/watch/.test(t)) return { name: "Watch", glyph: "󰖉" };
        return { name: "Device", glyph: "󰂯" };
    }

    // change signals from every network and device
    Instantiator {
        model: store.live && store.wifiDevice ? store.wifiDevice.networks : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onSignalStrengthChanged() { store.requestRebuild(); }
            function onConnectedChanged() { store.requestRebuild(); store.readLink(); store.readSaved(); }
            function onKnownChanged() { store.requestRebuild(); store.readSaved(); }
            function onStateChanged() { store.requestRebuild(); store.onNetState(modelData); }
            function onConnectionFailed(reason) { store.onWifiFailed(modelData.name, reason); }
        }
        onObjectAdded: store.requestRebuild()
        onObjectRemoved: store.requestRebuild()
    }
    Instantiator {
        model: store.live && store.adapter ? store.adapter.devices : null
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectedChanged() { store.requestRebuild(); }
            function onPairedChanged() { store.requestRebuild(); store.onBtPaired(modelData); }
            function onBondedChanged() { store.requestRebuild(); }
            function onNameChanged() { store.requestRebuild(); }
            function onDeviceNameChanged() { store.requestRebuild(); }
            function onBatteryChanged() { store.requestRebuild(); }
        }
        onObjectAdded: store.requestRebuild()
        onObjectRemoved: store.requestRebuild()
    }
    Connections {
        target: Networking
        function onWifiEnabledChanged() {
            store.requestRebuild();
            store.settlePower();
            if (Networking.wifiEnabled) store.radioBack("wifi");
            else { store.heldId = ""; store.prevId = ""; store.assumeId = ""; }
        }
    }
    // Wi-Fi switched (back) on: ask the card for a scan at once, read the list again every half second for the
    // first 5 s while the networks come back, and tell the style so its 10 s scan cycle starts again from zero.
    // (Bluetooth lists its known devices at once, so it needs none of this.)
    signal radioReturned(string mode)
    function radioBack(mode) {
        if (!live) return;
        if (mode === "wifi" && wifiIface !== "") Quickshell.execDetached(["nmcli", "device", "wifi", "rescan", "ifname", wifiIface]);
        radioBurst.left = 10;
        radioBurst.restart();
        radioReturned(mode);
    }
    Timer {
        id: radioBurst
        property int left: 0
        interval: 500
        repeat: true
        onTriggered: {
            store.rebuild();
            if (--left <= 0) stop();
        }
    }
    Connections {
        target: store.adapter
        ignoreUnknownSignals: true
        function onEnabledChanged() { store.requestRebuild(); store.settlePower(); }
    }

    // the connected Wi-Fi's access point, band, speed and address
    function readLink() { if (live && wifiIface !== "") { linkProc.running = false; linkProc.running = true; } }
    Process {
        id: linkProc
        command: ["sh", "-c", "iw dev \"$1\" link; echo ---; ip -4 -j addr show dev \"$1\"", "sh", store.wifiIface]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.split("---");
                const info = { bssid: "", freq: 0, bitrate: "", ip: "" };
                const iw = parts[0] || "";
                const b = iw.match(/Connected to ([0-9a-f:]{17})/i); if (b) info.bssid = b[1];
                const f = iw.match(/freq:\s*([\d.]+)/); if (f) info.freq = Math.round(Number(f[1]));
                const r = iw.match(/tx bitrate:\s*([\d.]+)\s*MBit/i); if (r) info.bitrate = Math.round(Number(r[1])) + " Mbps";
                try {
                    const j = JSON.parse((parts[1] || "").trim() || "[]");
                    if (j[0] && j[0].addr_info && j[0].addr_info[0]) info.ip = j[0].addr_info[0].local || "";
                } catch (e) {}
                store.linkInfo = info;
                store.requestRebuild();
            }
        }
    }
    Timer {
        interval: 10000
        repeat: true
        running: store.live && store.wifiConnected
        onTriggered: store.readLink()
    }
    onWifiConnectedChanged: if (wifiConnected) readLink()

    // ---------- saved Wi-Fi that really worked ----------
    // A profile NetworkManager has never connected with (TIMESTAMP 0: a wrong or half-tried password left behind)
    // does not count as saved, so the password is asked for again instead of "connecting" with it.
    property var neverConnected: ({})
    function isSaved(n) { return !!n && !!n.known && neverConnected[n.name] !== true; }
    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE,TIMESTAMP", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const never = {};
                for (const line of this.text.split("\n")) {
                    // nmcli -t escapes ':' inside a name as '\:'; the last two fields never hold one
                    const m = line.match(/^(.*):([^:]*):(\d+)$/);
                    if (!m || m[2] !== "802-11-wireless") continue;
                    if (m[3] === "0") never[m[1].replace(/\\:/g, ":").replace(/\\\\/g, "\\")] = true;
                }
                if (JSON.stringify(never) !== JSON.stringify(store.neverConnected)) store.neverConnected = never;
                store.requestRebuild();
            }
        }
    }
    function readSaved() { if (live && !savedProc.running) savedProc.running = true; }

    // ---------- a wrong password is caught from the device ----------
    // With a wrong password the Wi-Fi refuses within seconds, but NetworkManager then waits about two minutes for
    // another one (device state need-auth). Need-auth seen twice in a row while a typed password is tried means
    // the password was wrong (NetworkManager also passes through it for a moment on every connect).
    property int needAuthSeen: 0
    Process {
        id: devStateProc
        command: ["nmcli", "-t", "-g", "GENERAL.STATE", "device", "show", store.wifiIface]
        stdout: StdioCollector {
            onStreamFinished: {
                if (store.pskId === "") return;
                if (this.text.indexOf("need-auth") >= 0) {
                    if (++store.needAuthSeen >= 2) { store.needAuthSeen = 0; store.pskDone(false); }
                } else store.needAuthSeen = 0;
            }
        }
    }
    Timer {
        interval: 1000
        repeat: true
        running: store.pskId !== "" && store.wifiIface !== ""
        onTriggered: if (!devStateProc.running) devStateProc.running = true
        onRunningChanged: store.needAuthSeen = 0
    }

    // Bluetooth audio profiles (pactl), read on showing and after a change
    property var btProfiles: ({})
    Process {
        id: profileProc
        command: ["bash", Quickshell.shellDir + "/network/bluetooth_panel_logic.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { store.btProfiles = JSON.parse(this.text.trim() || "{}") || {}; } catch (e) {}
                store.requestRebuild();
            }
        }
    }
    function readProfiles() { if (live && !profileProc.running) profileProc.running = true; }
    onBtConnectedChanged: readProfiles()
    Component.onCompleted: { rebuild(); if (live) { readLink(); readProfiles(); } }

    // ---------- sounds (the styles' own set) ----------
    function playHoverProfile() {
        const now = Date.now();
        if (now - _lastHoverMs < 90) return;
        _lastHoverMs = now;
        playProfileSfx("hover");
    }
    function playProfileSfx(kind) {
        const s = ({ hover: ["network/tick-2.wav", 0.22], slither: ["network/silk_drag.wav", 0.62], retract: ["network/silk_retract.wav", 0.56],
                     impact: ["start/pop_author.wav", 0.62], unlock: ["notifications/Botanica.wav", 0.52], wrong: ["network/tick-1.wav", 0.55],
                     pull: ["reusables/switch/sfx.wav", 0.38], connect: ["network/connect.wav", 0.72] })[kind];
        if (s) Sounds.playSfx(s[0], s[1]);
    }
    function showToast(msg) {
        if (!enableToasts) return;
        toastText = msg;
        toastTimer.restart();
    }
    Timer { id: toastTimer; interval: 2200; onTriggered: store.toastText = "" }

    // ---------- mode and search ----------
    function setMode(modeId) {
        if (activeMode === modeId && !modeSwitching) return;
        if (_pendingMode === modeId && modeSwitching) return;
        Sounds.playSfx("network/switch.wav", 0.55);
        _pendingMode = modeId;
        modeSwitching = true;
        modeSwitchTimer.restart();
    }
    Timer {
        id: modeSwitchTimer
        interval: 190
        onTriggered: {
            const m = store._pendingMode;
            store._pendingMode = "";
            if (m && store.activeMode !== m) {
                store.activeMode = m;
                store.passwordPromptId = "";
                store.passwordError = "";
                const conn = store.activeConnection;
                store.selectedId = conn ? conn.id : (store.currentList.length > 0 ? store.currentList[0].id : "");
                if (m === "bt") store.readProfiles();
            }
            store.modeSwitching = false;
        }
    }
    function openSearch() {
        if (!currentPower) return;
        searchOpen = true;
        Sounds.playSfx("notifications/Sine.wav", 0.36);
    }
    function closeSearch() {
        Sounds.playSfx("reusables/clickbutton/click.wav", 0.42);
        searchOpen = false;
        passwordPromptId = "";
        passwordError = "";
    }
    function triggerScan() { if (currentPower && !searchOpen) searchOpen = true; }
    // the styles' 10 s scan tick: the radios scan on their own while shown; this only refreshes the lists
    function runAutoScanTick() { if (currentPower) rebuild(); }

    function selectItem(id) {
        if (selectedId !== id) Sounds.playSfx("reusables/dropdown/click.wav", 0.4);
        selectedId = id;
        if (activeMode === "bt") {
            const dev = firstMatch(btDevices, d => d.id === id);
            if (dev && dev.connected) focusedBtMac = dev.mac;
        }
    }
    function cycleFocusedBt(step) {
        if (activeMode !== "bt") return;
        const list = connectedBtList;
        if (list.length < 2) return;
        let cur = Math.max(0, list.findIndex(d => d.mac === focusedBtMac));
        const next = (cur + step + list.length) % list.length;
        focusedBtMac = list[next].mac;
        selectedId = list[next].id;
        playProfileSfx("hover");
    }
    function copyIp(ip) {
        if (!ip || ip === "No IP") return;
        Sounds.playSfx("reusables/clickbutton/click.wav", 0.5);
        Quickshell.execDetached(["wl-copy", ip]);
        showToast("Copied IP: " + ip);
    }

    // ---------- power ----------
    function applyPower(mode, on) {
        if (mode === "wifi") Networking.wifiEnabled = on;
        else if (adapter) adapter.enabled = on;
    }
    function togglePower() {
        if (powerPendingMode !== "") return;
        const next = !currentPower;
        Sounds.playSfx(next ? "network/power_on.wav" : "network/power_off.wav", 0.65);
        powerPendingMode = activeMode;
        powerPendingTarget = next;
        searchOpen = false;
        passwordPromptId = "";
        passwordError = "";
        applyPower(activeMode, next);
        powerTimeout.restart();
    }
    // Gargantua's own implosion / big-bang animation plays its sounds and switches at its own moment
    function setPowerImmediate(on) {
        passwordPromptId = "";
        passwordError = "";
        applyPower(activeMode, on);
    }
    function settlePower() {
        if (powerPendingMode === "") return;
        const now = powerPendingMode === "wifi" ? wifiPower : btPower;
        if (now === powerPendingTarget) { powerPendingMode = ""; powerTimeout.stop(); }
    }
    Timer { id: powerTimeout; interval: 8000; onTriggered: store.powerPendingMode = "" }

    // ---------- connecting ----------
    property string pskId: ""            // the network being tried with a typed password
    onPskIdChanged: requestRebuild()
    property bool pskWasKnown: false
    function checkPassword(password) { return (password || "").length >= 8; }
    function submitPassword(id, password) {
        const net = findNet(id);
        if (!net || (password || "").length < 8) { passwordChecked(id, false); return; }
        holdCurrent(id);
        pskId = id;
        pskSawConnecting = false;
        pskWasKnown = isSaved(net);
        connectingId = id;
        net.connectWithPsk(password);
        pskTimeout.restart();
    }
    // a network that did connect is never counted as failed by the clock
    Timer { id: pskTimeout; interval: 25000; onTriggered: { const n = store.findNet(store.pskId); store.pskDone(!!n && n.connected); } }
    // A drop or a failure is believed only once the network has stayed down for a while. NetworkManager drops and
    // retries during an ordinary connection ("disconnected during association, retrying"), and acting at once used to
    // delete the profile of a network that was still connecting, so it never connected.
    property bool pskSawConnecting: false
    property string doubtId: ""
    function doubt(name) { doubtId = name; failWait.restart(); }
    Timer { id: failWait; interval: 6000; onTriggered: store.judgeFailure() }
    function judgeFailure() {
        const id = doubtId;
        doubtId = "";
        const net = findNet(id);
        if (net && net.connected) { settlePending(); return; }
        if (net && net.state === ConnectionState.Connecting) { doubt(id); return; }   // still trying: wait more
        if (id === pskId) { pskDone(false); return; }
        if (id === connectingId || id === assumeId) {
            connectingId = "";
            connectTimeout.stop();
            restorePrevious();
            Sounds.playSfx("network/error.wav");
            showToast("Could not connect to " + id);
        }
    }
    function onNetState(net) {
        if (!net) return;
        if (net.name === doubtId && (net.connected || net.state === ConnectionState.Connecting)) { failWait.stop(); doubtId = ""; }
        if (net.name !== pskId) return;
        if (net.state === ConnectionState.Connecting) pskSawConnecting = true;
        else if (net.state === ConnectionState.Disconnected && pskSawConnecting && !net.connected) doubt(net.name);
    }
    function cancelPsk() { if (pskId !== "") pskDone(false); }
    // closing the style mid-check cancels it (and forgets the half-tried profile), so no unchecked password stays
    Component.onDestruction: cancelPsk()

    function pskDone(ok) {
        if (pskId === "") return;
        const id = pskId;
        pskId = "";
        pskTimeout.stop();
        if (doubtId === id) { failWait.stop(); doubtId = ""; }
        connectingId = "";
        if (!ok && !pskWasKnown) {
            const net = findNet(id);
            if (net && net.known) net.forget();
        }
        readSaved();
        if (ok) { heldId = ""; prevId = ""; }
        else restorePrevious();
        passwordChecked(id, ok);
    }
    function onWifiFailed(name, reason) {
        if (name === pskId || name === connectingId || name === assumeId) doubt(name);
    }
    // a password check succeeds once that network is connected; a plain connect ends there too
    function settlePending() {
        const real = nets_realConnected();
        if (pskId !== "" && real === pskId) pskDone(true);
        if (assumeId !== "" && real === assumeId) { assumeId = ""; heldId = ""; prevId = ""; }
        if (heldId !== "" && real === heldId && pskId === "" && connectingId === "") { heldId = ""; prevId = ""; }
        const done = activeMode === "wifi" ? real === connectingId
                                           : btDevices.some(d => d.id === connectingId && d.connected);
        if (connectingId !== "" && done) {
            connectingId = "";
            connectTimeout.stop();
        }
    }
    function nets_realConnected() {
        const n = wifiDevice ? listOf(wifiDevice.networks).find(x => x.connected) : null;
        return n ? n.name : "";
    }
    Timer {
        id: connectTimeout
        interval: 20000
        onTriggered: {
            const was = store.connectingId;
            store.connectingId = "";
            if (store.nets_realConnected() !== was) store.restorePrevious();
        }
    }

    function requestConnect(id) {
        if (!currentPower || connectingId !== "") return;
        selectedId = id;
        const item = firstMatch(currentList, n => n.id === id);
        if (!item || item.connected) return;
        if (activeMode === "wifi" && item.locked && !item.saved) {
            passwordPromptId = passwordPromptId === id ? "" : id;
            passwordError = "";
            return;
        }
        startConnect(id);
    }
    function startConnect(id) {
        if (activeMode === "wifi") {
            const net = findNet(id);
            if (!net || net.connected || !canConnect(firstMatch(wifiNetworks, n => n.id === id))) return;
            holdCurrent(id);
            connectingId = id;
            net.connect();
        } else {
            const d = findBt(id);
            if (!d || d.connected) return;
            connectingId = id;
            d.trusted = true;
            if (d.paired || d.bonded) d.connect();
            else { pairThenConnect = id; d.pair(); }
        }
        connectTimeout.restart();
    }
    property string pairThenConnect: ""
    function onBtPaired(d) {
        if (d && d.paired && d.address === pairThenConnect) {
            pairThenConnect = "";
            d.connect();
        }
    }
    function markWifiSaved(id) {}
    // may this be connected without a password? (open, saved, or a Bluetooth device)
    function canConnect(item) { return !!item && (activeMode === "bt" || !item.locked || item.saved); }
    // the style calls this the moment a connection is asked for, so it runs while the animation plays
    function beginConnect(id) {
        const item = firstMatch(currentList, n => n.id === id);
        if (item && !item.connected && connectingId !== id && pskId !== id && canConnect(item)) startConnect(id);
    }
    // the style's connect animation has landed: connect for real now unless that is already under way; a locked
    // network without a password that worked is never tried (that would only leave an empty profile behind)
    function finalizeConnection(id, keepOpen) {
        beginConnect(id);
        if (activeMode === "wifi" && nets_realConnected() !== id && (connectingId === id || pskId === id)) {
            assumeId = id;
            heldId = "";
        }
        if (activeMode === "bt") focusedBtMac = id;
        Sounds.playSfx("network/connect.wav", 0.72);
        if (!keepOpen) searchOpen = false;
    }
    function disconnectItem(id, keepOpen) {
        Sounds.playSfx("network/disconnect.wav", 0.72);
        if (!keepOpen) searchOpen = false;
        if (activeMode === "wifi") { const n = findNet(id); if (n) n.disconnect(); }
        else { const d = findBt(id); if (d) d.disconnect(); }
    }
    function forgetActive() {
        const c = activeConnection;
        if (!c) return;
        Sounds.playSfx("network/disconnect.wav", 0.7);
        searchOpen = false;
        if (activeMode === "wifi") { const n = findNet(c.id); if (n) n.forget(); }
        else unpairBt(c.mac);
    }
    function unpairBt(mac) {
        const d = findBt(mac);
        if (!d) return;
        Sounds.playSfx("network/disconnect.wav", 0.55);
        d.forget();
    }
    function requestUnpair(mac) {
        if (confirmUnpairMac === mac) {
            confirmUnpairMac = "";
            unpairConfirmTimer.stop();
            unpairBt(mac);
        } else {
            Sounds.playSfx("reusables/clickbutton/click2.wav", 0.45);
            confirmUnpairMac = mac;
            unpairConfirmTimer.restart();
        }
    }
    Timer { id: unpairConfirmTimer; interval: 2600; onTriggered: store.confirmUnpairMac = "" }
    function cancelPassword() {
        Sounds.playSfx("reusables/clickbutton/click.wav", 0.4);
        passwordPromptId = "";
        passwordError = "";
    }
    // an audio device switches between Hi-Fi (A2DP) and Headset (HFP)
    function cycleBtProfile(mac) {
        const dev = firstMatch(btDevices, d => d.mac === mac);
        if (!dev || !dev.hasAudioProfile) return;
        Sounds.playSfx("network/switch.wav", 0.55);
        const card = "bluez_card." + mac.replace(/:/g, "_");
        const next = dev.profile === "Hi-Fi (A2DP)" ? "headset-head-unit" : "a2dp-sink";
        Quickshell.execDetached(["pactl", "set-card-profile", card, next]);
        profileAgain.restart();
    }
    Timer { id: profileAgain; interval: 900; onTriggered: store.readProfiles() }
}
