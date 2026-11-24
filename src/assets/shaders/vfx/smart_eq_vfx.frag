#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float time;
    float playing;        // 0..1
    float activeBand;     // -1..9 hovered/dragged band
    float dragPulse;      // 0..1
    float cascadeProgress;// -1.5..10.5 (sweeps -1.0 -> 10.0 over 650ms OutSine, matching old EQ!)
    float cascadeFade;    // 0..1 (fades over 800ms OutQuad after 150ms hold)
    float cascadeActive;  // 0 or 1
    float showGhost;      // 0..1 (silver-grey target preview line while adjusting before Save)
    vec4 accentColor;
    vec4 bands0;          // live spring mercury wave b0..b3
    vec4 bands1;          // b4..b7
    vec4 bands2;          // b8, b9, pL, pR
    vec4 target0;         // ghost target curve t0..t3
    vec4 target1;         // t4..t7
    vec4 target2;         // t8, t9, pT, pB
    vec4 start0;          // pre-impact saved wave s0..s3
    vec4 start1;          // s4..s7
    vec4 start2;          // s8, s9, rippleBand, rippleAge
};

const float PI = 3.141592653589793;

float getLiveDb(int idx) {
    int i = clamp(idx, 0, 9);
    if (i == 0) return bands0.x;
    if (i == 1) return bands0.y;
    if (i == 2) return bands0.z;
    if (i == 3) return bands0.w;
    if (i == 4) return bands1.x;
    if (i == 5) return bands1.y;
    if (i == 6) return bands1.z;
    if (i == 7) return bands1.w;
    if (i == 8) return bands2.x;
    return bands2.y;
}

float getTargetDb(int idx) {
    int i = clamp(idx, 0, 9);
    if (i == 0) return target0.x;
    if (i == 1) return target0.y;
    if (i == 2) return target0.z;
    if (i == 3) return target0.w;
    if (i == 4) return target1.x;
    if (i == 5) return target1.y;
    if (i == 6) return target1.z;
    if (i == 7) return target1.w;
    if (i == 8) return target2.x;
    return target2.y;
}

float getStartDb(int idx) {
    int i = clamp(idx, 0, 9);
    if (i == 0) return start0.x;
    if (i == 1) return start0.y;
    if (i == 2) return start0.z;
    if (i == 3) return start0.w;
    if (i == 4) return start1.x;
    if (i == 5) return start1.y;
    if (i == 6) return start1.z;
    if (i == 7) return start1.w;
    if (i == 8) return start2.x;
    return start2.y;
}

