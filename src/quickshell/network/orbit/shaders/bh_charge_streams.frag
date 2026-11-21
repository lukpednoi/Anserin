#version 440
// Gargantua's power-on charge (network/orbit/BlackHoleNetworkView.qml): two thick streams of light, from the top
// left and the bottom right, spiral in and melt into a glow round the black hole's rim. Each pixel finds the one
// point of each spiral at its own angle, so it costs the same however thick the light gets.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 itemSize;
    float rimR;     // the hole's rim radius now (world units)
    float farR;     // how far out the streams reach beyond it (world units)
    float level;    // 0..1, how built-up the charge is
    float time;     // seconds since the charge began
    float head;     // 0..1, how far in the light has been drawn so far
};

const float PI = 3.14159265;
const float FLAT = 0.62;              // flattened like the disk
const float SWEEP = PI * 1.15;        // how far each stream curls round

vec3 stream(vec2 p, float a0) {
    float r = length(p);
    float u = mod(atan(p.y, p.x) - a0, 2.0 * PI) / SWEEP;   // where along the stream this angle is
    if (u > 1.0) return vec3(0.0);
    float rs = rimR * 1.08 + farR * pow(1.0 - u, 1.5);
    float w = (6.0 + 50.0 * level) * (1.0 - 0.45 * u) + 1.5;
    float d = abs(r - rs);
    float core = exp(-pow(d / (w * 0.22), 2.0));
    float body = exp(-pow(d / (w * 0.55), 2.0));
    float glow = exp(-pow(d / w, 2.0));
    float flow = 0.78 + 0.22 * sin(u * 14.0 - time * (2.0 + 6.0 * level));
    float fade = smoothstep(0.0, 0.28, u) * (1.0 - smoothstep(0.55, 0.97, u)) * flow
               * (1.0 - smoothstep(head - 0.12, head, u));
    vec3 c = vec3(1.0, 0.91, 0.72) * core * (0.40 + 0.60 * level)
           + vec3(1.0, 0.67, 0.36) * body * (0.20 + 0.30 * level)
           + vec3(1.0, 0.50, 0.20) * glow * (0.08 + 0.14 * level);
    return c * fade;
}

void main() {
    vec2 p = (qt_TexCoord0 - 0.5) * itemSize;
    vec2 q = vec2(p.x, p.y / FLAT);
    vec3 c = stream(q, PI * 1.25) + stream(q, PI * 0.25);
    // the rim glows hotter as it takes the light in
    float gr = rimR * (1.9 + 0.9 * level);
    float g = (0.10 + 0.32 * level) * (1.0 - smoothstep(rimR * 0.95, gr, length(p))) * step(0.5, rimR);
    c += vec3(1.0, 0.62, 0.32) * g;
    c = min(c, vec3(1.0));
    float a = min(1.0, max(c.r, max(c.g, c.b)));
    fragColor = vec4(c, a) * qt_Opacity;
}
