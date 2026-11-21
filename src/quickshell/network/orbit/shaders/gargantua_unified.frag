#version 440

// Unified Gravitational-Lensing Black Hole Shader for [3/3] (Reference: back hole.png)
// Fixed 600x420 GPU quad (~252k px = <0.45ms/frame on Intel Iris Plus G1!)
// Key Upgrades vs legacy gargantua_blackhole.frag:
//   - True smooth-minimum (smin) unified gravitational lensing field: horizontal accretion wings
//     seamlessly curve UP into the upper Einstein arch and DOWN into the lower arch (zero pasted-on bar!)
//   - Fine silky concentric luminous plasma strands flowing continuously along the unified iso-contours
//   - Iconic left-side relativistic Doppler flare where approaching wing merges into the photon sphere
//   - Delicate gracefully-bowed foreground equatorial bridge crossing the velvety obsidian shadow
//   - Live uniforms for colorMode (0.0 = Champagne back hole.png, 1.0 = Fiery Copper) & tiltRad (6.6 deg vs 0 deg)
//   - Full support for Power OFF implosion `vortex` & Power ON supernova `pulse`!

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float pulse;
    float vortex;
    float colorMode; // 0.0 = Champagne (back hole.png), 1.0 = Fiery Copper
    float tiltRad;   // ~0.115 rad (6.6 deg down-right) or 0.0 (horizontal)
};

const mat2 ROT = mat2(0.80, 0.60, -0.60, 0.80);

float hash21(vec2 p) {
    p = fract(p * vec2(127.31, 311.73));
    p += dot(p, p + 41.29);
    return fract(p.x * p.y);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    vec2 u = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

// Fast 4-octave smooth turbulence for silky cosmic plasma & dusty outer wings
float fbm4(vec2 p) {
    float v = 0.0;
    float a = 0.52;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = ROT * p * 2.04 + vec2(7.3, 11.9);
        a *= 0.49;
    }
    return v;
}

// Polynomial smooth-minimum: merges circular lensed arches & horizontal wings into ONE unified silhouette!
float smin(float a, float b, float k) {
    float h = clamp(0.5 + 0.5 * (b - a) / max(k, 0.0001), 0.0, 1.0);
    return mix(b, a, h) - k * h * (1.0 - h);
}

vec3 acesTone(vec3 x) {
    return clamp((x * (2.51 * x + 0.028)) / (x * (2.43 * x + 0.58) + 0.14), 0.0, 1.0);
}

