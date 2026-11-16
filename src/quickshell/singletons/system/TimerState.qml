pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// The Timer, Stopwatch and Pomodoro state, shared by every Timer view (Quick Actions and the left edge panel),
// so they show the same time and a finished timer notifies once. Loaded from the saved state when the first
// view opens (ensureLoaded); the ticker runs only while something is counting.
Item {
    id: root

    // What the bar's Info module shows while something runs.
    property var entries: []
    readonly property bool isActive: entries.length > 0

    property bool stateLoaded: false
    property bool loadRequested: false

    property int activeMode: 0

    property real timerTargetEpoch: 0
    property int timerRemainingMs: 5 * 60 * 1000
    property int timerPresetMs: 5 * 60 * 1000

    property real swStartEpoch: 0
    property int swAccumulatedMs: 0
    property real swDisplayMs: 0
    property var swLapData: []

    property int pomoState: 0
    property real pomoTargetEpoch: 0
    property int pomoRemainingMs: 25 * 60 * 1000

    property int pomoWorkLimit: 25
    property int pomoShortBreakLimit: 5
    property int pomoLongBreakLimit: 15
    property int pomoTargetSessions: 4
    property int pomoSessionsCount: 0

    readonly property bool anyTimerActive: timerTargetEpoch > 0 || swStartEpoch > 0 || pomoTargetEpoch > 0
    onAnyTimerActiveChanged: updateExportedState()

    onPomoWorkLimitChanged: {
        if (stateLoaded && pomoTargetEpoch === 0 && pomoState === 0) {
            pomoRemainingMs = pomoWorkLimit * 60 * 1000;
            saveFullState();
        }
    }
    onPomoShortBreakLimitChanged: {
        if (stateLoaded && pomoTargetEpoch === 0 && pomoState === 1) {
            pomoRemainingMs = pomoShortBreakLimit * 60 * 1000;
            saveFullState();
        }
    }
    onPomoLongBreakLimitChanged: {
        if (stateLoaded && pomoTargetEpoch === 0 && pomoState === 2) {
            pomoRemainingMs = pomoLongBreakLimit * 60 * 1000;
            saveFullState();
        }
    }

    function getStorageDir() {
        return Quickshell.env("QS_RUN_FOCUSTIME") || (Quickshell.env("XDG_RUNTIME_DIR") + "/anserin/focustime");
    }

    function ensureLoaded() {
        if (loadRequested) return;
        loadRequested = true;
        stateInitProc.running = true;
    }

    function formatTime(ms, includeMs) {
        if (ms < 0) ms = 0;
        let totalSeconds = Math.floor(ms / 1000);
        let hours = Math.floor(totalSeconds / 3600);
        let minutes = Math.floor((totalSeconds % 3600) / 60);
        let seconds = totalSeconds % 60;

        let out = "";
        if (hours > 0) out += hours.toString().padStart(2, '0') + ":";
        out += minutes.toString().padStart(2, '0') + ":" + seconds.toString().padStart(2, '0');

        if (includeMs) {
            let millis = Math.floor((ms % 1000) / 10);
            out += "." + millis.toString().padStart(2, '0');
        }
        return out;
    }

    Process { id: notifyProc }
    Process { id: saveFullStateProc }

    function notify(title, message, icon) {
        notifyProc.running = false;
        notifyProc.command = ["notify-send", "-a", I18n.t("quickactions.timer.notification.app_name"), "-i", icon, title, message];
        notifyProc.running = true;
    }

    function saveFullState() {
        if (!stateLoaded) return;
        let dir = getStorageDir();
        let payload = {
            activeMode: activeMode,
            timerTargetEpoch: timerTargetEpoch,
            timerRemainingMs: timerRemainingMs,
            timerPresetMs: timerPresetMs,
            swStartEpoch: swStartEpoch,
            swAccumulatedMs: swAccumulatedMs,
            swLapData: swLapData,
            pomoState: pomoState,
            pomoTargetEpoch: pomoTargetEpoch,
            pomoRemainingMs: pomoRemainingMs,
            pomoWorkLimit: pomoWorkLimit,
            pomoShortBreakLimit: pomoShortBreakLimit,
            pomoLongBreakLimit: pomoLongBreakLimit,
            pomoTargetSessions: pomoTargetSessions,
            pomoSessionsCount: pomoSessionsCount
        };
        let jsonStr = JSON.stringify(payload);
        saveFullStateProc.running = false;
        saveFullStateProc.command = ["bash", "-c", "mkdir -p '" + dir + "' && echo '" + jsonStr.replace(/'/g, "'\\''") + "' > '" + dir + "/saved_state.json'"];
        saveFullStateProc.running = true;
    }

    function notifyTimerFinished() {
        notify(I18n.t("quickactions.timer.notification.timer_finished_title"),
               I18n.t("quickactions.timer.notification.timer_finished_body", { time: formatTime(timerPresetMs, false) }),
               "preferences-system-time");
    }

    function notifyPomoPhaseEnded() {
        if (pomoState === 0) {
            notify(I18n.t("quickactions.timer.notification.focus_complete_title"),
                   I18n.t("quickactions.timer.notification.focus_complete_body"), "preferences-system-time");
        } else {
            notify(I18n.t("quickactions.timer.notification.break_over_title"),
                   I18n.t("quickactions.timer.notification.break_over_body"), "preferences-system-time");
        }
    }

    function restoreState(rawText) {
        let txt = (rawText || "").trim();
        if (txt !== "") {
            try {
                let data = JSON.parse(txt);
                if (data) {
                    if (data.activeMode !== undefined) activeMode = data.activeMode;
                    if (data.timerPresetMs !== undefined) timerPresetMs = data.timerPresetMs;
                    if (data.pomoWorkLimit !== undefined) pomoWorkLimit = data.pomoWorkLimit;
                    if (data.pomoShortBreakLimit !== undefined) pomoShortBreakLimit = data.pomoShortBreakLimit;
                    if (data.pomoLongBreakLimit !== undefined) pomoLongBreakLimit = data.pomoLongBreakLimit;
                    if (data.pomoTargetSessions !== undefined) pomoTargetSessions = data.pomoTargetSessions;
                    if (data.pomoSessionsCount !== undefined) pomoSessionsCount = data.pomoSessionsCount;
                    if (data.pomoState !== undefined) pomoState = data.pomoState;
                    if (data.swLapData !== undefined && Array.isArray(data.swLapData)) swLapData = data.swLapData;
                    if (data.swAccumulatedMs !== undefined) swAccumulatedMs = data.swAccumulatedMs;

                    let now = Date.now();

                    if (data.timerTargetEpoch && data.timerTargetEpoch > 0) {
                        if (now >= data.timerTargetEpoch) {
                            timerTargetEpoch = 0;
                            timerRemainingMs = 0;
                            notifyTimerFinished();
                        } else {
                            timerTargetEpoch = data.timerTargetEpoch;
                            timerRemainingMs = Math.max(0, data.timerTargetEpoch - now);
                        }
                    } else if (data.timerRemainingMs !== undefined) {
                        timerRemainingMs = data.timerRemainingMs;
                        timerTargetEpoch = 0;
                    }

                    if (data.swStartEpoch && data.swStartEpoch > 0) {
                        swStartEpoch = data.swStartEpoch;
                        swDisplayMs = swAccumulatedMs + (now - data.swStartEpoch);
                    } else {
                        swStartEpoch = 0;
                        swDisplayMs = swAccumulatedMs;
                    }

                    if (data.pomoTargetEpoch && data.pomoTargetEpoch > 0) {
                        if (now >= data.pomoTargetEpoch) {
                            pomoTargetEpoch = 0;
                            pomoRemainingMs = 0;
                            notifyPomoPhaseEnded();
                            handleSessionComplete();
                        } else {
                            pomoTargetEpoch = data.pomoTargetEpoch;
                            pomoRemainingMs = Math.max(0, data.pomoTargetEpoch - now);
                        }
                    } else if (data.pomoRemainingMs !== undefined) {
                        pomoRemainingMs = data.pomoRemainingMs;
                        pomoTargetEpoch = 0;
                    }
                }
            } catch(e) {}
        }
        stateLoaded = true;
        updateExportedState();
        saveFullState();
    }

    Process {
        id: stateInitProc
        command: ["bash", "-c", "STATE_FILE='" + root.getStorageDir() + "/saved_state.json'; if [ -f \"$STATE_FILE\" ]; then cat \"$STATE_FILE\"; fi"]
        stdout: StdioCollector {
            id: stateInitOut
            onStreamFinished: root.restoreState(stateInitOut.text)
        }
    }

    function updateExportedState() {
        let list = [];
        if (timerTargetEpoch > 0) list.push({ icon: "", time: formatTime(timerRemainingMs, false), colorType: "mauve" });
        if (swStartEpoch > 0) list.push({ icon: "", time: formatTime(swDisplayMs, false), colorType: "mauve" });
        if (pomoTargetEpoch > 0) list.push({ icon: "", time: formatTime(pomoRemainingMs, false), colorType: pomoState !== 0 ? "green" : "mauve" });
        entries = list;
    }

    // Start or pause whatever the chosen tab counts.
    function toggleMode() {
        let now = Date.now();
        if (activeMode === 0) {
            if (timerTargetEpoch > 0) {
                timerTargetEpoch = 0;
            } else {
                if (timerRemainingMs <= 0) timerRemainingMs = timerPresetMs;
                timerTargetEpoch = now + timerRemainingMs;
            }
        } else if (activeMode === 1) {
            if (swStartEpoch > 0) {
                swAccumulatedMs += (now - swStartEpoch);
                swStartEpoch = 0;
            } else {
                swStartEpoch = now;
            }
        } else if (activeMode === 2) {
            if (pomoTargetEpoch > 0) pomoTargetEpoch = 0;
            else pomoTargetEpoch = now + pomoRemainingMs;
        }
        saveFullState();
        updateExportedState();
    }

    function handleSessionComplete() {
        if (pomoState === 0) {
            pomoSessionsCount++;
            if (pomoSessionsCount >= pomoTargetSessions) {
                pomoState = 2;
                pomoSessionsCount = 0;
                pomoRemainingMs = pomoLongBreakLimit * 60 * 1000;
            } else {
                pomoState = 1;
                pomoRemainingMs = pomoShortBreakLimit * 60 * 1000;
            }
        } else {
            pomoState = 0;
            pomoRemainingMs = pomoWorkLimit * 60 * 1000;
        }
        saveFullState();
        updateExportedState();
    }

    Timer {
        id: globalTicker
        interval: 32
        repeat: true
        running: root.anyTimerActive
        onTriggered: {
            let now = Date.now();

            if (root.timerTargetEpoch > 0) {
                let rem = root.timerTargetEpoch - now;
                if (rem <= 0) {
                    root.timerRemainingMs = 0;
                    root.timerTargetEpoch = 0;
                    root.notifyTimerFinished();
                    root.saveFullState();
                } else {
                    root.timerRemainingMs = rem;
                }
            }

            root.swDisplayMs = root.swStartEpoch > 0 ? root.swAccumulatedMs + (now - root.swStartEpoch) : root.swAccumulatedMs;

            if (root.pomoTargetEpoch > 0) {
                let rem = root.pomoTargetEpoch - now;
                if (rem <= 0) {
                    root.pomoTargetEpoch = 0;
                    root.pomoRemainingMs = 0;
                    root.notifyPomoPhaseEnded();
                    root.handleSessionComplete();
                } else {
                    root.pomoRemainingMs = rem;
                }
            }

            root.updateExportedState();
        }
    }
}
