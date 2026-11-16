#version 440

// Water filled to a level, with rolling waves across its surface: a front layer and a fainter back layer
// moving the other way. Every time term is a whole multiple of `phase`, so a 0..2π loop never jumps.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float radius;
    float fillLevel;
    float waveAmp;
    vec2 itemSize;
    float phase;
    vec4 color1;
    vec4 color2;
    vec4 backColor;
};

const float TAU = 6.283185307179586;

float sdRoundedBox(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

void main() {
    if (fillLevel <= 0.0001) {
        fragColor = vec4(0.0);
        return;
    }

    vec2 p = qt_TexCoord0 * itemSize;
    vec2 halfSize = itemSize * 0.5;
    float r = clamp(radius, 0.0, min(halfSize.x, halfSize.y));
    float boxAlpha = clamp(0.5 - sdRoundedBox(p - halfSize, halfSize, r), 0.0, 1.0);

    float fillY = itemSize.y * (1.0 - fillLevel);
    float u = p.x / max(itemSize.x, 1.0);
    float amp = fillLevel >= 0.999 ? 0.0 : waveAmp;

    float front = fillY + amp * (0.65 * sin(TAU * 1.3 * u + phase) + 0.35 * sin(TAU * 2.6 * u - 2.0 * phase + 1.7));
    float back = fillY - amp * 0.5 + amp * 0.8 * sin(TAU * 0.9 * u - phase + 2.4);

    float frontA = clamp(0.5 - (front - p.y), 0.0, 1.0);
    float backA = clamp(0.5 - (back - p.y), 0.0, 1.0);

    vec4 col = mix(color1, color2, clamp(p.y / max(itemSize.y, 1.0), 0.0, 1.0));
    vec4 outCol = vec4(backColor.rgb * backColor.a, backColor.a) * backA;
    outCol = mix(outCol, vec4(col.rgb * col.a, col.a), frontA);
    fragColor = outCol * boxAlpha * qt_Opacity;
}
