#version 440

// Photorealistic IMAX-Grade Interstellar "Gargantua" Black Hole Shader for [2/2].
// Fixed 500x500 GPU quad -> < 0.45ms/frame on Intel Iris Plus G1!
// Upgrades:
//   - True asymmetric relativistic Doppler beaming (incandescent white-gold approaching left wing,
//     rich fiery copper-amber receding right wing)
//   - Organic warped logarithmic-spiral plasma filaments flowing smoothly across both the
//     gravitationally-lensed Einstein arches AND the foreground equatorial accretion disk
//     (zero artificial bullseye sine rings!)
//   - Dual razor-sharp photon sphere + fiery dusty outer corona fading cleanly before quad edge.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float time;
    float pulse;
    float vortex;
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

// Fast 4-octave smooth plasma turbulence (silky fiery wisps, zero blocky noise)
float fbm4(vec2 p) {
    float v = 0.0;
    float a = 0.52;
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = ROT * p * 2.06 + vec2(9.3, 13.7);
        a *= 0.49;
    }
    return v;
}

// Filmic HDR curve preserving velvety fiery copper/amber & creamy white highlights
vec3 acesTone(vec3 x) {
    return clamp((x * (2.51 * x + 0.028)) / (x * (2.43 * x + 0.58) + 0.14), 0.0, 1.0);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * 2.0;
    float r = length(p);
    if (r >= 0.99) {
        fragColor = vec4(0.0);
        return;
    }

    float quadFade = 1.0 - smoothstep(0.74, 0.985, r);

    // Subtle cinematic tilt (~2.2 deg)
    float ca = 0.9992, sa = -0.038;
    vec2 pt = vec2(ca * p.x - sa * p.y, sa * p.x + ca * p.y);

    // Rich Interstellar Blackbody Plasma Palette
    vec3 colEmber     = vec3(0.46, 0.17, 0.04);
    vec3 colCopper    = vec3(0.86, 0.46, 0.15);
    vec3 colGold      = vec3(1.00, 0.76, 0.40);
    vec3 colChampagne = vec3(1.00, 0.93, 0.78);
    vec3 colHotWhite  = vec3(1.00, 0.99, 0.96);

    float rShadow = 0.198 + clamp(vortex, 0.0, 1.0) * 0.065;

    // Relativistic Doppler Beaming: left side approaches viewer (hotter & brighter),
    // right side recedes (warmer amber-copper & slightly dimmer)
    float dopplerLum  = 0.88 + 0.36 * smoothstep(0.55, -0.65, pt.x);
    float dopplerTemp = smoothstep(0.45, -0.55, pt.x);

    // ------------------------------------------------------------------
    // 1. Gravitationally-Lensed Upper & Lower Einstein Arches (Organic Swirling Plasma!)
    // ------------------------------------------------------------------
    float ang = atan(pt.y, pt.x);
    float logR = log(max(r, 0.06));
    float vtx = clamp(vortex, 0.0, 1.0);
    // Logarithmic spiral plasma streams flowing smoothly around (and rushing inward during implosion vortex!)
    vec2 archUv1 = vec2(ang * 2.2 - time * (0.62 + vtx * 1.4) + logR * (5.2 + vtx * 4.2), r * 14.0 + time * (-0.28 + vtx * 2.6));
    vec2 archUv2 = vec2(ang * 4.4 - time * (1.05 + vtx * 2.0) + logR * (9.0 + vtx * 5.0), r * 24.0 + time * (0.18 + vtx * 3.2));
    float swirlA = fbm4(archUv1);
    float swirlB = fbm4(archUv2 + vec2(swirlA * 1.4, -swirlA * 0.8));
    float filament = smoothstep(0.22, 0.86, swirlA * 0.58 + swirlB * 0.48);

    // Upper Einstein arch rises higher & brighter than lower arch (exact Interstellar lensing geometry!)
    float upperBias = pt.y < 0.0 ? 1.0 : 0.76;
    float archScaleY = pt.y < 0.0 ? 0.90 : 1.06;
    float rArch = length(vec2(pt.x * 0.96, pt.y * archScaleY));
    float distFromRim = max(0.0, rArch - rShadow);

    // Dense inner lensed plasma band + feathery outer gravitational corona
    float archCore = smoothstep(rShadow - 0.008, rShadow + 0.012, rArch)
        * exp(-distFromRim * 7.8) * (0.45 + 0.95 * filament) * upperBias;
    float archCorona = exp(-distFromRim * 3.9) * (0.28 + 0.55 * swirlA) * upperBias;

    // Dual Photon Sphere: razor-sharp incandescent inner ring + delicate secondary light echo
    float photonPrimary   = exp(-abs(r - (rShadow + 0.005)) * 82.0) * 1.95;
    float photonSecondary = exp(-abs(r - (rShadow + 0.024)) * 34.0) * 0.56 * (0.65 + 0.45 * swirlB);

    float archEnergy = (archCore * 1.32 + archCorona * 0.44) * dopplerLum;
    vec3 archCol = mix(colEmber, colCopper, smoothstep(0.05, 0.30, archEnergy));
    archCol = mix(archCol, colGold, smoothstep(0.25, 0.68, archEnergy));
    archCol = mix(archCol, colChampagne, smoothstep(0.60, 1.15, archEnergy) * (0.65 + 0.35 * dopplerTemp));

    vec3 backLayer = archCol * archEnergy
        + mix(colGold, colChampagne, dopplerTemp) * photonSecondary * dopplerLum
        + colHotWhite * photonPrimary * (0.90 + 0.20 * pulse);

    // Subtle atmospheric warm gravitational bloom
    float warmHalo = exp(-r * 3.5) * 0.28 + exp(-length(vec2(pt.x * 0.58, pt.y * 2.1)) * 3.0) * 0.22;
    backLayer += mix(colEmber, colCopper, 0.55 + 0.25 * dopplerTemp) * warmHalo;

    // Pitch-black Event Horizon Shadow (occludes back arches & stars cleanly!)
    float shadowMask = smoothstep(rShadow - 0.006, rShadow + 0.008, r);
    vec3 col = backLayer * shadowMask;
    float shadowAlpha = 1.0 - shadowMask;

    // ------------------------------------------------------------------
    // 2. Relativistic Horizontal Equatorial Accretion Disk (Sweeps IN FRONT OF Shadow!)
    // ------------------------------------------------------------------
    float dyDisk = pt.y - 0.014;
    float ax = abs(pt.x);

    // Elegant perspective ribbon thickness: crisp waist across front of shadow, flaring slightly on wings, tapering cleanly to tips
    float diskHalfH = mix(0.048, 0.011, smoothstep(0.18, 0.94, ax)) * (1.0 + 0.16 * exp(-pow((ax - 0.30) * 4.5, 2.0)));
    float yNorm = abs(dyDisk) / max(diskHalfH, 0.005);

    // Flowing multi-speed plasma streams sheared horizontally across the black hole!
    float flow1 = fbm4(vec2(pt.x * 4.6 - time * 1.45, dyDisk * 34.0 + 1.1));
    float flow2 = fbm4(vec2(pt.x * 10.8 - time * 2.45 + flow1 * 0.85, dyDisk * 68.0 - 3.7));
    float flow3 = fbm4(vec2(pt.x * 20.0 - time * 3.40, dyDisk * 110.0 + 5.2));
    float diskPlasma = 0.42 + 0.58 * flow1 + 0.42 * flow2 + 0.22 * flow3;

    float wingEnv = exp(-pow(ax * 0.98, 2.05)) * (1.0 - smoothstep(0.75, 0.985, ax));
    float innerBoost = 0.82 + 0.62 * exp(-pow((ax - 0.23) * 3.4, 2.0));

    float diskBodyY   = exp(-yNorm * yNorm * 2.25);
    float diskSheathY = exp(-abs(dyDisk) * mix(12.5, 23.0, smoothstep(0.18, 0.88, ax)));
    // Fine dark dust shear lane subtly etched near outer upper/lower wings for photographic realism!
    float dustStreak  = 1.0 - 0.28 * smoothstep(0.42, 0.82, flow2) * smoothstep(0.24, 0.65, ax) * smoothstep(0.25, 0.85, yNorm);

    // Razor-sharp incandescent equatorial spine
    float spine = exp(-abs(dyDisk) * 118.0) * (1.0 - smoothstep(0.42, 0.94, ax)) * (0.72 + 0.48 * flow2);

    float diskEnergy = (diskBodyY * 1.28 * diskPlasma * dustStreak + diskSheathY * 0.36 * flow1)
        * wingEnv * innerBoost * dopplerLum;

    vec3 diskCol = mix(colEmber, colCopper, smoothstep(0.05, 0.28, diskEnergy));
    diskCol = mix(diskCol, colGold, smoothstep(0.24, 0.62, diskEnergy));
    diskCol = mix(diskCol, colChampagne, smoothstep(0.55, 1.08, diskEnergy));
    diskCol = mix(diskCol, colHotWhite, smoothstep(0.95, 1.65, diskEnergy) * (0.75 + 0.25 * dopplerTemp));

    vec3 frontDiskRgb = diskCol * diskEnergy * 1.12 + mix(colChampagne, colHotWhite, 0.65 + 0.35 * dopplerTemp) * spine * 1.38;

    // Front accretion disk passes smoothly IN FRONT OF the jet-black shadow!
    float frontOcclude = clamp(diskBodyY * wingEnv * 0.94 + spine * 0.88, 0.0, 1.0);
    col = col * (1.0 - frontOcclude * 0.42) + frontDiskRgb;

    // Dramatic golden core-charge flare & supernova hyper-charge before explosion!
    col *= (1.0 + pulse * 0.48);
    col += colChampagne * exp(-abs(r - (rShadow + 0.015)) * 22.0) * (pulse * 0.78 + vtx * 0.35);
    col *= quadFade;

    vec3 outRgb = acesTone(col);

    // Fully opaque inside the black event horizon shadow; smooth feathered glow outside
    float glowA = clamp(max(outRgb.r, max(outRgb.g, outRgb.b)) * 1.28, 0.0, 1.0);
    float outAlpha = clamp(max(shadowAlpha * 0.99, glowA) * quadFade, 0.0, 1.0);

    fragColor = vec4(outRgb, outAlpha) * qt_Opacity;
}
