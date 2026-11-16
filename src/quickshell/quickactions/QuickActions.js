.pragma library

var defaultIds = ["launcher", "system", "timer", "screenshot"];
var positions = ["left", "bottom", "right", "top"];
var types = {
    launcher: { label: "quickactions.tabs.launcher", icon: "󰵆", file: "" },
    system: { label: "quickactions.tabs.system", icon: "󰍛", file: "actions/SystemUsage.qml" },
    timer: { label: "quickactions.tabs.timer", icon: "󰔛", file: "actions/Timer.qml" },
    calculator: { label: "quickactions.tabs.calculator", icon: "󰃬", file: "actions/Calculator.qml" },
    screenshot: { label: "quickactions.tabs.screenshot", icon: "󰹑", file: "" },
    settings: { label: "quickactions.tabs.settings", icon: "󰒓", file: "actions/Settings.qml" }
};

function position(settings) {
    var value = settings && settings.position;
    return positions.indexOf(value) >= 0 ? value : "left";
}

function enabledIds(settings) {
    var ids = settings && Array.isArray(settings.modules) ? settings.modules : defaultIds;
    return ids.filter(function(id, index) {
        return typeof id === "string" && Object.prototype.hasOwnProperty.call(types, id)
            && ids.indexOf(id) === index;
    });
}

function moduleInBar(modules, id) {
    return !!modules && ["left", "center", "right"].some(function(edge) {
        return Array.isArray(modules[edge]) && modules[edge].some(function(item) {
            return item === id || (Array.isArray(item) && item.indexOf(id) >= 0);
        });
    });
}

function settingsInBar(modules) {
    return moduleInBar(modules, "settings");
}

function groups(settings, barModules) {
    var result = { left: [], bottom: [], right: [], top: [] };
    var modules = settings && settings.modules;
    if (!modules || Array.isArray(modules) || typeof modules !== "object") {
        modules = {};
        modules[position(settings)] = enabledIds(settings);
    }
    var seen = ["settings"].filter(function(id) { return moduleInBar(barModules, id); });
    for (var edge of positions) {
        result[edge] = enabledIds({ modules: Array.isArray(modules[edge]) ? modules[edge] : [] }).filter(function(id) {
            if (seen.indexOf(id) >= 0) return false;
            seen.push(id);
            return true;
        });
    }
    return result;
}
