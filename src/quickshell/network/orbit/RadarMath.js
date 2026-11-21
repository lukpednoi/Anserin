.pragma library

function clamp(v, lo, hi) {
    return Math.max(lo, Math.min(hi, v));
}

function smoothK(dt, tau) {
    return tau > 0.0001 ? (1.0 - Math.exp(-dt / tau)) : 1.0;
}

function easeOutCubic(t) {
    const c = clamp(t, 0.0, 1.0);
    return 1.0 - Math.pow(1.0 - c, 3);
}

function easeOutBack(t) {
    const c = clamp(t, 0.0, 1.0);
    const c1 = 1.70158;
    const c3 = c1 + 1;
    return 1 + c3 * Math.pow(c - 1, 3) + c1 * Math.pow(c - 1, 2);
}

function easeInCubic(t) {
    const c = clamp(t, 0.0, 1.0);
    return c * c * c;
}

function strokeSmoothCurve(ctx, pts) {
    if (!pts || pts.length < 2) return;
    ctx.beginPath();
    ctx.moveTo(pts[0].x, pts[0].y);
    for (let k = 1; k < pts.length - 1; k++) {
        const mx = (pts[k].x + pts[k + 1].x) * 0.5;
        const my = (pts[k].y + pts[k + 1].y) * 0.5;
        ctx.quadraticCurveTo(pts[k].x, pts[k].y, mx, my);
    }
    const last = pts[pts.length - 1];
    ctx.lineTo(last.x, last.y);
}

function slicePolylineByLen(pathObj, drawLen) {
    const pts = pathObj.pts;
    const cum = pathObj.cum;
    if (!pts || pts.length < 2 || drawLen <= 0.5) return [];
    const segPts = [pts[0]];
    for (let p = 1; p < pts.length; p++) {
        if (cum[p] <= drawLen) {
            segPts.push(pts[p]);
        } else {
            const span = Math.max(0.001, cum[p] - cum[p - 1]);
            const localU = clamp((drawLen - cum[p - 1]) / span, 0.0, 1.0);
            segPts.push({
                x: pts[p - 1].x + (pts[p].x - pts[p - 1].x) * localU,
                y: pts[p - 1].y + (pts[p].y - pts[p - 1].y) * localU
            });
            break;
        }
    }
    return segPts;
}

/**
 * Potential-field + Laplacian obstacle-avoiding spline from (x0, y0) to (x1, y1),
 * trimmed cleanly at the start circle boundary (hostR) and end node boundary.
 *
 * @param {object} opts Optional settings: { hostR, minY, maxY, circleMode, hoveredUid, archUp }
 */