float catmullRom(float p0, float p1, float p2, float p3, float t) {
    float t2 = t * t;
    float t3 = t2 * t;
    return 0.5 * (
        (2.0 * p1) +
        (-p0 + p2) * t +
        (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 +
        (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3
    );
}

float sampleLiveDb(float u) {
    float uc = clamp(u, 0.0, 9.0);
    int i1 = int(floor(uc));
    float f = uc - float(i1);
    float baseDb = catmullRom(getLiveDb(i1 - 1), getLiveDb(i1), getLiveDb(i1 + 1), getLiveDb(i1 + 2), f);
    float breath = playing * (sin(time * 2.4 + uc * 0.85) * 0.34 + cos(time * 3.8 - uc * 1.2) * 0.17);

    // Physical ripple from impact/drag
    float rip = 0.0;
    float rBand = start2.z;
    float rAge = start2.w;
    if (rBand >= 0.0 && rAge > 0.001 && rAge < 0.999) {
        float dist = abs(uc - rBand);
        float env = exp(-dist * 0.55) * (1.0 - rAge) * (1.0 - rAge);
        rip = sin(dist * 2.3 - rAge * 13.0) * 1.45 * env;
    }
    return clamp(baseDb + breath + rip, -13.5, 13.5);
}

float sampleTargetDb(float u) {
    float uc = clamp(u, 0.0, 9.0);
    int i1 = int(floor(uc));
    float f = uc - float(i1);
    return clamp(catmullRom(getTargetDb(i1 - 1), getTargetDb(i1), getTargetDb(i1 + 1), getTargetDb(i1 + 2), f), -12.5, 12.5);
}

float calcCaustics(vec2 p, float t) {
    vec2 cp = vec2(p.x * 0.052, p.y * 0.068);
    float c1 = sin(cp.x + t * 1.65 + cos(cp.y * 1.2 - t * 1.1));
    float c2 = cos(cp.y * 1.35 - t * 1.4 + sin(cp.x * 1.1 + t * 1.25));
    float c3 = sin((cp.x + cp.y) * 0.85 - t * 1.9);
    return pow(clamp(1.0 - abs(c1 + c2 + c3) * 0.42, 0.0, 1.0), 3.0);
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;
    float pL = bands2.z;
    float pR = bands2.w;
    float pT = target2.z;
    float pB = target2.w;
    float pW = max(itemSize.x - pL - pR, 1.0);
    float pH = max(itemSize.y - pT - pB, 1.0);
    float zY = pT + pH * 0.5;
    float ampY = pH * 0.43;

    float u = ((p.x - pL) / pW) * 10.0 - 0.5;
    float inPlotX = smoothstep(pL - 6.0, pL + 2.0, p.x) * smoothstep(pL + pW + 6.0, pL + pW - 2.0, p.x);
    float inPlotY = smoothstep(pT - 10.0, pT, p.y) * smoothstep(pT + pH + 8.0, pT + pH - 2.0, p.y);

    vec3 acc = accentColor.rgb;
    vec3 deepCol = mix(vec3(0.08, 0.13, 0.20), acc * 0.46, 0.52);
    vec3 rimTint = mix(vec3(0.84, 0.94, 1.0), acc * 1.25, 0.44);
    vec3 ghostCol = mix(vec3(0.68, 0.72, 0.80), acc * 0.9, 0.22);

    vec3 col = vec3(0.0);
    float alpha = 0.0;

    // 1. Subtle 0 dB horizon hairline + vertical band guides
    float zeroLine = exp(-abs(p.y - zY) * 1.9) * 0.15 * inPlotX;
    col += mix(vec3(1.0), acc, 0.35) * zeroLine;
    alpha = max(alpha, zeroLine);

    float bandNearest = clamp(floor(u + 0.5), 0.0, 9.0);
    float bandCenterX = pL + ((bandNearest + 0.5) / 10.0) * pW;
    float isActGuide = (activeBand >= -0.5 && abs(bandNearest - activeBand) < 0.25) ? 1.0 : 0.0;
    float guideA = exp(-abs(p.x - bandCenterX) * 2.2) * (0.045 + 0.18 * isActGuide) * inPlotX * inPlotY;
    col += mix(vec3(1.0), acc, 0.5) * guideA;
    alpha = max(alpha, guideA);

    // 2. LIVE LIQUID MERCURY WAVE (smoothly knocked band-by-band during cascade!)
    float dbLive = sampleLiveDb(u);
    float curveY = zY - (dbLive / 12.0) * ampY;
    float du = 0.08;
    float yL = zY - (sampleLiveDb(u - du) / 12.0) * ampY;
    float yR = zY - (sampleLiveDb(u + du) / 12.0) * ampY;
    float slope = (yR - yL) / max((du * 2.0 / 10.0) * pW, 0.001);
    float normFactor = inversesqrt(1.0 + slope * slope);

    float meniscus = 0.0;
    for (int i = 0; i < 10; ++i) {
        float dBand = abs(u - float(i));
        meniscus += exp(-dBand * dBand * 10.0) * 1.35;
    }
    float liqY = curveY - meniscus;
    float dy = p.y - liqY;
    float inLiquid = smoothstep(-1.5, 1.5, dy) * smoothstep(pT + pH + 2.0, pT + pH - 14.0, p.y) * inPlotX;
    float depthFrac = clamp(dy / max(pT + pH - liqY, 1.0), 0.0, 1.0);
    float topFalloff = exp(-depthFrac * 2.35);
    float caust = calcCaustics(p, time);

    float actProx = (activeBand >= -0.5) ? exp(-pow((u - activeBand) * 0.80, 2.0)) * (0.4 + 0.6 * dragPulse) : 0.0;

    // Underwater caustic surge right where cascade impacts happen
    float impactCaustBoost = 0.0;
    float impactRimBoost = 0.0;
    float fadeEnv = 1.0 - cascadeFade;
    if (cascadeActive > 0.5 && fadeEnv > 0.005) {
        float swProx = exp(-pow((u - cascadeProgress) * 0.75, 2.0)) * fadeEnv;
        impactCaustBoost = swProx * 0.85;
        impactRimBoost = swProx * 0.70;
    }

    vec3 bodyCol = deepCol * (0.45 + 0.55 * topFalloff)
                 + rimTint * caust * (0.58 * topFalloff + 0.35 * actProx + impactCaustBoost);

    col += bodyCol * inLiquid * 0.90;
    alpha = max(alpha, inLiquid * clamp(0.28 + 0.50 * topFalloff + 0.25 * caust + impactCaustBoost * 0.35, 0.0, 0.96));

    float dSurf = abs(dy) * normFactor;
    float specRim = exp(-dSurf * 1.25) * (1.20 + 0.35 * actProx + impactRimBoost);
    float specBloom = exp(-dSurf * 0.28) * (0.38 + 0.30 * actProx + impactRimBoost * 0.55);
    float underShadow = smoothstep(0.0, 2.2, dy) * smoothstep(5.5, 2.2, dy) * 0.30 * inPlotX;
    col *= (1.0 - underShadow);
    col += (vec3(1.0) * specRim + rimTint * specBloom) * inPlotX;
    alpha = max(alpha, clamp((specRim + specBloom * 0.8) * inPlotX, 0.0, 1.0));

    // 3. SILVER-GREY GHOST MARKER CURVE (visible while pending OR for bands not yet impacted!)
    if (showGhost > 0.01) {
        // During cascade, hide ghost smoothly on bands that have ALREADY been struck!
        float unhitMask = (cascadeActive > 0.5) ? smoothstep(cascadeProgress - 0.15, cascadeProgress + 0.45, u) : 1.0;
        float gVis = showGhost * unhitMask * inPlotX;
        if (gVis > 0.01) {
            float tDb = sampleTargetDb(u);
            float tY = zY - (tDb / 12.0) * ampY;
            float tYL = zY - (sampleTargetDb(u - du) / 12.0) * ampY;
            float tYR = zY - (sampleTargetDb(u + du) / 12.0) * ampY;
            float tSlope = (tYR - tYL) / max((du * 2.0 / 10.0) * pW, 0.001);
            float tNorm = inversesqrt(1.0 + tSlope * tSlope);
            float dGhost = abs(p.y - tY) * tNorm;

            // Crisp refined dashed silver-grey marker line!
            float dash = smoothstep(-0.15, 0.25, sin(p.x * 0.58 - time * 1.8));
            float ghostLine = exp(-dGhost * 1.55) * (0.34 + 0.42 * dash) * gVis;
            col += ghostCol * ghostLine;
            alpha = max(alpha, clamp(ghostLine, 0.0, 0.85));
        }

        // Per-band Ghost Target Hollow Rings + Delicate Vertical Connector Lines
        for (int i = 0; i < 10; ++i) {
            float fi = float(i);
            float tDb = getTargetDb(i);
            float lDb = getLiveDb(i);
            float diff = tDb - lDb;
            float bUnhit = (cascadeActive > 0.5) ? smoothstep(cascadeProgress - 0.15, cascadeProgress + 0.35, fi) : 1.0;
            float bVis = showGhost * bUnhit;
            if (bVis > 0.02 && abs(diff) > 0.25) {
                float bx = pL + ((fi + 0.5) / 10.0) * pW;
                float ty = zY - (tDb / 12.0) * ampY;
                float ly = zY - (lDb / 12.0) * ampY;
                float isAct = (activeBand >= -0.5 && abs(fi - activeBand) < 0.25) ? 1.0 : 0.0;

                // Vertical dashed connector from old mercury orb to target marker
                float yMin = min(ty, ly) + 5.0;
                float yMax = max(ty, ly) - 5.0;
                if (yMax > yMin) {
                    float inVert = smoothstep(yMin - 1.0, yMin + 1.0, p.y) * smoothstep(yMax + 1.0, yMax - 1.0, p.y);
                    float vDash = smoothstep(-0.1, 0.3, sin(p.y * 0.75 - sign(diff) * time * 4.5));
                    float vLine = exp(-abs(p.x - bx) * 2.1) * inVert * (0.20 + 0.28 * vDash) * bVis;
                    col += ghostCol * vLine;
                    alpha = max(alpha, clamp(vLine, 0.0, 0.6));
                }

                // Crisp hollow silver-grey target marker ring
                float rT = length(p - vec2(bx, ty));
                float tRad = 4.6 + isAct * 1.4;
                float ring = exp(-abs(rT - tRad) * 1.55) * (0.68 + 0.32 * isAct) * bVis;
                float centerDot = smoothstep(2.0, 0.8, rT) * (0.32 + 0.45 * isAct) * bVis;
                vec3 mCol = mix(ghostCol, vec3(1.0), isAct * 0.55);
                col += mCol * (ring + centerDot);
                alpha = max(alpha, clamp(ring + centerDot, 0.0, 0.92));
            }
        }
    }

    // 4. PER-BAND MERCURY DROPLET BEADS + PROJECTILE BALL IMPACT (UP FROM BOTTOM / DOWN FROM TOP / STILL GLOW!)
    for (int i = 0; i < 10; ++i) {
        float fi = float(i);
        float bx = pL + ((fi + 0.5) / 10.0) * pW;
        float liveY = zY - (sampleLiveDb(fi) / 12.0) * ampY - 1.35;
        vec2 np = vec2(bx, liveY);
        vec2 dp = p - np;
        float r = length(dp);
        float isAct = (activeBand >= -0.5 && abs(fi - activeBand) < 0.25) ? 1.0 : 0.0;

        float impactFlash = 0.0;
        float haloAmp = 0.0;
        float haloRadius = 8.0;

        if (cascadeActive > 0.5 && fadeEnv > 0.005) {
            float sDb = getStartDb(i);
            float gDb = getTargetDb(i);
            float delta = gDb - sDb;
            float dir = (delta > 0.25) ? 1.0 : ((delta < -0.25) ? -1.0 : 0.0);
            float startY = zY - (sDb / 12.0) * ampY - 1.35;
            float lead = cascadeProgress - fi; // < 0 before hit, == 0 at impact, > 0 after hit

            // A. IN-FLIGHT PROJECTILE BALL (dir != 0, shooting from bottom if UP or top if DOWN!)
            float flightSpan = 1.30;
            if (dir != 0.0 && lead > -flightSpan && lead < 0.06) {
                float ft = clamp((lead + flightSpan) / flightSpan, 0.0, 1.0);
                // Smooth ballistic acceleration into impact (ease-in)
                float ease = ft * ft;
                float launchY = (dir > 0.0) ? (pT + pH + 6.0) : (pT - 10.0);
                float ballY = mix(launchY, startY, ease);
                vec2 bp = p - vec2(bx, ballY);

                // Slightly motion-stretched 3D mercury projectile orb
                vec2 stretchP = vec2(bp.x * 1.16, bp.y * 0.80);
                float br = length(stretchP);
                float ballRad = 4.5 + 1.4 * ft;
                float ballMask = smoothstep(ballRad + 0.9, max(0.4, ballRad - 0.8), br);
                float bSpec = exp(-length(bp - vec2(-1.6, -1.6)) * 0.82);
                vec3 ballCol = mix(rimTint * 0.85, vec3(1.0), clamp(bSpec * 1.2 + 0.35, 0.0, 1.0));

                // Luminous vertical comet trail behind the launching projectile!
                float behind = (dir > 0.0) ? bp.y : -bp.y; // > 0 trailing behind ball
                float trailLen = 22.0 + 28.0 * ft;
                float trail = smoothstep(0.0, 3.0, behind) * smoothstep(trailLen, 0.0, behind)
                            * exp(-abs(bp.x) * 0.58) * (0.72 * ft) * inPlotY;
                float bGlow = exp(-br * 0.26) * 0.55 * ft;

                col = mix(col, ballCol, ballMask);
                col += mix(rimTint, vec3(1.0), 0.55) * (trail + bGlow);
                alpha = max(alpha, clamp(max(ballMask, trail + bGlow * 0.85), 0.0, 1.0));
            }

            // B. POST-IMPACT VFX (lead >= 0.0)
            if (lead >= 0.0) {
                float age = clamp(lead / 3.2, 0.0, 1.0);
                float decay = exp(-age * 3.1) * fadeEnv;

                if (dir != 0.0) {
                    // MOVED BAND: Impact shock flash + directional splash droplets + expanding ripple ring!
                    impactFlash = decay;
                    haloAmp = decay * 1.15;
                    haloRadius = 7.5 + age * 20.0;

                    // Impact burst core at live node
                    float iGlow = exp(-r * 0.14) * exp(-age * 4.5) * 0.95 * fadeEnv;
                    col += mix(vec3(1.0), rimTint, 0.30) * iGlow;
                    alpha = max(alpha, clamp(iGlow, 0.0, 1.0));

                    // 3 crisp directional splash droplets spraying along impact direction (UP or DOWN)
                    if (age < 0.85) {
                        float spFade = sin(clamp(age / 0.85, 0.0, 1.0) * PI) * fadeEnv;
                        for (int k = -1; k <= 1; ++k) {
                            float fk = float(k);
                            float sx = bx + fk * (10.5 * age) + fk * 2.0;
                            float sy = liveY - dir * (16.0 * age - 8.0 * age * age) - abs(fk) * dir * 3.0;
                            float sr = length(p - vec2(sx, sy));
                            float sRad = (2.6 - abs(fk) * 0.45) * (0.45 + 0.55 * spFade);
                            float sMask = smoothstep(sRad + 0.8, max(0.2, sRad - 0.6), sr) * spFade;
                            col += mix(rimTint, vec3(1.0), 0.75) * sMask * 1.15;
                            alpha = max(alpha, clamp(sMask, 0.0, 1.0));
                        }
                    }
                } else {
                    // UNCHANGED / STILL BAND: Pure radiant light bloom & soft expanding rings around the orb!
                    float stillGlow = exp(-r * 0.16) * exp(-age * 2.4) * 0.72 * fadeEnv;
                    col += mix(vec3(1.0), rimTint, 0.45) * stillGlow;
                    alpha = max(alpha, clamp(stillGlow, 0.0, 1.0));

                    haloAmp = exp(-age * 2.2) * 0.95 * fadeEnv;
                    haloRadius = 6.5 + age * 18.5;

                    // Soft second outer light ring for unchanged bands
                    float r2 = haloRadius + 6.0;
                    float ring2 = exp(-abs(r - r2) * 0.95) * haloAmp * 0.48;
                    col += mix(vec3(1.0), rimTint, 0.45) * ring2;
                    alpha = max(alpha, clamp(ring2 * 0.85, 0.0, 1.0));
                }
            }
        }

        // Render the 3D glossy mercury orb on the live wave
        float rad = 4.9 + isAct * 1.4 + impactFlash * 1.8;
        if (r < rad + 26.0) {
            float bead = smoothstep(rad + 0.9, rad - 0.8, r);
            float specDot = exp(-length(dp - vec2(-rad * 0.32, -rad * 0.32)) * 0.85);
            float rim = exp(-abs(r - rad * 0.85) * 1.1) * 0.65;
            vec3 beadCol = mix(rimTint * 0.78, vec3(1.0), clamp(specDot * 1.15 + rim * 0.55 + impactFlash * 0.4, 0.0, 1.0));
            col = mix(col, beadCol, bead);
            alpha = max(alpha, bead);

            float rAmp = max(haloAmp, isAct * (0.65 + 0.35 * dragPulse));
            if (rAmp > 0.03) {
                float ringR = (haloAmp > 0.03) ? haloRadius : (rad + 3.2);
                float ring = exp(-abs(r - ringR) * 0.88) * rAmp;
                col += mix(vec3(1.0), rimTint, 0.4) * ring * 0.95;
                alpha = max(alpha, clamp(ring * 0.85, 0.0, 1.0));
            }
        }
    }

    col = clamp(col, 0.0, 1.55);
    alpha = clamp(alpha, 0.0, 1.0);
    fragColor = vec4(col * alpha, alpha) * qt_Opacity;
}
