#version 440

// Ultra-Subtle Monochrome Obsidian Cosmic Smoke Backdrop for [4/4] (`blackHoleMode`).
// Baked ONCE into an offscreen GPU texture (`ShaderEffectSource { live: false }`) -> 0% per-frame GPU cost!
// Matches the moody pitch-black void + faint charcoal smoke corners in Download.mp4.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;
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

float fbm5(vec2 p) {
    float v = 0.0;
    float a = 0.50;
    for (int i = 0; i < 5; i++) {
        v += a * noise(p);
        p = ROT * p * 2.06 + vec2(13.1, 8.7);
        a *= 0.50;
    }
    return v;
}

void main() {
    float aspect = res.x / max(res.y, 1.0);
    vec2 uv = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0);

    // Pure obsidian void base (#020204)
    vec3 col = vec3(0.008, 0.008, 0.012);

    // Subtle dark charcoal cosmic smoke drifting in lower-left & upper-right corners (like Download.mp4)
    vec2 q = vec2(fbm5(uv * 2.2), fbm5(uv * 2.2 + vec2(4.3, 2.1)));
    float smoke = fbm5(uv * 2.6 + (q - 0.5) * 0.9);
    float fine = fbm5(uv * 5.8 - q * 0.6);

    float cornerLL = exp(-pow(length((uv - vec2(-0.55, 0.35)) * vec2(1.1, 1.4)), 2.0));
    float cornerUR = exp(-pow(length((uv - vec2(0.55, -0.32)) * vec2(1.1, 1.4)), 2.0));
    float ringMist = smoothstep(0.18, 0.85, length(uv)) * (0.28 + 0.72 * max(cornerLL, cornerUR));

    float mistVal = smoothstep(0.28, 0.80, smoke * 0.72 + fine * 0.28) * ringMist;
    // Subtle cinematic charcoal smoke matching Download.mp4
    col += vec3(0.088, 0.086, 0.094) * mistVal;

    // Ultra-faint warm core dust scatter right behind the black hole
    float centerScatter = exp(-length(uv) * 3.6) * 0.036;
    col += vec3(0.95, 0.72, 0.42) * centerScatter;

    fragColor = vec4(col, 1.0) * qt_Opacity;
}