function buildSmoothAvoidancePath(x0, y0, x1, y1, nodes, targetUid, opts) {
    const cfg = opts || {};
    const hostR = cfg.hostR !== undefined ? cfg.hostR : 22.0;
    const clampY = cfg.minY !== undefined && cfg.maxY !== undefined;
    const circleMode = !!cfg.circleMode;
    const hoveredUid = cfg.hoveredUid || "";
    const archUp = !!cfg.archUp;

    const N = 28;
    const dxLine = x1 - x0;
    const dyLine = y1 - y0;
    const lineLen = Math.max(1.0, Math.hypot(dxLine, dyLine));
    const ux = dxLine / lineLen;
    const uy = dyLine / lineLen;
    const px = -uy;
    const py = ux;

    const pts = [];
    const restPts = [];
    const liftY = archUp ? clamp(lineLen * 0.28, 30.0, 78.0) : 0.0;
    const horizFrac = Math.abs(ux);
    const vertFactor = archUp ? Math.max(0.0, 1.0 - horizFrac / 0.45) : 0.0;
    const bowDir = dxLine >= 0 ? 1.0 : -1.0;

    for (let i = 0; i <= N; i++) {
        const t = i / N;
        let rx = x0 + dxLine * t;
        let ry = y0 + dyLine * t;
        if (archUp) {
            const s = Math.sin(t * Math.PI);
            rx += bowDir * vertFactor * liftY * 0.65 * s;
            ry -= (0.55 + 0.45 * horizFrac) * liftY * s;
        }
        pts.push({ x: rx, y: ry });
        restPts.push({ x: rx, y: ry });
    }

    let targetNode = null;
    const obs = [];
    for (let i = 0; i < nodes.length; i++) {
        const n = nodes[i];
        if (n.uid === targetUid) {
            targetNode = n;
            continue;
        }
        if (n.removing || n.appear < 0.25) continue;

        const useCircle = circleMode && n.uid !== hoveredUid;
        const rx = useCircle ? ((n.iconR || 19.0) + 16.0) : (n.w * 0.56 + 18.0);
        const ry = useCircle ? ((n.iconR || 19.0) + 16.0) : (n.baseH * 0.62 + 16.0);
        const cross = dxLine * (n.y - y0) - dyLine * (n.x - x0);
        let side = cross >= 0 ? -1.0 : 1.0;
        if (clampY && n.y + side * py * ry < cfg.minY + 2.0) side = -side;
        obs.push({ cx: n.x, cy: n.y, rx: rx, ry: ry, side: side });
    }

    if (obs.length > 0) {
        for (let iter = 0; iter < 18; iter++) {
            for (let k = 1; k < N; k++) {
                const p = pts[k];
                for (let o = 0; o < obs.length; o++) {
                    const ob = obs[o];
                    const vx = p.x - ob.cx;
                    const vy = p.y - ob.cy;
                    const ex = vx / ob.rx;
                    const ey = vy / ob.ry;
                    const ell = Math.hypot(ex, ey);
                    if (ell < 1.08) {
                        const pen = 1.08 - ell;
                        const radLen = Math.max(0.001, Math.hypot(vx, vy));
                        const rux = vx / radLen;
                        const ruy = vy / radLen;
                        const dirX = ob.side * px * 0.72 + rux * 0.28;
                        const dirY = ob.side * py * 0.72 + ruy * 0.28;
                        const dirNorm = Math.max(0.001, Math.hypot(dirX, dirY));
                        const push = pen * 22.0;
                        p.x += (dirX / dirNorm) * push;
                        p.y += (dirY / dirNorm) * push;
                    }
                }
            }

            const smoothPasses = (iter === 17) ? 1 : 2;
            const wEdge = (iter === 17) ? 0.18 : 0.27;
            const wMid = 1.0 - 2.0 * wEdge;
            for (let sp = 0; sp < smoothPasses; sp++) {
                const devX = new Array(N + 1);
                const devY = new Array(N + 1);
                for (let k = 0; k <= N; k++) {
                    devX[k] = pts[k].x - restPts[k].x;
                    devY[k] = pts[k].y - restPts[k].y;
                }
                for (let k = 1; k < N; k++) {
                    pts[k].x = restPts[k].x + wEdge * devX[k - 1] + wMid * devX[k] + wEdge * devX[k + 1];
                    pts[k].y = restPts[k].y + wEdge * devY[k - 1] + wMid * devY[k] + wEdge * devY[k + 1];
                    if (clampY) {
                        pts[k].y = clamp(pts[k].y, cfg.minY, cfg.maxY);
                    }
                }
            }
        }
    } else if (!archUp) {
        const lift = Math.min(18.0, lineLen * 0.055);
        const dir = py <= 0 ? 1.0 : -1.0;
        for (let k = 1; k < N; k++) {
            const t = k / N;
            const s = Math.sin(t * Math.PI);
            pts[k].x += px * dir * s * lift * 0.55;
            pts[k].y += py * dir * s * lift * 0.55 - s * lift * 0.35;
        }
    }

    // Trim polyline start at Host outer border (hostR)
    let trimmed = pts;
    for (let k = 0; k < trimmed.length - 1; k++) {
        const p0 = trimmed[k];
        const p1 = trimmed[k + 1];
        if (Math.hypot(p1.x - x0, p1.y - y0) >= hostR) {
            let lo = 0.0;
            let hi = 1.0;
            for (let b = 0; b < 10; b++) {
                const mid = (lo + hi) * 0.5;
                const mx = p0.x + (p1.x - p0.x) * mid;
                const my = p0.y + (p1.y - p0.y) * mid;
                if (Math.hypot(mx - x0, my - y0) < hostR) lo = mid;
                else hi = mid;
            }
            const tEdge = (lo + hi) * 0.5;
            const startEdge = {
                x: p0.x + (p1.x - p0.x) * tEdge,
                y: p0.y + (p1.y - p0.y) * tEdge
            };
            trimmed = [startEdge].concat(trimmed.slice(k + 1));
            break;
        }
    }

    // Trim polyline end cleanly at Target node border (circle or rounded pill)
    if (targetNode && trimmed.length >= 2) {
        const targetIsCircle = circleMode && targetNode.uid !== hoveredUid;
        const hw = targetNode.w * 0.5;
        const hh = targetNode.baseH * 0.5;
        const rCor = Math.min(12.0, hw, hh);
        const cRad = targetNode.iconR || 19.0;

        const insideTarget = function(pxPt, pyPt) {
            if (targetIsCircle) {
                return Math.hypot(pxPt - targetNode.x, pyPt - targetNode.y) <= cRad;
            }
            const ax = Math.abs(pxPt - targetNode.x);
            const ay = Math.abs(pyPt - targetNode.y);
            if (ax > hw || ay > hh) return false;
            if (ax <= hw - rCor || ay <= hh - rCor) return true;
            return Math.hypot(ax - (hw - rCor), ay - (hh - rCor)) <= rCor;
        };

        for (let k = trimmed.length - 2; k >= 0; k--) {
            const pOut = trimmed[k];
            const pIn = trimmed[k + 1];
            if (!insideTarget(pOut.x, pOut.y)) {
                let lo = 0.0;
                let hi = 1.0;
                for (let b = 0; b < 12; b++) {
                    const mid = (lo + hi) * 0.5;
                    const mx = pOut.x + (pIn.x - pOut.x) * mid;
                    const my = pOut.y + (pIn.y - pOut.y) * mid;
                    if (insideTarget(mx, my)) hi = mid;
                    else lo = mid;
                }
                const tCut = (lo + hi) * 0.5;
                const endEdge = {
                    x: pOut.x + (pIn.x - pOut.x) * tCut,
                    y: pOut.y + (pIn.y - pOut.y) * tCut
                };
                trimmed = trimmed.slice(0, k + 1);
                trimmed.push(endEdge);
                break;
            }
        }
    }

    const cum = [0.0];
    let totalLen = 0.0;
    for (let i = 1; i < trimmed.length; i++) {
        totalLen += Math.hypot(trimmed[i].x - trimmed[i - 1].x, trimmed[i].y - trimmed[i - 1].y);
        cum.push(totalLen);
    }
    return { pts: trimmed, cum: cum, totalLen: totalLen };
}

