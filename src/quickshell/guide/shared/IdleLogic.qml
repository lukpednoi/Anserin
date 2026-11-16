import QtQuick
import Quickshell
import "../../"

// What the Idle page does, without its look: the idle settings, the built-in steps (dim, lock, display off,
// suspend) and custom ones, their order check, timeouts, inhibitors and commands, adding and deleting custom
// steps. Used by the Settings page (IdleTab.qml) and the Control Center's board. `rootObj` is the host window.
Item {
    id: logic
    property var rootObj: null

    readonly property bool isNiri: {
        const de = (typeof SystemInfo !== "undefined" && SystemInfo.desktopEnv) ? SystemInfo.desktopEnv.toLowerCase() : "";
        return de.indexOf("niri") !== -1 || (Quickshell.env("XDG_CURRENT_DESKTOP") || "").toLowerCase().indexOf("niri") !== -1;
    }

    property var expandedActionMap: ({})

    function toggleActionExpanded(id) {
        let map = Object.assign({}, logic.expandedActionMap);
        map[id] = !map[id];
        logic.expandedActionMap = map;
    }

    property var defaultIdleSettings: ({
        "enabled": false,
        "manualInhibit": false,
        "actions": {
            "dim": {
                "id": "dim",
                "name": "Dim Screen",
                "timeout": 120,
                "enabled": true,
                "respectInhibitors": true,
                "mprisInhibit": true,
                "warningTimeout": 0,
                "warningCommand": "",
                "beforeCommand": "",
                "resumeCommand": "",
                "isCustom": false
            },
            "lock": {
                "id": "lock",
                "name": "Lock Session",
                "timeout": 300,
                "enabled": true,
                "respectInhibitors": true,
                "mprisInhibit": true,
                "warningTimeout": 10,
                "warningCommand": "",
                "beforeCommand": "",
                "resumeCommand": "",
                "isCustom": false
            },
            "dpms": {
                "id": "dpms",
                "name": "Display Off (DPMS)",
                "timeout": 360,
                "enabled": true,
                "respectInhibitors": true,
                "mprisInhibit": true,
                "warningTimeout": 0,
                "warningCommand": "",
                "beforeCommand": "",
                "resumeCommand": "",
                "isCustom": false
            },
            "suspend": {
                "id": "suspend",
                "name": "System Suspend",
                "timeout": 600,
                "enabled": true,
                "respectInhibitors": true,
                "mprisInhibit": true,
                "warningTimeout": 30,
                "warningCommand": "",
                "isCustom": false
            }
        },
        "customActions": []
    })

    property var idleSettings: {
        let s = (typeof Config !== "undefined" && Config.rawSettings) ? Config.rawSettings["idle"] : undefined;
        if (s !== undefined && s !== null) return s;
        if (typeof Config !== "undefined" && typeof Config.getSetting === "function") {
            return Config.getSetting("idle", logic.defaultIdleSettings);
        }
        return logic.defaultIdleSettings;
    }

    property bool idleEnabled: idleSettings && idleSettings.enabled !== undefined ? idleSettings.enabled : false

    property bool manualInhibit: idleSettings && idleSettings.manualInhibit !== undefined ? idleSettings.manualInhibit : false

    property var actionIdsList: ["dim", "lock", "dpms", "suspend"]

    function refreshActionIds() {
        let list = ["dim", "lock", "dpms", "suspend"];
        let customs = (idleSettings && idleSettings.customActions && Array.isArray(idleSettings.customActions)) ? idleSettings.customActions : [];
        for (let i = 0; i < customs.length; i++) {
            if (customs[i] && customs[i].id) {
                list.push(customs[i].id);
            }
        }
        let current = logic.actionIdsList;
        let same = (current && current.length === list.length);
        if (same) {
            for (let j = 0; j < list.length; j++) {
                if (current[j] !== list[j]) {
                    same = false;
                    break;
                }
            }
        }
        if (!same) {
            logic.actionIdsList = list;
        }
    }

    onIdleSettingsChanged: refreshActionIds()

    function isCustomAction(actId) {
        return actId !== "dim" && actId !== "lock" && actId !== "dpms" && actId !== "suspend";
    }

    function getActionData(actId) {
        if (!actId) return null;
        if (actId === "dim" || actId === "lock" || actId === "dpms" || actId === "suspend") {
            let acts = (idleSettings && idleSettings.actions) ? idleSettings.actions : defaultIdleSettings.actions;
            let def = defaultIdleSettings.actions[actId] || {};
            let act = (acts && acts[actId]) ? acts[actId] : {};
            return Object.assign({}, def, act);
        }
        let customs = (idleSettings && idleSettings.customActions && Array.isArray(idleSettings.customActions)) ? idleSettings.customActions : [];
        for (let i = 0; i < customs.length; i++) {
            if (customs[i] && customs[i].id === actId) {
                return customs[i];
            }
        }
        return null;
    }

    function getActionTimeout(act) {
        if (!act || act.timeout === undefined || act.timeout === null || isNaN(act.timeout) || act.timeout <= 0) {
            if (act && act.id === "dim") return 120;
            if (act && act.id === "lock") return 300;
            if (act && act.id === "dpms") return 360;
            if (act && act.id === "suspend") return 600;
            return 300;
        }
        return Math.max(1, Math.round(Number(act.timeout)));
    }

    function isActionPipelineValid(actionObj) {
        if (!actionObj) return true;
        let id = (actionObj.id || "").toLowerCase();
        let builtInOrder = ["dim", "lock", "dpms", "suspend"];
        let idx = builtInOrder.indexOf(id);
        if (idx === -1) return true;

        let acts = (idleSettings && idleSettings.actions) ? idleSettings.actions : defaultIdleSettings.actions;
        let myTimeout = logic.getActionTimeout(actionObj);

        for (let j = idx + 1; j < builtInOrder.length; j++) {
            let nextKey = builtInOrder[j];
            let nextAct = (acts && acts[nextKey]) ? Object.assign({}, defaultIdleSettings.actions[nextKey], acts[nextKey]) : defaultIdleSettings.actions[nextKey];
            let nextEnabled = nextAct && nextAct.enabled !== undefined ? nextAct.enabled : true;
            if (nextEnabled) {
                let nextTimeout = logic.getActionTimeout(nextAct);
                if (myTimeout >= nextTimeout) return false;
            }
        }
        return true;
    }

    function getActionTitle(act, actId) {
        let id = actId || (act ? act.id : "");
        if (id === "dim") return I18n.t("guide.idle.dim.title", "Dim Screen");
        if (id === "lock") return I18n.t("guide.idle.lock.title", "Lock Session");
        if (id === "dpms") return I18n.t("guide.idle.dpms.title", "Display Off (DPMS)");
        if (id === "suspend") return I18n.t("guide.idle.suspend.title", "System Suspend");
        return (act && act.name) ? act.name : I18n.t("guide.idle.custom_action_fallback", "Custom Action");
    }

    function getActionDescription(act, actId) {
        let id = actId || (act ? act.id : "");
        if (id === "dim") return I18n.t("guide.idle.dim.desc", "Reduce screen brightness before locking");
        if (id === "lock") return I18n.t("guide.idle.lock.desc", "Lock the session after a period of inactivity");
        if (id === "dpms") return I18n.t("guide.idle.dpms.desc", "Turn off monitor display signal");
        if (id === "suspend") return I18n.t("guide.idle.suspend.desc", "Suspend the system to sleep mode");
        return (act && act.desc) ? act.desc : ((act && act.command) ? act.command : I18n.t("guide.idle.custom_action_desc", "Custom timeout action and command"));
    }

    function getDefaultResumeCommand(actId) {
        if (actId === "dpms") return logic.isNiri ? "niri msg action power-on-monitors" : "hyprctl dispatch 'hl.dsp.dpms({ action = \"enable\" })' || hyprctl dispatch dpms on";
        return I18n.t("guide.idle.resume_command.placeholder", "Resume command");
    }

    function saveCustomAction(actionObj) {
        let sanitizeId = (actionObj.id || "").replace(/[^a-zA-Z0-9_\-]/g, "").trim();
        if (sanitizeId === "") sanitizeId = "action_" + Date.now();
        actionObj.id = sanitizeId;
        actionObj.isCustom = true;

        let current = JSON.parse(JSON.stringify(Config.getSetting("idle", defaultIdleSettings) || defaultIdleSettings));
        if (!current.customActions || !Array.isArray(current.customActions)) current.customActions = [];
        let customs = current.customActions;
        let idx = customs.findIndex(a => a && a.id === sanitizeId);
        if (idx !== -1) {
            customs[idx] = actionObj;
        } else {
            customs.push(actionObj);
        }
        current.customActions = customs;
        Config.setSetting("idle", current);
        logic.refreshActionIds();
    }

    function deleteCustomAction(actionId) {
        let current = JSON.parse(JSON.stringify(Config.getSetting("idle", defaultIdleSettings) || defaultIdleSettings));
        if (!current.customActions || !Array.isArray(current.customActions)) return;
        current.customActions = current.customActions.filter(a => a && a.id !== actionId);
        Config.setSetting("idle", current);
        logic.refreshActionIds();
    }

    function createNewAction() {
        let newId = "custom_" + Date.now();
        let newAction = {
            "id": newId,
            "name": I18n.t("guide.idle.custom_action_default", "New Action"),
            "desc": "",
            "timeout": 300,
            "enabled": true,
            "respectInhibitors": true,
            "mprisInhibit": false,
            "warningTimeout": 0,
            "warningCommand": "",
            "command": "",
            "beforeCommand": "",
            "resumeCommand": "",
            "isCustom": true
        };
        logic.saveCustomAction(newAction);
    }

    function updateActionProp(actionId, isCustom, propKey, value) {
        if (propKey === "timeout" && (isNaN(value) || value <= 0)) return;
        let current = JSON.parse(JSON.stringify(Config.getSetting("idle", defaultIdleSettings) || defaultIdleSettings));

        if (isCustom) {
            let customs = (current.customActions && Array.isArray(current.customActions)) ? current.customActions : [];
            let found = customs.find(a => a && a.id === actionId);
            if (found) {
                found[propKey] = value;
                current.customActions = customs;
                Config.setSetting("idle", current);
            }
        } else {
            if (!current.actions) current.actions = JSON.parse(JSON.stringify(defaultIdleSettings.actions));
            if (!current.actions[actionId]) current.actions[actionId] = JSON.parse(JSON.stringify(defaultIdleSettings.actions[actionId] || {}));
            current.actions[actionId][propKey] = value;
            Config.setSetting("idle", current);
        }
    }

    function updateRootSetting(propKey, value) {
        let current = JSON.parse(JSON.stringify(Config.getSetting("idle", defaultIdleSettings) || defaultIdleSettings));
        current[propKey] = value;
        Config.setSetting("idle", current);
    }

    Component.onCompleted: logic.refreshActionIds()
}