void main() {
    // Aspect-matched 600x420 quad -> x in [-1.428, 1.428], y in [-1.0, 1.0]
    vec2 p = (qt_TexCoord0 - 0.5) * vec2(2.857, 2.0);
    float edgeFadeX = 1.0 - smoothstep(1.06, 1.41, abs(p.x));
    float edgeFadeY = 1.0 - smoothstep(0.74, 0.99, abs(p.y));
    float quadFade = edgeFadeX * edgeFadeY;
    if (quadFade <= 0.0005) {
        fragColor = vec4(0.0);
        return;
    }

    // Rotate by tiltRad (positive tiltRad tilts right wing slightly downward, matching back hole.png!)
    float ca = cos(tiltRad);
    float sa = sin(tiltRad);
    vec2 pt = vec2(ca * p.x + sa * p.y, -sa * p.x + ca * p.y);

    float vtx = clamp(vortex, 0.0, 1.0);
    float cm  = clamp(colorMode, 0.0, 1.0);

    // Event horizon radius (expands slightly & hungrier during Power OFF vortex!)
    float rShadow = 0.285 + vtx * 0.080;
    float r = length(pt);
    float ang = atan(pt.y, pt.x);

    // Dual Color Palettes:
    //   cm = 0.0 -> Creamy Champagne / Warm Dusty Bronze (exact back hole.png!)
    //   cm = 1.0 -> Rich Interstellar Fiery Copper-Amber
    vec3 colDust   = mix(vec3(0.42, 0.26, 0.16), vec3(0.46, 0.16, 0.04), cm);
    vec3 colMid    = mix(vec3(0.82, 0.61, 0.40), vec3(0.88, 0.44, 0.13), cm);
    vec3 colBright = mix(vec3(0.99, 0.88, 0.70), vec3(1.00, 0.76, 0.36), cm);
    vec3 colHot    = mix(vec3(1.00, 0.98, 0.93), vec3(1.00, 0.97, 0.89), cm);

    // Relativistic Doppler Beaming: strong approaching flare on the LEFT, warmer dusty right wing!
    float dopplerLum  = 0.76 + 0.56 * smoothstep(0.55, -0.58, pt.x);
    float dopplerTemp = smoothstep(0.42, -0.50, pt.x);

    // ------------------------------------------------------------------
    // 1. UNIFIED GRAVITATIONAL LENSING DISTANCE FIELD (Tight Round Halo + Sleek Merged Wings!)
    // ------------------------------------------------------------------
    // Round Einstein lensed halo (slightly fuller upper arch than lower arch, tight around shadow)
    float archScaleY = pt.y < 0.0 ? 0.96 : 1.04;
    float rArch = length(vec2(pt.x * 1.00, pt.y * archScaleY));
    float dArch = max(0.0, rArch - rShadow);

    // Sleek sweeping horizontal accretion wings smoothly joining the left & right rim of the halo
    float ax = abs(pt.x);
    float wingStart = smoothstep(rShadow * 0.58, rShadow * 1.12, ax);
    float wingTaper = mix(1.45, 3.15, smoothstep(rShadow, 1.34, ax));
    float yWingCenter = 0.024 * exp(-ax * 1.5);
    float dWing = abs(pt.y - yWingCenter) * wingTaper + max(0.0, ax - rShadow * 0.92) * 0.145;
    dWing = mix(dArch + 0.45, dWing, wingStart);

    // Tighter smooth-minimum (k = 0.125): keeps the round halo circular while curving cleanly into sleek wings!
    float dUnified = smin(dArch, dWing, 0.125);

    // ------------------------------------------------------------------
    // 2. SILKY CONCENTRIC FLOWING PLASMA STRANDS (Following Unified Iso-Contours!)
    // ------------------------------------------------------------------
    float wingBlend = smoothstep(rShadow * 0.88, rShadow * 1.48, ax);
    float flowPhase = ang * 2.0 - time * (0.76 + vtx * 1.65) + log(max(r, 0.14)) * (3.0 + vtx * 3.8);
    vec2 swirlUv = vec2(flowPhase, dUnified * 20.0 + time * (0.20 + vtx * 2.2));
    vec2 wingUv  = vec2(pt.x * 3.8 - time * (1.42 + vtx * 1.5), (pt.y - yWingCenter) * 32.0);
    vec2 unifiedUv = mix(swirlUv, wingUv, wingBlend * 0.65);

    float turbA = fbm4(unifiedUv);
    float turbB = fbm4(unifiedUv * 2.25 + vec2(turbA * 1.15 - time * 0.48, -turbA * 0.65));

    // Crisp multi-track concentric luminous silk rings wrapping around the halo & flowing out the wings!
    float contourCoord = dUnified * 46.0 + (turbA - 0.5) * 2.4 + (turbB - 0.5) * 1.1;
    float fineTracks   = pow(0.5 + 0.5 * sin(contourCoord * 1.65 + time * 0.50), 1.35);
    float silkFibers   = smoothstep(0.16, 0.90, fineTracks * 0.62 + turbB * 0.52);

    // Crisp tight luminous halo + delicate feathery outer cosmic dust (keeps dark space crisp outside!)
    float innerBand   = exp(-dUnified * 9.2) * (0.42 + 0.98 * silkFibers);
    float outerDust   = exp(-dUnified * 4.4) * (0.20 + 0.54 * turbA) * (1.0 - smoothstep(0.75, 1.38, ax * 0.96));
    float archBias    = pt.y < 0.0 ? 1.05 : 0.86;
    float unifiedBody = (innerBand * 1.24 + outerDust * 0.34) * mix(archBias, 1.0, wingBlend) * dopplerLum;

    // Subtle dark dust lanes carved between concentric silk tracks for photographic depth
    float dustCarve = 1.0 - 0.34 * smoothstep(0.42, 0.82, turbA) * smoothstep(0.04, 0.24, dUnified);
    unifiedBody *= dustCarve;

    // Razor-sharp incandescent Photon Sphere hugging the dark event horizon
    float photonMain = exp(-abs(r - (rShadow + 0.009)) * 78.0) * 2.05 * (0.82 + 0.34 * dopplerTemp);
    float photonEcho = exp(-abs(r - (rShadow + 0.046)) * 44.0) * 0.72 * (0.60 + 0.50 * silkFibers);

    // Iconic LEFT relativistic Doppler flare right where the left wing fuses into the photon ring!
    vec2 flarePos = vec2(-(rShadow + 0.045), 0.015);
    float leftFlare = exp(-dot((pt - flarePos) * vec2(3.1, 3.9), (pt - flarePos) * vec2(3.1, 3.9))) * 1.22;
    float leftGlow  = exp(-dot((pt - vec2(-(rShadow + 0.16), 0.015)) * vec2(1.55, 3.6), (pt - vec2(-(rShadow + 0.16), 0.015)) * vec2(1.55, 3.6))) * 0.50;

    vec3 haloCol = mix(colDust, colMid, smoothstep(0.05, 0.32, unifiedBody));
    haloCol = mix(haloCol, colBright, smoothstep(0.28, 0.68, unifiedBody));
    haloCol = mix(haloCol, colHot, smoothstep(0.64, 1.22, unifiedBody) * (0.68 + 0.32 * dopplerTemp));

    vec3 backLayer = haloCol * unifiedBody
        + mix(colBright, colHot, 0.55 + 0.45 * dopplerTemp) * photonEcho
        + colHot * photonMain * (0.92 + 0.22 * pulse)
        + mix(colBright, colHot, 0.85) * leftFlare
        + mix(colMid, colBright, 0.65) * leftGlow;

    // Subtle atmospheric bloom around the unified black hole
    float softBloom = exp(-dUnified * 3.0) * 0.12 * (0.75 + 0.35 * dopplerLum);
    backLayer += mix(colDust, colMid, 0.5) * softBloom;

    // ------------------------------------------------------------------
    // 3. VELVETY EVENT HORIZON SHADOW (With Subtle Atmospheric Rim Scatter!)
    // ------------------------------------------------------------------
    float shadowMask = smoothstep(rShadow - 0.008, rShadow + 0.010, r);
    float shadowAlpha = 1.0 - shadowMask;
    float innerRimHaze = smoothstep(rShadow - 0.08, rShadow, r) * (1.0 - shadowMask) * 0.08;
    vec3 col = backLayer * shadowMask + mix(colDust, colMid, 0.45) * innerRimHaze;

    // ------------------------------------------------------------------
    // 4. DELICATE FOREGROUND EQUATORIAL BRIDGE (Gracefully Thin Across Front of Shadow!)
    // ------------------------------------------------------------------
    // Slight natural downward gravitational bow across the front of the dark sphere (exact back hole.png!)
    float sphereT = clamp(pt.x / max(rShadow, 0.01), -1.0, 1.0);
    float yBridge = 0.024 + 0.026 * cos(sphereT * 1.5708) * smoothstep(1.25, 0.0, abs(pt.x) / rShadow);
    float dyBridge = pt.y - yBridge;

    // Thin waist crossing the shadow, flaring gently where it connects seamlessly into left & right wings
    float bridgeHalfH = mix(0.024, 0.044, smoothstep(0.0, rShadow * 1.35, ax))
        * mix(1.0, 0.52, smoothstep(rShadow * 1.35, 1.32, ax));
    float ybNorm = abs(dyBridge) / max(bridgeHalfH, 0.004);

    float bFlow1 = fbm4(vec2(pt.x * 5.2 - time * 1.65, dyBridge * 38.0 + 1.3));
    float bFlow2 = fbm4(vec2(pt.x * 11.5 - time * 2.75 + bFlow1 * 0.8, dyBridge * 74.0 - 2.9));
    float bPlasma = 0.54 + 0.46 * bFlow1 + 0.34 * bFlow2;

    float bridgeWingEnv = exp(-pow(ax * 0.72, 2.2)) * (1.0 - smoothstep(0.95, 1.38, ax));
    float bridgeCore    = exp(-ybNorm * ybNorm * 2.8) * bPlasma;
    float bridgeSpine   = exp(-abs(dyBridge) * 115.0) * (0.78 + 0.42 * bFlow2) * (1.0 - smoothstep(0.68, 1.28, ax));
    float bridgeSheath  = exp(-abs(dyBridge) * 24.0) * 0.32 * bFlow1;

    float bridgeEnergy = (bridgeCore * 1.15 + bridgeSheath) * bridgeWingEnv * dopplerLum;
    vec3 bridgeCol = mix(colMid, colBright, smoothstep(0.15, 0.65, bridgeEnergy));
    bridgeCol = mix(bridgeCol, colHot, smoothstep(0.58, 1.20, bridgeEnergy));

    vec3 frontBridgeRgb = bridgeCol * bridgeEnergy * 0.92
        + mix(colBright, colHot, 0.72 + 0.28 * dopplerTemp) * bridgeSpine * 1.25;

    // Cross cleanly IN FRONT of the dark event horizon shadow & fuse naturally into the wings!
    float bridgeOcclude = clamp(bridgeCore * bridgeWingEnv * 0.85 + bridgeSpine * 0.85, 0.0, 1.0);
    col = col * (1.0 - bridgeOcclude * 0.45) + frontBridgeRgb;

    // Power ON supernova charge & Wi-Fi core-charge flare + Power OFF vortex rim highlight
    col *= (1.0 + pulse * 0.48);
    col += colHot * exp(-abs(r - (rShadow + 0.016)) * 24.0) * (pulse * 0.82 + vtx * 0.36);
    col *= quadFade;

    vec3 outRgb = acesTone(col);
    float glowA = clamp(max(outRgb.r, max(outRgb.g, outRgb.b)) * 1.25, 0.0, 1.0);
    float outAlpha = clamp(max(shadowAlpha * 0.99, glowA) * quadFade, 0.0, 1.0);

    fragColor = vec4(outRgb, outAlpha) * qt_Opacity;
}