/**
 * Converts a polyline into an SVG quadratic-smoothed path string ("M ... Q ... L ...")
 * for GPU QtQuick.Shapes PathSvg rendering with zero per-frame CPU rasterization.
 */
function pointsToSmoothSvgPath(pts, ox, oy) {
    if (!pts || pts.length < 2) return "";
    const dx = ox || 0.0;
    const dy = oy || 0.0;
    let d = "M " + (pts[0].x + dx).toFixed(1) + " " + (pts[0].y + dy).toFixed(1);
    for (let k = 1; k < pts.length - 1; k++) {
        const mx = (pts[k].x + pts[k + 1].x) * 0.5 + dx;
        const my = (pts[k].y + pts[k + 1].y) * 0.5 + dy;
        d += " Q " + (pts[k].x + dx).toFixed(1) + " " + (pts[k].y + dy).toFixed(1) + " " + mx.toFixed(1) + " " + my.toFixed(1);
    }
    const last = pts[pts.length - 1];
    d += " L " + (last.x + dx).toFixed(1) + " " + (last.y + dy).toFixed(1);
    return d;
}

function circleSvg(cx, cy, r) {
    if (r <= 0.5) return "";
    return "M " + (cx - r).toFixed(1) + " " + cy.toFixed(1)
        + " A " + r.toFixed(1) + " " + r.toFixed(1) + " 0 1 0 " + (cx + r).toFixed(1) + " " + cy.toFixed(1)
        + " A " + r.toFixed(1) + " " + r.toFixed(1) + " 0 1 0 " + (cx - r).toFixed(1) + " " + cy.toFixed(1) + " Z";
}

