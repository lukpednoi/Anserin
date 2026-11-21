#version 440
// IMAX-grade Gargantua power-on charge streams (v4):
// Preserves the exact original concept — two sweeping streams of light from top-left and bottom-right,
// drawn in from outside and spiraling into the black hole's glowing rim as charge builds (0..1) —
// upgraded with sleek domain-warped Interstellar silk-plasma, seamless 2D twisted accretion corona
// (zero atan branch cuts), crisp twinkling cosmic embers (zero cell clipping), ACES filmic tonemap,
// and full GargantuaEditor support (Copper/Champagne colour + 0/6.6 deg tilt).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float rimR;      // event horizon shadow radius in world units
    float farR;      // outer reach beyond rimR (world units)
    float level;     // 0..1 charge build-up
    float time;      // seconds since charge started
    float head;      // 0..1 how far inward the streams have drawn in
    float colorMode; // 0.0 = Champagne, 1.0 = Fiery Copper
    float tiltRad;   // 0.0 or ~0.115 rad (6.6 deg)
};

const float PI = 3.14159265;
const float TAU = 6.28318530;
const float SWEEP = PI * 1.46; // iconic 2-arm silhouette coiling cleanly into the photon ring
const mat2 ROT = mat2(0.80, 0.60, -0.60, 0.80);

