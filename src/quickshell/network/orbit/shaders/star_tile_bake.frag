#version 440

// Seamless Periodic Starfield Tile Baker for [3/3] (`pseudo3DMode`).
// Baked ONCE into two GPU textures (`ShaderEffectSource { live: false }`):
//   layerMode = 0.0 -> Dense razor-sharp 1px pinpoint astronomical dust stars (seamless periodic grid)
//   layerMode = 1.0 -> Crisp mid stars + sparse jewel-like 4-point optical diffraction hero stars
// Zero per-frame loops or hashes during runtime; smooth cell-edge falloff prevents any box clipping.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float layerMode;
    vec4 accentColor;
};

vec2 hash22(vec2 p) {
    vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.xx + p3.yz) * p3.zy);
}

// Seamless periodic pinpoint star grid (`period` MUST be an integer)
// Keeps stars safely inside cell interior + smooth radial window so halos NEVER touch cell boundaries!
vec3 seamlessPinpoints(vec2 uv, float period, float threshold, float brightness, vec2 seedOff) {
    vec2 sp = uv * period;
    vec2 id = mod(floor(sp), period);
    vec2 gv = fract(sp) - 0.5;

    vec2 rnd = hash22(id + seedOff);
    if (rnd.x < threshold) return vec3(0.0);

    vec2 off = (rnd - 0.5) * 0.56;
    float d = length(gv - off);
    // Strict zero before reaching nearest cell edge (min margin = 0.22)
    float cellWin = smoothstep(0.21, 0.05, d);
    if (cellWin <= 0.001) return vec3(0.0);

    float mag = pow(fract(rnd.y * 37.3), 3.3);
    float coreSize = mix(0.016, 0.048, mag);
    float core = smoothstep(coreSize, 0.0, d);
    float halo = exp(-d * mix(40.0, 19.0, mag)) * (0.16 + 0.34 * mag) * cellWin;

    float tintPick = fract(rnd.x * 73.1 + rnd.y * 17.3);
    vec3 sCol = vec3(0.95, 0.96, 1.00);
    if (tintPick < 0.26) sCol = vec3(0.76, 0.88, 1.00);
    else if (tintPick < 0.52) sCol = vec3(0.95, 0.80, 1.00);
    else if (tintPick < 0.72) sCol = vec3(1.00, 0.95, 0.82);

    return sCol * (core * 1.10 + halo) * brightness;
}

// Seamless periodic 4-point diffraction hero stars (`period` MUST be an integer)
vec3 seamlessHeroStars(vec2 uv, float period, vec3 accentRgb) {
    vec2 sp = uv * period;
    vec2 baseId = floor(sp);
    vec2 baseGv = fract(sp);
    vec3 acc = vec3(0.0);

    for (int y = -1; y <= 1; y++) {
        for (int x = -1; x <= 1; x++) {
            vec2 cell = mod(baseId + vec2(float(x), float(y)) + period, period);
            vec2 rnd = hash22(cell + vec2(17.2, 53.9));
            if (rnd.x < 0.89) continue;

            vec2 starPos = vec2(float(x), float(y)) + 0.22 + rnd * 0.56;
            vec2 d = baseGv - starPos;
            float dist = length(d);
            if (dist > 0.72) continue;

            float win = smoothstep(0.72, 0.26, dist);
            float mag = 0.52 + 0.50 * fract(rnd.y * 29.3);
            float core = exp(-dist * 46.0) * 1.45 + exp(-dist * 14.5) * 0.28;

            float spikeH = exp(-abs(d.y) * 145.0) * exp(-abs(d.x) * 9.5);
            float spikeV = exp(-abs(d.x) * 145.0) * exp(-abs(d.y) * 9.5);
            float spikes = (spikeH + spikeV) * 0.56;

            float cSel = fract(rnd.x * 41.7);
            vec3 hCol = cSel < 0.50
                ? mix(vec3(0.92, 0.68, 1.00), accentRgb, 0.26)
                : (cSel < 0.80 ? vec3(0.95, 0.97, 1.00) : vec3(0.96, 0.94, 0.76));

            acc += mix(hCol, vec3(1.0), smoothstep(0.04, 0.0, dist)) * (core + spikes) * mag * win;
        }
    }
    return acc;
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec3 stars = vec3(0.0);

    if (layerMode < 0.5) {
        // Dense razor-sharp far cosmic stardust
        stars += seamlessPinpoints(uv, 36.0, 0.68, 0.56, vec2(3.1, 7.4));
        stars += seamlessPinpoints(uv, 20.0, 0.76, 0.78, vec2(19.7, 11.2));
    } else {
        // Crisp mid pinpoint stars + sparse jewel-like 4-point diffraction hero stars
        stars += seamlessPinpoints(uv, 14.0, 0.78, 0.86, vec2(41.3, 29.8));
        stars += seamlessHeroStars(uv, 4.0, accentColor.rgb);
    }

    vec3 rgb = clamp(stars, 0.0, 1.0);
    float a = clamp(max(rgb.r, max(rgb.g, rgb.b)), 0.0, 1.0);
    fragColor = vec4(rgb, a) * qt_Opacity;
}