function ellipseSvg(cx, cy, rx, ry) {
    if (rx <= 0.5 || ry <= 0.5) return "";
    return "M " + (cx - rx).toFixed(1) + " " + cy.toFixed(1)
        + " A " + rx.toFixed(1) + " " + ry.toFixed(1) + " 0 1 0 " + (cx + rx).toFixed(1) + " " + cy.toFixed(1)
        + " A " + rx.toFixed(1) + " " + ry.toFixed(1) + " 0 1 0 " + (cx - rx).toFixed(1) + " " + cy.toFixed(1) + " Z";
}

function arcSvg(cx, cy, r, deg0, deg1) {
    if (r <= 0.5) return "";
    const a0 = deg0 * Math.PI / 180.0;
    const a1 = deg1 * Math.PI / 180.0;
    const largeArc = Math.abs(deg1 - deg0) > 180.0 ? 1 : 0;
    const sweep = deg1 >= deg0 ? 1 : 0;
    const x0 = cx + Math.cos(a0) * r;
    const y0 = cy + Math.sin(a0) * r;
    const x1 = cx + Math.cos(a1) * r;
    const y1 = cy + Math.sin(a1) * r;
    return "M " + x0.toFixed(1) + " " + y0.toFixed(1)
        + " A " + r.toFixed(1) + " " + r.toFixed(1) + " 0 " + largeArc + " " + sweep + " " + x1.toFixed(1) + " " + y1.toFixed(1);
}

function ellipseArcSvg(cx, cy, rx, ry, deg0, deg1) {
    if (rx <= 0.5 || ry <= 0.5) return "";
    const a0 = deg0 * Math.PI / 180.0;
    const a1 = deg1 * Math.PI / 180.0;
    const largeArc = Math.abs(deg1 - deg0) > 180.0 ? 1 : 0;
    const sweep = deg1 >= deg0 ? 1 : 0;
    const x0 = cx + Math.cos(a0) * rx;
    const y0 = cy + Math.sin(a0) * ry;
    const x1 = cx + Math.cos(a1) * rx;
    const y1 = cy + Math.sin(a1) * ry;
    return "M " + x0.toFixed(1) + " " + y0.toFixed(1)
        + " A " + rx.toFixed(1) + " " + ry.toFixed(1) + " 0 " + largeArc + " " + sweep + " " + x1.toFixed(1) + " " + y1.toFixed(1);
}

function orbitalTicksSvg(cx, cy, r, stepDeg, majorEvery, minorLen, majorLen) {
    let d = "";
    const count = Math.round(360 / stepDeg);
    for (let i = 0; i < count; i++) {
        const ang = (i * stepDeg) * Math.PI / 180.0;
        const isMaj = (majorEvery > 0) && (i % majorEvery === 0);
        const halfL = (isMaj ? majorLen : minorLen) * 0.5;
        const r0 = r - halfL;
        const r1 = r + halfL;
        d += " M " + (cx + Math.cos(ang) * r0).toFixed(1) + " " + (cy + Math.sin(ang) * r0).toFixed(1)
            + " L " + (cx + Math.cos(ang) * r1).toFixed(1) + " " + (cy + Math.sin(ang) * r1).toFixed(1);
    }
    return d;
}

