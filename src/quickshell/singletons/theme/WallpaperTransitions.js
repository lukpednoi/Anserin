.pragma library

var ids = ["fade", "wipe", "circle", "swipe", "paint"];
var directions = ["left", "right", "top", "bottom", "top_left", "top_right", "bottom_left", "bottom_right"];
var defaults = {
    mode: "custom", pool: ["fade"],
    effects: {
        fade: {duration: 1000},
        wipe: {duration: 1600, orientation: "random"},
        circle: {duration: 1600, origin: "random"},
        swipe: {duration: 1600, direction: "random"},
        paint: {duration: 2400}
    }
};

function settings(value) {
    var saved = value && typeof value === "object" ? value : {};
    var pool = Array.isArray(saved.pool) ? ids.filter(function(id) { return saved.pool.indexOf(id) >= 0; }) : defaults.pool.slice();
    if (!pool.length) pool = defaults.pool.slice();
    var effects = {};
    ids.forEach(function(id) {
        effects[id] = Object.assign({}, defaults.effects[id], saved.effects && saved.effects[id]);
        var duration = Number(effects[id].duration);
        effects[id].duration = isFinite(duration) ? Math.max(100, Math.min(10000, Math.round(duration))) : defaults.effects[id].duration;
    });
    return {mode: saved.mode === "random" ? "random" : "custom", pool: pool, effects: effects};
}

function resolve(value, type) {
    var saved = settings(value);
    var index = typeof type === "number" ? type : ids.indexOf(type);
    var candidates = saved.mode === "custom" ? saved.pool : ids;
    var id = index >= 0 && index < ids.length ? ids[index] : candidates[Math.floor(Math.random() * candidates.length)];
    var effect = saved.effects[id];
    var direction = directions.indexOf(effect.direction);
    return {
        type: ids.indexOf(id), duration: effect.duration,
        vertical: effect.orientation === "vertical" || (effect.orientation !== "horizontal" && Math.random() < .5),
        direction: direction >= 0 ? direction : Math.floor(Math.random() * directions.length),
        centered: effect.origin === "center"
    };
}
