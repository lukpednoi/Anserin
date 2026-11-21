#version 440

// Ultra-Fast 60FPS Deep-Space Multi-Depth Parallax Starfield Compositor for [3/3].
// Runs at 1.0x native resolution with ONLY 3 texture lookups per pixel (ZERO loops, ZERO noise!)
// so Intel Iris Plus G1 holds rock-solid 60FPS even in 1920x1080 Fullscreen.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float zoom;
    vec2 res;
    vec2 camPos;
    vec2 hoverOffset;
};

layout(binding = 1) uniform sampler2D farStarTex;
layout(binding = 2) uniform sampler2D nearStarTex;

vec2 parallaxUv(vec2 uv, float depth, float zoomPow, float tileScale, vec2 offset) {
    float zNorm = clamp(zoom / 0.85, 0.42, 2.25);
    float zScale = pow(zNorm, zoomPow);
    vec2 hShift = hoverOffset * (depth - 0.14) * 0.026;
    vec2 p = uv / zScale + camPos * depth + hShift;
    return fract(p * tileScale + offset);
}

void main() {
    float aspect = res.x / max(res.y, 1.0);
    vec2 uv = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0);
    float panelFit = mix(1.22, 1.0, smoothstep(1.15, 1.55, aspect));
    uv *= panelFit;

    // Pure deep obsidian space base (#030208) with ultra-subtle radial deep-indigo cosmos depth
    float bgDist = length(uv * vec2(0.75, 1.05));
    vec3 col = mix(vec3(0.015, 0.011, 0.030), vec3(0.008, 0.006, 0.016), smoothstep(0.0, 1.15, bgDist));

    // 3 seamless parallax depth star layers -> ONLY 3 GPU texture fetches!
    vec2 uvFarA = parallaxUv(uv, 0.06, 0.12, 1.55, vec2(0.13, 0.27));
    vec2 uvFarB = parallaxUv(uv, 0.14, 0.24, 1.15, vec2(0.61, 0.43));
    vec2 uvNear = parallaxUv(uv, 0.28, 0.42, 0.78, vec2(0.37, 0.19));

    col += texture(farStarTex, uvFarA).rgb * 0.72;
    col += texture(farStarTex, uvFarB).rgb * 0.58;
    col += texture(nearStarTex, uvNear).rgb * 0.96;

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
