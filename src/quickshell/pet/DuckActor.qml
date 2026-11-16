import QtQuick
import "."

// The duck as a character: a DuckRig standing on the parent's floors, acting out one action at a time, with every
// change of pose eased so actions run smoothly into each other. Meant for the Animation Lab now and the desktop
// pet later. The parent sets `floors` ([{x1, x2, y}], y = where feet stand) and moves nothing itself.
//
//   play(name, opts)  starts an action: idle, walk {x}, sit, preenBreast, preenWing, peck, peckAt {x, y},
//                     peckAround {count}, petted, held, drop {vx, vy}, stretch, quack, dive (on water). `random` picks actions by itself, like the desktop pet will.
//   Mouse: press the head and hold to pet it; press the body and drag to carry it (limp), let go in the air and it
//   flutters down slowly; right-click shows a pencil (pencilClicked()).
// One FrameAnimation drives everything while it moves (15 ticks a second while it idles or sits), only while visible.
Item {
    id: actor
    property real size: 128                 // the duck's height in px, head to feet
    property var floors: []
    property bool random: false
    property bool quackInRandom: true        // the desktop pet quacks on its own timer instead
    // in place: everything happens on the spot (walking steps without going anywhere, no walking to a target);
    // for the editor's preview
    property bool inPlace: false
    property string colour: "white"
    // on water (a river): only the part above the surface shows (py is the surface), no legs, it bobs and can dive
    property bool swimming: false
    // held still mid-pose (the editor freezes it while carrying it into its box); nothing moves or eases
    property bool frozen: false
    property bool soundOn: true
    property string labelFont: "sans-serif"
    signal quacked()
    signal pencilClicked()

    // where its feet are, and which way it looks
    property real px: 200
    property real py: 300
    property int facing: 1
    readonly property real k: size / 232     // drawing units (head top 48 .. feet 280) to px
    readonly property string action: act ? act.name : ""
    property var act: null
    property real clock: 0
    property real nextBlink: 3

    // the pose every action aims for; the rig eases toward it
    readonly property var rest: ({ rock: 0, bob: 0, shakeX: 0, stretchY: 0, breath: 0, headAngle: 0, headX: 0, headY: 0,
                                   eyesClosed: 0, jawOpen: 0, flap: 0, tailWag: 0, legSwing: 0, farLegSwing: 0 })
    readonly property var fast: ({ flap: 1, legSwing: 1, farLegSwing: 1, jawOpen: 1, tailWag: 1, shakeX: 1 })

    width: 400 * k
    height: 300 * k
    x: px - 194 * k
    y: py - 276 * k

    // ---------- helpers ----------
    function floorBelow(fx, fy) {
        let best = Infinity;
        for (const f of floors) if (fx >= f.x1 && fx <= f.x2 && f.y >= fy - 1 && f.y < best) best = f.y;
        return best;
    }
    function floorUnder() {
        for (const f of floors) if (px >= f.x1 && px <= f.x2 && Math.abs(f.y - py) < 2) return f;
        return null;
    }
    function ease(u) { u = Math.max(0, Math.min(1, u)); return u < 0.5 ? 4 * u * u * u : 1 - Math.pow(-2 * u + 2, 3) / 2; }
    function bump(u) { u = Math.max(0, Math.min(1, u)); return Math.sin(Math.PI * u); }
    function rnd(a, b) { return a + Math.random() * (b - a); }
    // where the head is now, in the parent (for petting and for reaching)
    function headPoint() { return Qt.point(px + facing * (276 - 194 + rig.headX) * k, py + (96 - 276 + rig.headY) * k + sink); }

    function play(name, opts) {
        const o = opts || {};
        act = { name: name, t: 0, o: o, phase: 0, done: false };
        if (name === "walk" && o.x === undefined) act.o.x = px;
        if (name === "quack" || name === "petted" || name === "held") sayQuack();
    }
    // calm actions are drawn 15 times a second instead of every frame, but only once the pose has settled from
    // whatever came before (easing back at 15 a second is what looked jerky)
    property bool calm: false
    function updateCalm() {
        calm = !!act && (act.name === "idle" || act.name === "sit") && act.t > 1.2 && act.flickT === undefined
               && Math.abs(rig.headAngle) + Math.abs(rig.headX) + Math.abs(rig.headY) + Math.abs(rig.rock) + Math.abs(rig.flap) + Math.abs(rig.tailWag) < 1.5;
    }

    // ---------- the actions: each sets the target pose `p` for time `t`, and may move the duck ----------
    function step(dt) {
        const a = act, p = Object.assign({}, rest), t = a.t;
        // breathing and blinking under every action that does not shut the eyes itself
        p.breath = 0.5 - 0.5 * Math.cos(2 * Math.PI * clock / 3);
        if (clock > nextBlink) { if (clock > nextBlink + 0.13) nextBlink = clock + rnd(2.5, 6); else p.eyesClosed = 1; }

        switch (a.name) {
        case "idle":
            p.tailWag = Math.sin(clock * 1.3) * 2;
            if (a.o.dur && t > a.o.dur) a.done = true;
            break;
        case "walk":
            if (inPlace) { steps(a, 0.55 * size * dt, p); if (t > (a.o.dur || 2.5)) a.done = true; }
            else if (walkTo(a, a.o.x, dt, p)) a.done = true;
            tailFlick(a, dt, p);
            break;
        case "sit":
            p.bob = -18 * ease(t / 0.5);
            p.stretchY = -0.03 * bump(t / 0.5);
            p.breath = 0.5 - 0.5 * Math.cos(2 * Math.PI * clock / 4);
            if (t > 0.35) p.legSwing = 0;
            if (t > 0.6) tailFlick(a, dt, p);
            if (a.o.dur && t > a.o.dur) { a.done = true; }
            break;
        case "preenBreast": {
            // curl the neck down in front of the breast, crown forward, bill working into the breast feathers
            const nib = Math.sin(t * 2 * Math.PI * 5);
            if (t < 0.55) { const u = ease(t / 0.55); p.headAngle = 104 * u; p.headX = -12 * u; p.headY = 6 * u; p.rock = 4 * u; }
            else if (t < 3.2) { p.headAngle = 104 + 6 * nib; p.headX = -12 + 3 * Math.sin(t * 7); p.headY = 6 + 2 * nib; p.rock = 4; p.eyesClosed = 1; }
            else if (t < 3.7) { const u = ease((t - 3.2) / 0.5); p.headAngle = 104 * (1 - u); p.headX = -12 * (1 - u); p.headY = 6 * (1 - u); p.rock = 4 * (1 - u); }
            else if (t < 4.4) wag(p, t - 3.7, 22);
            else a.done = true;
            break;
        }
        case "preenWing": {
            // turn the head back over the shoulder and work the bill through the folded wing, then face front and wag
            const nib = Math.sin(t * 2 * Math.PI * 5);
            a.flip = t > 0.32 && t < 3.45;
            if (t < 0.32) { const u = ease(t / 0.32); p.headAngle = -24 * u; p.headY = -4 * u; }                 // start to turn
            else if (t < 0.8) { const u = ease((t - 0.32) / 0.48); p.headAngle = -24 - 22 * u; p.headX = -8 * u; p.headY = -4 + 4 * u; }
            else if (t < 3.0) { p.headAngle = -46 + 5 * nib; p.headX = -8 + 2 * Math.sin(t * 6); p.headY = 2 * Math.sin(t * 4); p.eyesClosed = 1; }
            else if (t < 3.45) { const u = ease((t - 3.0) / 0.45); p.headAngle = -46 + 22 * u; p.headX = -8 * (1 - u); }
            else if (t < 3.8) { const u = ease((t - 3.45) / 0.35); p.headAngle = -24 * (1 - u); }                     // face front again
            else if (t < 4.6) wag(p, t - 3.8, 22);
            else a.done = true;
            break;
        }
        case "peck": {
            // one or two quick pecks at the ground in front
            if (!a.o.times) a.o.times = 1 + Math.floor(Math.random() * 2);
            const n = a.o.times, per = 0.42, u = t / per, i = Math.floor(u), f = u - i;
            if (i >= n) { a.done = true; break; }
            const down = f < 0.45 ? ease(f / 0.45) : 1 - ease((f - 0.45) / 0.55);
            p.rock = 10 * Math.min(1, t / 0.2);
            p.headAngle = 62 * down + 8;
            p.headX = 10 * down;
            p.headY = 44 * down;
            break;
        }
        case "peckAt":
            if (reach(a, a.o.x, a.o.y, dt, p)) a.done = true;
            a.wings = !!a.jumpWings;
            break;
        case "peckAround": {
            // pecks at whatever is about: the floor near and far, an edge or side of a window, the air, something up
            // high it has to jump for; a few in a row
            if (!a.queue) a.queue = pickTargets(a.o.count || 3 + Math.floor(Math.random() * 3));
            if (!a.cur) { if (!a.queue.length) { a.done = true; break; } a.cur = Object.assign({ t: 0 }, a.queue.shift()); }
            a.cur.t += dt;
            if (reach(a.cur, a.cur.x, a.cur.y, dt, p)) a.cur = null;
            a.wings = a.cur ? !!a.cur.jumpWings : false;
            break;
        }
        case "petted":
            p.eyesClosed = 1;
            p.headAngle = -14 + 3 * Math.sin(t * 5);
            p.headY = 4;
            p.rock = -3 + 2 * Math.sin(t * 2.4);
            wag(p, (t % 1.6), 9);
            if (a.o.dur && t > a.o.dur) a.done = true;
            break;
        case "held": {
            // hanging from the hand: long and floppy. It follows the hand on a soft spring (a little behind, a little
            // past when the hand stops), and the head and legs swing with how fast it goes
            if (a.tx !== undefined && !inPlace) {
                const K = 150, C = 17;
                a.vx = (a.vx || 0) + ((a.tx - px) * K - (a.vx || 0) * C) * dt;
                a.vy = (a.vy || 0) + ((a.ty - py) * K - (a.vy || 0) * C) * dt;
                px += a.vx * dt;
                py += a.vy * dt;
            }
            const sw = Math.max(-1, Math.min(1, (a.vx || 0) / 900));
            p.stretchY = 0.2 + 0.04 * Math.sin(t * 7) * Math.exp(-t * 2);
            p.headAngle = 38 - 30 * sw;
            p.headY = 14;
            p.rock = -6 - 14 * sw;
            p.legSwing = 6 + 30 * sw;
            p.farLegSwing = 0 + 24 * sw;
            p.tailWag = -8 * sw;
            break;
        }
        case "drop": {
            // flapping hard, falling slowly onto the floor below
            // a throw carries on sideways (and a little upward), slowing down; it faces where it drifts
            if (a.sx === undefined) { a.sx = Math.max(-1600, Math.min(1600, a.o.vx || 0)); a.up = Math.min(0, Math.max(-900, a.o.vy || 0)); }
            if (Math.abs(a.sx) > 4) {
                const lo = Math.min(...floors.map(f => f.x1)) + 0.3 * size, hi = Math.max(...floors.map(f => f.x2)) - 0.3 * size;
                px = Math.max(lo, Math.min(hi, px + a.sx * dt));
                if (px <= lo || px >= hi) a.sx = 0;
                a.sx *= Math.exp(-1.6 * dt);
                if (Math.abs(a.sx) > 80) facing = a.sx > 0 ? 1 : -1;
            }
            py += a.up * dt;
            a.up *= Math.exp(-5 * dt);
            const fy = floorBelow(px, py);
            // slow motion, but a long fall (from the top of the screen) still lands within about three seconds
            if (a.vy === undefined) a.vy = Math.max(0.5 * size, (fy - py) / 2.8);
            py = Math.min(fy, py + a.vy * dt);
            a.wings = true;
            p.flap = 26 + 34 * Math.sin(t * 2 * Math.PI * 4.5);
            p.legSwing = 12; p.farLegSwing = 6;
            p.headAngle = -8; p.tailWag = 8 * Math.sin(t * 9);
            p.rock = -4 + 3 * Math.sin(t * 3);
            p.shadow = false;
            if (py >= fy) { a.landT = (a.landT || 0) + dt; a.wings = false; p.stretchY = -0.12 * bump(a.landT / 0.3); p.flap = 0; p.legSwing = 0; p.farLegSwing = 0;
                if (a.landT > 0.35) a.done = true; }
            break;
        }
        case "stretch": {
            // rise up as tall as it goes (body upright, neck long, slim, legs still straight down), lift both wings
            // high over the back and shake them, settle, wag
            if (t < 0.8) { const u = ease(t / 0.8); p.rock = -26 * u; p.stretchY = 0.17 * u; p.headY = -28 * u; p.headAngle = 24 * u;
                p.bob = 4 * u; p.legSwing = 26 * u; p.farLegSwing = 26 * u; }
            else if (t < 2.5) { const u = t - 0.8; a.wings = true;
                p.rock = -26 + 1.2 * Math.sin(u * 30); p.stretchY = 0.17; p.headY = -28; p.headAngle = 24; p.bob = 4;
                p.legSwing = 26; p.farLegSwing = 26;
                p.flap = -40 * ease(u / 0.3) + 9 * Math.sin(u * 2 * Math.PI * 9) * ease(u / 0.3); p.tailWag = 4 * Math.sin(u * 40); }
            else if (t < 3.1) { const u = ease((t - 2.5) / 0.6); a.wings = u < 0.55; p.flap = -40 * (1 - u);
                p.rock = -26 * (1 - u); p.stretchY = 0.17 * (1 - u) - 0.05 * bump(u); p.headY = -28 * (1 - u); p.headAngle = 24 * (1 - u);
                p.bob = 4 * (1 - u); p.legSwing = 26 * (1 - u); p.farLegSwing = 26 * (1 - u); }
            else if (t < 3.9) wag(p, t - 3.1, 22);
            else a.done = true;
            break;
        }
        case "dive": {
            // on water: tip forward until the head is under and the tail is up, paddle, then pop back up
            const paddle = Math.sin(t * 2 * Math.PI * 2.2);
            if (t < 0.6) { const u = ease(t / 0.6); p.rock = 96 * u; p.bob = 12 * u; }
            else if (t < 2.0) { a.legsUp = true; p.rock = 96 + 4 * paddle; p.bob = 12; p.legSwing = 22 * paddle; p.farLegSwing = -22 * paddle; }
            else if (t < 2.6) { a.legsUp = t < 2.25; const u = ease((t - 2.0) / 0.6); p.rock = 96 - 101 * u; p.bob = 12 * (1 - u); }
            else if (t < 3.0) { p.rock = -5 * (1 - ease((t - 2.6) / 0.4)); }
            else if (t < 3.7) wag(p, t - 3.0, 22);
            else a.done = true;
            break;
        }
        case "quack": {
            const u = t / 0.32;
            p.headAngle = -10 * Math.min(1, t / 0.12);
            p.headY = -3;
            p.jawOpen = u < 1 ? 22 * bump(u) : u < 2 ? 18 * bump(u - 1) : 0;
            if (t > 0.8) a.done = true;
            break;
        }
        }
        if (swimming && a.name !== "dive") p.bob = (p.bob || 0) + 1.6 * Math.sin(clock * 2.1);
        // the rig follows: wings open only while an action spreads them
        rig.wingsOpen = !!a.wings;
        rig.headFlip = !!a.flip;
        rig.shadowVisible = p.shadow !== false && (a.name !== "held");
        rig.legsVisible = !(a.name === "sit" && a.t > 0.35) && (!swimming || !!a.legsUp);
        if (swimming) rig.shadowVisible = false;
        return p;
    }
    // a waddling step toward tx along the floor it stands on (never off its ends); true once there
    function walkTo(a, tx, dt, p) {
        const f = floorUnder(), margin = 0.35 * size;
        if (f) tx = Math.max(f.x1 + margin, Math.min(f.x2 - margin, tx));
        if (Math.abs(tx - px) < 2) return true;
        const dir = tx > px ? 1 : -1;
        facing = dir;
        const stepPx = Math.min(0.55 * size * dt, Math.abs(tx - px));   // about half its height a second
        px += dir * stepPx;
        steps(a, stepPx, p);
        return false;
    }
    // the waddle for `dist` px of walking
    function steps(a, dist, p) {
        a.phase = (a.phase || 0) + dist / (0.26 * size) * Math.PI;
        p.legSwing = 22 * Math.sin(a.phase);
        p.farLegSwing = -p.legSwing;
        p.rock = 4 * Math.sin(a.phase);
        p.bob = 3 * Math.abs(Math.sin(a.phase));
        p.headY = 2 * Math.sin(a.phase * 2);
        p.tailWag = 5 * Math.sin(a.phase);
        return false;
    }
    function sayQuack() { quacked(); bubble.restart(); }

    // the duck's state, to hand it to another DuckActor (the desktop pet's duck into the editor's) and take it back
    function snapshot() {
        const pose = {};
        for (const key in rest) pose[key] = rig[key];
        return { act: act ? { name: act.name, t: act.t, o: Object.assign({}, act.o), phase: act.phase || 0, flickT: act.flickT } : null,
                 pose: pose, facing: facing, wings: rig.wingsOpen, flip: rig.headFlip, eyes: rig.eyesClosed, legs: rig.legsVisible,
                 clock: clock };
    }
    function restore(snap) {
        if (!snap) return;
        for (const key in snap.pose) rig[key] = snap.pose[key];
        rig.wingsOpen = snap.wings; rig.headFlip = snap.flip; rig.eyesClosed = snap.eyes; rig.legsVisible = snap.legs;
        facing = snap.facing;
        clock = snap.clock;
        act = snap.act ? Object.assign({ done: false }, snap.act) : null;
    }

    // a tail wag: the tuft alone swings, quick and wide, while the body keeps still
    function wag(p, u, amp) {
        p.tailWag = amp * Math.sin(u * 2 * Math.PI * 5) * Math.max(0, 1 - u / 0.9);
    }
    // now and then, while sitting or walking, the tail wags by itself
    function tailFlick(a, dt, p) {
        if (a.flickT === undefined) { if (Math.random() < 0.3 * dt) a.flickT = 0; return; }
        a.flickT += dt;
        if (a.flickT > 0.9) { a.flickT = undefined; return; }
        p.tailWag = 24 * Math.sin(a.flickT * 2 * Math.PI * 5) * (1 - a.flickT / 0.9);
    }

    // go to (tx, ty) and get it with the bill; state lives in `a`; true when finished
    function reach(a, tx, ty, dt, p) {
        if (!a.stage) a.stage = "go";
        if (a.stage === "go") {
            // stop where the bill reaches it, on the side it came from
            if (a.side === undefined) a.side = inPlace ? facing : tx >= px ? 1 : -1;
            if (!inPlace && !walkTo(a, tx - a.side * 0.62 * size, dt, p)) return false;
            facing = a.side;
            const headTop = py - size, reachLow = py - 0.25 * size;
            a.rise = py - ty;
            a.stage = ty > reachLow ? "low" : ty > headTop - 0.15 * size ? "mid" : ty > py - 2.1 * size ? "jump" : "look";
            a.t0 = a.t;
        }
        const s = a.t - a.t0;
        if (a.stage === "low") {                 // down to the floor
            const d = bump(s / 0.45); p.rock = 10 * d; p.headAngle = 70 * d; p.headX = 10 * d; p.headY = 44 * d;
            p.jawOpen = s > 0.18 && s < 0.26 ? 12 : 0;
            return s > 0.75;
        }
        if (a.stage === "mid") {                 // a stab straight ahead (a window's side, the air)
            const d = bump(s / 0.4); p.headAngle = 14 * d; p.headX = 34 * d; p.headY = -6 * d; p.jawOpen = s > 0.18 && s < 0.3 ? 20 : 0;
            return s > 0.7;
        }
        if (a.stage === "jump") {                // crouch, spring up with a beat of the wings, snap, land
            const h = Math.max(0, a.rise - 0.85 * size);
            a.jumpWings = s >= 0.3 && s < 0.86;
            if (s < 0.28) { p.stretchY = -0.14 * ease(s / 0.28); p.bob = -6 * ease(s / 0.28); p.headAngle = 8; }
            else if (s < 0.88) { const u = (s - 0.28) / 0.6;
                p.bob = h / k * 4 * u * (1 - u); p.stretchY = 0.1 * (1 - u); p.headAngle = -26; p.headY = -12;
                p.flap = 30 + 25 * Math.sin(s * 40); p.legSwing = 16; p.farLegSwing = 10;
                p.jawOpen = u > 0.42 && u < 0.6 ? 26 : 0; }
            else if (s < 1.15) p.stretchY = -0.1 * bump((s - 0.88) / 0.27);
            return s >= 1.15;
        }
        // out of reach: look up at it and quack
        const d = Math.min(1, s / 0.4); p.headAngle = -28 * d; p.headY = -6 * d;
        if (s > 0.6 && !a.q) { a.q = true; sayQuack(); }
        p.jawOpen = s > 0.6 && s < 0.85 ? 22 * bump((s - 0.6) / 0.25) : 0;
        return s > 1.6;
    }

    // things to peck: the floor in front (near or a little way off), a bit of a window's edge or side within a few
    // steps (`spots`: [{x1, y1, x2, y2}] lines the parent says can be pecked), the air in front, now and then
    // something up high to jump for
    property var spots: []
    function pickTargets(n) {
        const out = [];
        let x = px, dir = facing;
        for (let i = 0; i < n; i++) {
            const r = Math.random();
            if (Math.random() < 0.3) dir = -dir;
            const near = spots.filter(sp => Math.min(Math.abs(sp.x1 - x), Math.abs(sp.x2 - x)) < 3 * size);
            if (r < 0.45) out.push({ x: x + dir * rnd(0.7, 1.6) * size, y: py });
            else if (r < 0.7 && near.length) { const sp = near[Math.floor(Math.random() * near.length)], u = Math.random();
                out.push({ x: sp.x1 + (sp.x2 - sp.x1) * u, y: sp.y1 + (sp.y2 - sp.y1) * u }); }
            else if (r < 0.88) out.push({ x: x + dir * rnd(0.8, 1.2) * size, y: py - rnd(0.6, 0.9) * size });
            else out.push({ x: x + dir * rnd(0.9, 1.2) * size, y: py - rnd(1.3, 1.8) * size });
            if (inPlace) out[out.length - 1].x = px + dir * 0.62 * size;
            else x = out[out.length - 1].x - dir * 0.62 * size;
        }
        return out;
    }

    // what to do next when the action ends (random mode picks; otherwise stand)
    function next() {
        if (!random) { play("idle"); return; }
        const r = Math.random(), f = floorUnder();
        if (swimming) {
            if (r < 0.4) play("idle", { dur: rnd(2.5, 6) });
            else if (r < 0.62) play("dive");
            else if (r < 0.74) play("preenBreast");
            else if (r < 0.84) play("preenWing");
            else if (r < 0.92 || !quackInRandom) play("walk", { dur: rnd(1.5, 3) });
            else play("quack");
            return;
        }
        if (r < 0.34 && f) play("walk", inPlace ? { dur: rnd(1.5, 3) } : { x: rnd(f.x1, f.x2) });
        else if (r < 0.56) play("idle", { dur: rnd(2.5, 6) });
        else if (r < 0.64) play("sit", { dur: rnd(6, 12) });
        else if (r < 0.69) play("preenBreast");
        else if (r < 0.74) play("preenWing");
        else if (r < 0.86) play("peckAround");
        else if (r < 0.92 || !quackInRandom) play("stretch");
        else play("quack");
    }

    function tick(dt) {
            if (actor.frozen) return;
            actor.clock += dt;
            if (!actor.act) actor.play("idle");
            actor.act.t += dt;
            const p = actor.step(dt);
            // ease every pose value toward its target; quick ones (flaps, steps, bill) follow closely
            for (const key in actor.rest) {
                const rate = actor.fast[key] ? 40 : 12;
                const target = p[key] !== undefined ? p[key] : 0;
                rig[key] += (target - rig[key]) * (1 - Math.exp(-rate * dt));
            }
            rig.eyesClosed = p.eyesClosed;
            // its floor went away (a window closed or moved): it drops to whatever is below
            if (actor.floors.length && actor.act.name !== "held" && actor.act.name !== "drop" && !actor.floorUnder())
                actor.play("drop");
            if (actor.act.done) actor.next();
            actor.updateCalm();
    }
    FrameAnimation {
        running: actor.visible && !actor.calm && !actor.frozen
        onTriggered: actor.tick(Math.min(frameTime, 0.05))
    }
    Timer {
        interval: 66; repeat: true
        running: actor.visible && actor.calm && !actor.frozen
        onTriggered: actor.tick(0.066)
    }

    // where it can be clicked (the pet's window takes input only here): the head, the body, the pencil
    readonly property Item headBox: headHit
    readonly property Item bodyBox: bodyHit
    readonly property Item pencilBox: pencilHit
    // a button is held on the duck (carrying, petting): the pet's window then takes the whole screen, so the hand
    // cannot slip off while the duck trails it
    readonly property bool handled: hand.pressed
    Item { id: pencilHit; x: pencil.x; y: pencil.y; width: pencil.shown ? pencil.width : 0; height: width }
    Item {
        id: headHit
        readonly property point h: actor.headPoint()
        width: 92 * actor.k; height: width
        x: h.x - actor.x - width / 2; y: h.y - actor.y - height / 2
    }
    Item {
        id: bodyHit
        width: 230 * actor.k; height: 160 * actor.k
        x: (actor.facing > 0 ? 85 : 2 * 194 - 85 - 230) * actor.k
        y: 116 * actor.k + actor.sink
    }

    // ---------- the drawing ----------
    // on water the duck sits lower and everything under the surface (py) is cut away
    readonly property real sink: swimming ? 26 * k : 0
    Item {
        id: waterClip
        // wider than the duck, so a head reaching out while it tips over is not cut at the sides
        x: -120 * actor.k
        width: actor.width + 240 * actor.k
        height: actor.swimming ? 276 * actor.k : actor.height
        // drawn into a texture of this size while swimming: plain clipping let the turning parts (head, legs) through
        // when it dives
        clip: actor.swimming
        layer.enabled: actor.swimming
        layer.smooth: true
        DuckRig {
            id: rig
            x: 120 * actor.k
            width: actor.width
            height: actor.height
            y: actor.sink
            colour: actor.colour
            transform: Scale { origin.x: 194 * actor.k; xScale: actor.facing }
        }
    }


    // "Quack" rising from the bill
    Text {
        id: word
        property real u: 1
        x: actor.width / 2 + actor.facing * 110 * actor.k - width / 2
        y: (40 - 50 * u) * actor.k
        rotation: -8 * actor.facing
        text: "Quack"
        color: "#c3c8d0"
        opacity: u < 1 ? Math.min(1, u / 0.15, (1 - u) / 0.35) * 0.95 : 0
        font { family: actor.labelFont; pixelSize: Math.max(11, 30 * actor.k); bold: true; italic: true }
        NumberAnimation on u { id: bubble; running: false; from: 0; to: 1; duration: 1300 }
    }

    // the pencil a right-click shows for a while
    Rectangle {
        id: pencil
        property bool shown: false
        width: Math.max(28, 46 * actor.k); height: width; radius: width / 2
        x: actor.width / 2 - actor.facing * 150 * actor.k - width / 2
        y: 20 * actor.k
        color: "#f4f2ec"
        border.color: "#c3c8d0"
        scale: shown ? 1 : 0
        opacity: shown ? 1 : 0
        Behavior on scale { NumberAnimation { duration: 260; easing.type: Easing.OutBack } }
        Behavior on opacity { NumberAnimation { duration: 180 } }
        Text { anchors.centerIn: parent; text: "\u{F03EB}"; font.family: "Symbols Nerd Font Mono"; font.pixelSize: parent.width * 0.5; color: "#4a3a32" }
        Timer { id: pencilHide; interval: 3000; onTriggered: pencil.shown = false }
        MouseArea { anchors.fill: parent; enabled: pencil.shown; cursorShape: Qt.PointingHandCursor; onClicked: { pencil.shown = false; actor.pencilClicked(); } }
    }

    // ---------- the hand: pet the head, carry the body, right-click for the pencil ----------
    MouseArea {
        id: hand
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property bool carrying: false
        property point grab
        function onHead(mx, my) {
            const hp = actor.headPoint();
            return Math.hypot(mx + actor.x - hp.x, my + actor.y - hp.y) < 44 * actor.k;
        }
        function onBody(mx, my) {
            let dx = mx / actor.k, dy = my / actor.k;
            if (actor.facing < 0) dx = 2 * 194 - dx;
            return Math.pow((dx - 200) / 112, 2) + Math.pow((dy - 196) / 78, 2) < 1;
        }
        onPressed: (m) => {
            const head = onHead(m.x, m.y);
            if (!head && !onBody(m.x, m.y)) { m.accepted = false; return; }
            if (m.button === Qt.RightButton) { pencil.shown = true; pencilHide.restart(); return; }
            if (head) { actor.play("petted"); carrying = false; return; }
            carrying = true;
            if (actor.inPlace) actor.py -= 0.3 * actor.size;     // in place: lifted a little, not carried around
            grab = Qt.point(m.x + actor.x - actor.px, m.y + actor.y - actor.py);
            actor.play("held");
        }
        onPositionChanged: (m) => {
            if (!carrying || actor.inPlace) return;
            const gx = m.x + actor.x, gy = m.y + actor.y;
            actor.act.tx = gx - grab.x;
            actor.act.ty = gy - grab.y;
        }
        onReleased: (m) => { if (m.button !== Qt.RightButton) letGo(); }
        // the press was taken away (not let go): it ends the same way, so the duck never stays hanging in the air
        onCanceled: letGo()
        function letGo() {
            if (carrying) {
                carrying = false;
                const fy = actor.floorBelow(actor.px, actor.py - 1);
                const throwX = actor.act.vx || 0, throwY = actor.act.vy || 0;
                if (fy - actor.py > 6 && fy !== Infinity) actor.play("drop", { vx: throwX, vy: throwY });
                else { if (fy !== Infinity) actor.py = fy; actor.play("idle"); }
            } else if (actor.act && actor.act.name === "petted") actor.play("idle");
        }
    }
}
