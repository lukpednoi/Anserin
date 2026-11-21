#version 440

// Ultra-Lightweight 1-Tap Tinted Sprite Blit for Pooled Cloudy Sheet-Lightning Flashes.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 tintColor;
};

layout(binding = 1) uniform sampler2D spriteTex;

void main() {
    vec4 s = texture(spriteTex, qt_TexCoord0);
    fragColor = vec4(s.rgb * tintColor.rgb, s.a * tintColor.a) * qt_Opacity;
}
