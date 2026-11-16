pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

Item {
    id: root
    readonly property var settings: Config.getSetting("idle", {})
    readonly property bool enabled: !!settings.manualInhibit
    readonly property double endTime: Number(settings.caffeineEndTime || 0)
    // Keep Awake with no end time (idle.keepAwakeMode "forever", or switched on in the Settings window)
    readonly property bool forever: enabled && endTime <= 0
    // How Keep Awake starts, set on the Control tab's Idle page: "timer" for idle.keepAwakeMinutes, or "forever"
    readonly property bool foreverMode: settings.keepAwakeMode === "forever"
    readonly property int timerMinutes: {
        const m = Number(settings.keepAwakeMinutes);
        return isFinite(m) && m > 0 ? Math.round(Math.max(5, Math.min(480, m))) : 60;
    }
    property int remainingSeconds: 0
    readonly property string remainingTimeString: {
        if (forever) return "∞";
        if (remainingSeconds <= 0) return "< 1m";
        const hours = Math.floor(remainingSeconds / 3600);
        const minutes = Math.floor((remainingSeconds % 3600) / 60);
        return hours > 0 ? hours + "h " + (minutes < 10 ? "0" : "") + minutes + "m" : Math.max(1, minutes) + "m";
    }

    // Works from the saved idle settings, not `settings`, which can lag while bindings are still updating.
    function setDuration(durationMs, extend) {
        const now = Date.now();
        const active = durationMs > 0;
        const current = Config.getSetting("idle", {});
        const keep = extend && !!current.manualInhibit;
        const next = Object.assign({}, current);
        next.manualInhibit = active;
        next.caffeineStartTime = active ? (keep ? current.caffeineStartTime || now : now) : 0;
        next.caffeineEndTime = active ? (keep ? Math.max(now, Number(current.caffeineEndTime || 0)) : now) + durationMs : 0;
        Config.setSetting("idle", next);
        stateWriter.setText(JSON.stringify({enabled: active, startTime: next.caffeineStartTime,
            enabledAt: active ? new Date(next.caffeineStartTime).toISOString() : "",
            endTime: next.caffeineEndTime, durationSeconds: active ? (next.caffeineEndTime-next.caffeineStartTime)/1000 : 0}));
        remainingSeconds = active ? Math.ceil((next.caffeineEndTime - now) / 1000) : 0;
    }
    function setForever() {
        const now = Date.now();
        const next = Object.assign({}, Config.getSetting("idle", {}));
        next.manualInhibit = true;
        next.caffeineStartTime = now;
        next.caffeineEndTime = 0;
        Config.setSetting("idle", next);
        stateWriter.setText(JSON.stringify({enabled: true, startTime: now, enabledAt: new Date(now).toISOString(),
            endTime: 0, durationSeconds: 0}));
        remainingSeconds = 0;
    }
    function start() { if (foreverMode) setForever(); else setDuration(timerMinutes * 60000, false); }
    function stop() { setDuration(0, false); }
    function toggle() { if (enabled) stop(); else start(); }
    // one more hour on a timed Keep Awake; one with no end has nothing to add
    function extend() { if (!forever) setDuration(3600000, true); }
    function updateRemaining() {
        remainingSeconds = enabled && endTime > 0 ? Math.max(0, Math.ceil((endTime-Date.now())/1000)) : 0;
        // Expiry is applied after the current binding update, so it never writes settings from inside one.
        if (enabled && endTime > 0 && remainingSeconds === 0) Qt.callLater(root.expire);
    }
    function expire() {
        const current = Config.getSetting("idle", {});
        const end = Number(current.caffeineEndTime || 0);
        if (current.manualInhibit && end > 0 && end <= Date.now()) setDuration(0, false);
    }
    FileView { id: stateWriter; path: Caching.runDir + "/caffeine_state.json"; preload: false }
    Timer {
        interval: 1000
        repeat: true
        running: root.enabled && root.endTime > 0
        triggeredOnStart: true
        onTriggered: root.updateRemaining()
    }
    onEndTimeChanged: updateRemaining()
    Component.onCompleted: updateRemaining()
}