vec2 rot2(vec2 v, float a) {
    float c = cos(a);
    float s = sin(a);
    return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

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

// Fast 3-octave smooth plasma turbulence
float fbm3(vec2 p) {
    float v = 0.0;
    float a = 0.54;
    for (int i = 0; i < 3; i++) {
        v += a * noise(p);
        p = ROT * p * 2.04 + vec2(7.3, 11.9);
        a *= 0.48;
    }
    return v;
}

vec3 acesTone(vec3 x) {
    return clamp((x * (2.51 * x + 0.028)) / (x * (2.43 * x + 0.58) + 0.14), 0.0, 1.0);
}

// Crisp glittering stardust embers flowing along the stream (cell-windowed -> ZERO tile artifacts!)
float sampleEmbers(float u, float dn, float seed, float headMask) {
    if (abs(dn) > 2.3) return 0.0;
    float lum = 0.0;
    float speed = 1.75 + 3.25 * level;
    for (int k = 0; k < 2; k++) {
        float fk = float(k);
        vec2 sc = vec2(u * mix(16.0, 26.0, fk) - time * (speed * (0.85 + 0.35 * fk)) + fk * 5.3,
                       dn * mix(2.4, 3.8, fk) + seed * 4.7 + fk * 9.1);
        vec2 cid = floor(sc);
        vec2 cf = fract(sc) - 0.5;
        float rnd = hash21(cid + vec2(seed * 13.7, fk * 29.1));
        float thresh = mix(0.80, 0.58, level);
        if (rnd > thresh) {
            // Keep jitter well inside cell + smooth boundary window so glow NEVER clips at tile edge
            vec2 j = (vec2(hash21(cid + 2.3), hash21(cid + 8.1)) - 0.5) * 0.36;
            vec2 dp = cf - j;
            float stretch = mix(0.82, 0.56, u);
            float d2 = dot(vec2(dp.x * stretch, dp.y), vec2(dp.x * stretch, dp.y));
            float sizeK = mix(78.0, 155.0, hash21(cid + 14.9));
            float cellSafe = smoothstep(0.49, 0.22, abs(cf.x)) * smoothstep(0.49, 0.22, abs(cf.y));
            float dotGlow = (exp(-d2 * sizeK) + exp(-d2 * (sizeK * 0.28)) * 0.28) * cellSafe;
            float tw = 0.55 + 0.45 * sin(time * (7.0 + rnd * 9.0) + rnd * 50.0);
            float env = smoothstep(0.05, 0.24, u) * (1.0 - smoothstep(0.82, 0.98, u))
                      * exp(-dn * dn * 0.38) * headMask;
            lum += dotGlow * tw * env * mix(1.0, 0.72, fk);
        }
    }
    return lum * (0.45 + 0.95 * level);
}

// Evaluate one iconic Interstellar tidal plasma stream (sleek silk fibers + volumetric mist + embers)
vec4 evalStream(vec2 q, float a0, float seed, float doppler) {
    float r = length(q);
    float aRel = mod(atan(q.y, q.x) - a0, TAU);
    float u = aRel / SWEEP;
    if (u <= 0.001 || u >= 0.999) return vec4(0.0);

    // Graceful gravitational inspiral tightening smoothly into Gargantua's photon sphere
    float oneMinusU = 1.0 - u;
    float rs = rimR * 1.06 + farR * pow(oneMinusU, 1.66);

    // Sleek, sculptural ribbon width: airy misty outer tail focusing into an intense tight inner throat
    float baseW = (11.5 + 31.0 * level) * mix(1.42, 0.42, pow(u, 0.72)) + 2.2;
    float rawD = r - rs;
    if (abs(rawD) > baseW * 3.8) return vec4(0.0);

    // Accelerating inward curvilinear flow along the stream
    float speed = 1.15 + 2.65 * level;
    float flowU = u * 7.8 - time * speed - u * u * 1.75;
    float dn = rawD / max(baseW, 1.0);

    // Domain-warped silky FBM turbulence flowing smoothly along the curve
    float nBase = fbm3(vec2(flowU * 0.85 + seed * 2.1, dn * 1.45 + seed));
    float nSilk = fbm3(vec2(flowU * 2.25 - time * (0.75 + 1.2 * level) + (nBase - 0.5) * 1.6,
                            dn * 3.80 + (nBase - 0.5) * 1.3 - seed * 1.9));
    float nFine = fbm3(vec2(flowU * 4.60 - time * (1.3 + 1.9 * level) + nSilk * 1.1,
                            dn * 7.60 + seed * 3.3));

    // Gentle organic radial drift (fuller in outer/mid arm, locked razor-tight near the photon sphere)
    float wobbleEnv = smoothstep(0.0, 0.22, u) * smoothstep(0.92, 0.36, u);
    float d = rawD + (nBase - 0.5) * baseW * 0.68 * wobbleEnv;
    float dNorm = d / max(baseW, 1.0);

    // Gravitational heating gradient: smoky copper-gold tail -> incandescent white-gold throat
    float heatGrad = smoothstep(0.06, 0.84, u);

    // 1. Sleek sinuous molten core filament
    float coreDrift = (nSilk - 0.5) * baseW * 0.24;
    float coreShape = exp(-pow((d - coreDrift) / max(baseW * mix(0.22, 0.13, heatGrad), 0.9), 2.0));
    float coreSilk  = smoothstep(0.16, 0.88, 0.36 + 0.56 * nSilk + 0.38 * nFine);
    float core = coreShape * coreSilk * (0.34 + 0.96 * heatGrad);

    // 2. Fine multi-track concentric silk plasma fibers (exact Gargantua aesthetic!)
    float trackWave = 0.5 + 0.5 * sin(dNorm * 8.5 + (nBase - 0.5) * 3.2 - flowU * 0.6);
    float silkFibers = smoothstep(0.18, 0.92, trackWave * 0.42 + nSilk * 0.44 + nFine * 0.36);
    float dustCarve  = 1.0 - 0.46 * smoothstep(0.44, 0.86, nBase) * smoothstep(0.16, 0.95, abs(dNorm));
    float body = exp(-pow(d / max(baseW * 0.56, 1.8), 2.0)) * silkFibers * dustCarve;

    // 3. Delicate sheared outer plasma tendril peeling gently off the outer curve
    float wispOff = baseW * (0.58 + 0.22 * (nBase - 0.5));
    float wisp = exp(-pow((d - wispOff) / max(baseW * 0.24, 1.2), 2.0))
               * smoothstep(0.28, 0.88, nSilk * 0.60 + nFine * 0.52)
               * smoothstep(0.10, 0.38, u) * (1.0 - smoothstep(0.72, 0.93, u)) * 0.48;

    // 4. Feathery volumetric copper-amber nebula sheath around the stream
    float mist = exp(-pow(d / max(baseW * 1.65, 4.0), 2.0))
               * smoothstep(0.20, 0.88, nBase * 0.72 + nSilk * 0.40) * 0.52;

    // Organic pulsing energy wave surging inward
    float surge = 0.75 + 0.25 * sin(u * 10.5 - time * (2.8 + 5.4 * level) + nBase * 3.5);

    // Feathery outer entry & smooth melt into the photon corona
    float tailIn  = smoothstep(0.0, 0.32, u);
    float rimMelt = 1.0 - smoothstep(0.70, 0.985, u);

    // Advancing comet-like leading head while drawing in from outer space (head: 0 -> 1)
    float headMask = 1.0 - smoothstep(head - 0.18, head + 0.02, u);
    float tipGlow  = exp(-pow((u - (head - 0.045)) / 0.068, 2.0)) * (1.0 - smoothstep(0.84, 1.0, head));

    float env = tailIn * rimMelt * headMask * surge * doppler;

    // Glittering cosmic embers drifting along the stream
    float embers = sampleEmbers(u, dNorm, seed, headMask) * doppler;

    float xHot  = (core * (1.08 + tipGlow * 1.55) + wisp * 0.25) * env;
    float yGold = (body * 1.10 + core * 0.46 + wisp * 0.58 + coreShape * tipGlow * 0.85) * env;
    float zMist = (mist + body * 0.36) * env;
    return vec4(xHot, yGold, zMist, embers);
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * itemSize;

    // Obey GargantuaEditor tiltRad (0° or 6.6°)
    float ca = cos(tiltRad);
    float sa = sin(tiltRad);
    vec2 pt = vec2(ca * p.x + sa * p.y, -sa * p.x + ca * p.y);

    float rCirc = length(pt);
    float maxR = itemSize.x * 0.495;
    if (rCirc >= maxR) {
        fragColor = vec4(0.0);
        return;
    }
    float quadFade = 1.0 - smoothstep(maxR * 0.70, maxR, rCirc);

    // Iconic tilted galactic perspective far out (0.68), relaxing smoothly to circular (0.95) at the photon rim!
    float nearHole = smoothstep(rimR * 3.2 + 80.0, max(rimR * 1.15, 16.0), rCirc);
    float flatY = mix(0.68, 0.95, nearHole);
    vec2 q = vec2(pt.x, pt.y / flatY);

    // Relativistic Doppler beaming (left approaching side hotter & brighter, matching Gargantua!)
    float dopplerLum  = 0.84 + 0.38 * smoothstep(260.0, -260.0, pt.x);
    float dopplerTemp = smoothstep(220.0, -220.0, pt.x);

    // Exact gargantua_unified.frag color palettes (0.0 = Champagne, 1.0 = Fiery Copper)
    float cm = clamp(colorMode, 0.0, 1.0);
    vec3 colDust   = mix(vec3(0.42, 0.25, 0.15), vec3(0.48, 0.15, 0.03), cm);
    vec3 colMid    = mix(vec3(0.84, 0.62, 0.40), vec3(0.92, 0.44, 0.11), cm);
    vec3 colBright = mix(vec3(1.00, 0.89, 0.70), vec3(1.00, 0.76, 0.34), cm);
    vec3 colHot    = mix(vec3(1.00, 0.98, 0.94), vec3(1.00, 0.97, 0.88), cm);

    // 1. TWO ICONIC TIDAL ACCRETION STREAMS (Top-Left & Bottom-Right!)
    vec4 sTotal = evalStream(q, PI * 1.22, 1.3, dopplerLum)
                + evalStream(q, PI * 0.22, 4.7, dopplerLum);

    float lvlGain = 0.46 + 0.94 * level;
    vec3 streamCol = colHot    * sTotal.x * (0.62 + 0.76 * level)
                   + colBright * sTotal.y * (0.50 + 0.64 * level)
                   + mix(colDust, colMid, 0.72) * sTotal.z * (0.44 + 0.52 * level)
                   + mix(colBright, colHot, 0.78) * sTotal.w * 1.45;

    // 2. SEAMLESS 2D TWISTED ACCRETION CORONA & PHOTON-RIM IGNITION (ZERO atan branch-cut seam!)
    float hasRim = step(2.0, rimR);
    float distRim = max(0.0, rCirc - rimR);
    float normRim = distRim / max(rimR, 12.0);
    float logR = log(max(rCirc, 10.0));

    // Continuous 2D logarithmic-spiral twist in Cartesian space (100% periodic & seam-free in 360 deg!)
    vec2 pNorm = pt / max(rimR, 16.0);
    vec2 cUv1 = rot2(pNorm, -time * (1.2 + 3.0 * level) - logR * 1.85) * 1.35;
    float cWarp = fbm3(cUv1 + vec2(2.4, -1.7));
    vec2 cUv2 = rot2(pNorm, -time * (1.9 + 4.4 * level) - logR * 3.10 + (cWarp - 0.5) * 1.2) * 2.55;
    float cSilk = fbm3(cUv2 + vec2(-3.1, 4.2));

    float rimRing = exp(-pow((rCirc - rimR * 1.07) / max(rimR * (0.11 + 0.07 * level), 2.8), 2.0))
                  * (0.52 + 0.70 * cSilk);
    float corona  = exp(-normRim * (2.45 - 0.60 * level)) * (0.28 + 0.80 * cSilk);
    float wingFeed = exp(-pow(pt.y / max(rimR * (0.26 + 0.12 * level), 5.5), 2.0))
                   * exp(-abs(pt.x) / max(rimR * 2.9, 30.0))
                   * smoothstep(rimR * 0.95, rimR * 1.32, rCirc) * (0.38 + 0.62 * cSilk);

    float breath = 0.91 + 0.09 * sin(time * (5.5 + 9.5 * level));
    float cGain = (0.16 + 0.72 * level) * smoothstep(0.24, 0.95, head) * hasRim * breath * dopplerLum;

    vec3 coronaCol = (mix(colBright, colHot, 0.52 + 0.44 * dopplerTemp) * rimRing * 1.08
                   +  mix(colDust, colMid, 0.68) * corona * 0.52
                   +  mix(colMid, colBright, 0.55) * wingFeed * 0.38) * cGain;

    // 3. SEAMLESS DEEP-SPACE GRAVITATIONAL NEBULA DRAFT (2D twisted Cartesian -> zero horizontal seam!)
    float draftR = smoothstep(rimR * 1.05, rimR * 2.4 + 55.0, rCirc) * (1.0 - smoothstep(farR * 0.55, farR * 1.26, rCirc));
    vec2 dUv = rot2(pt / max(farR, 100.0), -time * (0.28 + 0.68 * level) - logR * 1.35) * 2.6;
    float draftN = fbm3(dUv + vec2(5.1, -2.8));
    vec3 draftCol = mix(colDust, colMid, 0.38) * pow(smoothstep(0.30, 0.86, draftN), 1.6) * draftR * (0.04 + 0.13 * level);

    vec3 col = streamCol * lvlGain + coronaCol + draftCol;

    // 4. CRISP EVENT HORIZON SHADOW MASK: keep Gargantua's jet-black shadow razor-sharp!
    float shadowMask = mix(1.0, smoothstep(rimR * 0.86, rimR * 1.06, rCirc), hasRim);
    col *= (0.03 + 0.97 * shadowMask);

    col *= quadFade;
    vec3 outRgb = acesTone(col);

    // Luminous premultiplied alpha: blends seamlessly like glowing plasma light!
    float lum = max(outRgb.r, max(outRgb.g, outRgb.b));
    float outAlpha = clamp(lum * 0.74, 0.0, 0.90) * quadFade;

    fragColor = vec4(outRgb, outAlpha) * qt_Opacity;
}
