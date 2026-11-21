#version 440

// One-Time Baked Organic Cloudy Sheet-Lightning Flash Sprite (160x160, `live: false`).
// Produces a feathered, irregular storm-cloud illumination glow with ZERO circular banding or hard edges!

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
};

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

float fbm4(vec2 p) {
    float v = 0.0;
    float a = 0.52;
    mat2 rot = mat2(0.80, 0.60, -0.60, 0.80);
    for (int i = 0; i < 4; i++) {
        v += a * noise(p);
        p = rot * p * 2.1 + vec2(5.3, 9.7);
        a *= 0.50;
    }
    return v;
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * 2.0;
    float r = length(p);
    if (r >= 0.99) {
        fragColor = vec4(0.0);
        return;
    }

    // Organic irregular cloud-diffused glow (never a sterile geometric circle!)
    float cloud = fbm4(p * 2.6 + vec2(2.1, -1.7));
    float fine  = fbm4(p * 5.8 + vec2(-3.4, 4.2));
    float rWarp = r + (cloud - 0.5) * 0.34;

    float outerMist = exp(-rWarp * rWarp * 4.2) * (0.48 + 0.62 * cloud);
    float midBloom  = exp(-rWarp * rWarp * 11.5) * (0.65 + 0.45 * fine);
    float hotCore   = exp(-r * r * 32.0) * 0.85;

    // Smooth strict zero before quad border so no box seam can ever appear
    float edgeFade = 1.0 - smoothstep(0.68, 0.98, r);
    float lum = clamp((outerMist * 0.55 + midBloom * 0.72 + hotCore) * edgeFade, 0.0, 1.0);

    // Warm starlight-white core tapering into delicate pale silver-champagne storm glow
    vec3 col = mix(vec3(0.90, 0.91, 0.97), vec3(1.0, 0.97, 0.91), smoothstep(0.15, 0.75, lum));
    fragColor = vec4(col * lum, lum) * qt_Opacity;
}