function edgesToSvg(beamEdges, ox, oy, hopMin, hopMax) {
    let d = "";
    const dx = ox || 0.0;
    const dy = oy || 0.0;
    for (let i = 0; i < beamEdges.length; i++) {
        const e = beamEdges[i];
        if (e.hop < hopMin || e.hop > hopMax) continue;
        d += " M " + (e.sx + dx).toFixed(1) + " " + (e.sy + dy).toFixed(1)
            + " L " + (e.ex + dx).toFixed(1) + " " + (e.ey + dy).toFixed(1);
    }
    return d;
}

/**
 * Generates a 5-hop organic 360° triangulated network constellation extending from
 * Center Hub (0, 0) cleanly out to the outermost Ring 5 boundary (r = 505),
 * with Bellman-Ford causal timing precomputed ONCE (zero per-frame math overhead).
 */
function buildCosmicMesh(yScale) {
    const ys = (yScale !== undefined && yScale !== null) ? yScale : 1.0;
    const hopSpecs = [
        { hop: 1, count: 7,  rBase: 82.0,  rAmp: 9.0,  dotR: 3.4, rot: -0.25 },
        { hop: 2, count: 10, rBase: 156.0, rAmp: 13.0, dotR: 3.3, rot:  0.14 },
        { hop: 3, count: 13, rBase: 252.0, rAmp: 15.0, dotR: 3.0, rot: -0.09 },
        { hop: 4, count: 16, rBase: 358.0, rAmp: 16.0, dotR: 2.8, rot:  0.22 },
        { hop: 5, count: 18, rBase: 492.0, rAmp: 13.0, dotR: 2.7, rot: -0.17 } // Reaches outermost r = 505!
    ];

    const nodes = [];
    const ringIndices = [];
    for (let h = 0; h < hopSpecs.length; h++) {
        const sp = hopSpecs[h];
        const ring = [];
        for (let i = 0; i < sp.count; i++) {
            const frac = i / sp.count;
            const ang = sp.rot + frac * Math.PI * 2.0 + Math.sin(i * 2.17 + h * 1.4) * (0.34 / sp.count * Math.PI);
            const rr = sp.rBase + Math.cos(i * 1.73 + h * 2.3) * sp.rAmp;
            const rNode = (h === 4) ? Math.min(505.0, Math.max(478.0, rr)) : rr;
            ring.push(nodes.length);
            nodes.push({
                dx: Math.cos(ang) * rNode,
                dy: Math.sin(ang) * rNode * ys,
                r: sp.dotR + ((i % 3 === 0) ? 0.35 : 0.0),
                hop: sp.hop,
                ang: ang,
                arrive: 999.0
            });
        }
        ringIndices.push(ring);
    }

    const edgeSet = {};
    const radialEdges = [];
    const crossEdges = [];
    function addEdge(list, a, b) {
        const u = Math.min(a, b);
        const v = Math.max(a, b);
        const key = u + ":" + v;
        if (edgeSet[key]) return;
        edgeSet[key] = true;
        list.push([u, v]);
    }

    for (let h = 0; h < ringIndices.length; h++) {
        const ring = ringIndices[h];
        for (let i = 0; i < ring.length; i++) {
            addEdge(crossEdges, ring[i], ring[(i + 1) % ring.length]);
        }
    }

    for (let h = 0; h < ringIndices.length - 1; h++) {
        const inner = ringIndices[h];
        const outer = ringIndices[h + 1];
        for (let i = 0; i < inner.length; i++) {
            const pIdx = inner[i];
            const pn = nodes[pIdx];
            const sorted = outer.slice().sort(function(a, b) {
                const da = Math.hypot(nodes[a].dx - pn.dx, nodes[a].dy - pn.dy);
                const db = Math.hypot(nodes[b].dx - pn.dx, nodes[b].dy - pn.dy);
                return da - db;
            });
            addEdge(radialEdges, pIdx, sorted[0]);
            if (sorted.length > 1) addEdge(radialEdges, pIdx, sorted[1]);
        }
        for (let j = 0; j < outer.length; j++) {
            const cIdx = outer[j];
            const cn = nodes[cIdx];
            let bestP = inner[0];
            let bestD = 1e9;
            for (let i = 0; i < inner.length; i++) {
                const pIdx = inner[i];
                const d = Math.hypot(nodes[pIdx].dx - cn.dx, nodes[pIdx].dy - cn.dy);
                if (d < bestD) {
                    bestD = d;
                    bestP = pIdx;
                }
            }
            addEdge(radialEdges, bestP, cIdx);
        }
    }

    // Precompute Bellman-Ford arrival times once
    const waveSpeed = 860.0;
    const hubFire = 0.04;
    const spokes = [];
    for (let i = 0; i < hopSpecs[0].count; i++) {
        const angUnscaled = nodes[i].ang;
        const sx = Math.cos(angUnscaled) * 24.0;
        const sy = Math.sin(angUnscaled) * 24.0 * ys;
        const len = Math.max(12.0, Math.hypot(nodes[i].dx - sx, nodes[i].dy - sy));
        const dur = len / waveSpeed;
        nodes[i].arrive = hubFire + dur;
        const visAng = Math.atan2(nodes[i].dy - sy, nodes[i].dx - sx);
        spokes.push({
            sx: sx,
            sy: sy,
            ex: nodes[i].dx,
            ey: nodes[i].dy,
            len: len,
            angDeg: visAng * 180.0 / Math.PI,
            start: hubFire,
            dur: dur,
            str: 0.85,
            wireA: 0.14,
            hop: 1
        });
    }

    const rawEdges = [];
    for (let k = 0; k < radialEdges.length; k++) {
        const a = radialEdges[k][0], b = radialEdges[k][1];
        const len = Math.max(8.0, Math.hypot(nodes[b].dx - nodes[a].dx, nodes[b].dy - nodes[a].dy));
        rawEdges.push({ a: a, b: b, dur: len / waveSpeed, len: len, isCross: false });
    }
    for (let k = 0; k < crossEdges.length; k++) {
        const a = crossEdges[k][0], b = crossEdges[k][1];
        const len = Math.max(8.0, Math.hypot(nodes[b].dx - nodes[a].dx, nodes[b].dy - nodes[a].dy));
        rawEdges.push({ a: a, b: b, dur: len / waveSpeed, len: len, isCross: true });
    }
    for (let relax = 0; relax < 6; relax++) {
        for (let k = 0; k < rawEdges.length; k++) {
            const e = rawEdges[k];
            if (nodes[e.a].arrive + e.dur < nodes[e.b].arrive) nodes[e.b].arrive = nodes[e.a].arrive + e.dur;
            if (nodes[e.b].arrive + e.dur < nodes[e.a].arrive) nodes[e.a].arrive = nodes[e.b].arrive + e.dur;
        }
    }

    const beamEdges = spokes.slice();
    for (let k = 0; k < rawEdges.length; k++) {
        const ed = rawEdges[k];
        const srcIdx = nodes[ed.a].arrive <= nodes[ed.b].arrive ? ed.a : ed.b;
        const dstIdx = srcIdx === ed.a ? ed.b : ed.a;
        const pa = nodes[srcIdx];
        const pb = nodes[dstIdx];
        const hDst = pb.hop;
        beamEdges.push({
            sx: pa.dx,
            sy: pa.dy,
            ex: pb.dx,
            ey: pb.dy,
            len: ed.len,
            angDeg: Math.atan2(pb.dy - pa.dy, pb.dx - pa.dx) * 180.0 / Math.PI,
            start: pa.arrive,
            dur: ed.dur,
            wireA: ed.isCross ? (hDst >= 4 ? 0.055 : 0.075) : (hDst >= 4 ? 0.09 : 0.12),
            str: ed.isCross ? 0.45 : (hDst >= 4 ? 0.72 : 0.88),
            hop: hDst
        });
    }

    return {
        nodes: nodes,
        beamEdges: beamEdges
    };
}

