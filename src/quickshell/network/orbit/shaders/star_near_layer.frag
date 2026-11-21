#version 440

// Ultra-Lightweight 1-Tap Transparent Near-Star Parallax Overlay for [4/4].
// Floats directly IN FRONT of the Gargantua Black Hole wallpaper and BEHIND the 2D network layer,
// matching BubbleMonitor's dual-starfield depth with 1 single GPU texture fetch per pixel!

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float zoom;
    vec2 res;
    vec2 camPos;
};

layout(binding = 1) uniform sampler2D nearStarTex;

void main() {
    float aspect = res.x / max(res.y, 1.0);
    vec2 uv = (qt_TexCoord0 - 0.5) * vec2(aspect, 1.0);
    float panelFit = mix(1.22, 1.0, smoothstep(1.15, 1.55, aspect));
    uv *= panelFit;

    // Matches BubbleMonitor near-star depth (~0.30 parallax) with seamless infinite wrapping
    float zNorm = clamp(zoom / 0.85, 0.42, 2.25);
    float zScale = pow(zNorm, 0.36);
    vec2 p = uv / zScale + camPos * 0.30;
    vec2 tileUv = fract(p * 0.82 + vec2(0.41, 0.23));

    vec3 starRgb = texture(nearStarTex, tileUv).rgb * 0.86;
    float a = clamp(max(starRgb.r, max(starRgb.g, starRgb.b)), 0.0, 1.0);
    fragColor = vec4(starRgb, a) * qt_Opacity;
}
