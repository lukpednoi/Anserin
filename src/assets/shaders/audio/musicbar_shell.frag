// Unified Music Bar shell SDF: stadium pill + seamless drooping Cava wave + continuous 1px rim border.
// Drawn as ONE single C1-continuous shape so there is zero seam between the pill corners and the wave.
// Compile:
// /usr/lib/qt6/bin/qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o musicbar_shell.frag.qsb musicbar_shell.frag
#version 440

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    mat4 levels0;
    mat4 levels1;
    vec4 fillColor;
    vec4 borderColor;
    vec2 itemSize;
    float pillHeight;
    float count;
    float maxLength;
    float borderWidth;
};

int imin(int a, int b) { return a < b ? a : b; }
int imax(int a, int b) { return a > b ? a : b; }
int iclamp(int v, int lo, int hi) { return imin(imax(v, lo), hi); }

float levelAt(int i) {
    int m = i / 16;
    int k = i - m * 16;
    int row = k / 4;
    int col = k - row * 4;
    if (m == 0) return levels0[col][row];
    return levels1[col][row];
}

float waveHeight(int i) {
    return levelAt(iclamp(i, 0, int(count) - 1)) * maxLength;
}

void main() {
    vec2 p = qt_TexCoord0 * itemSize;

    // 1px outer AA padding so the top/left/right 1px border never clips at the texture edge
    float pad = 1.0;
    float W = max(pillHeight + 2.0, itemSize.x - 2.0 * pad);
    float H = pillHeight;
    float R = H * 0.5;

    // Local coordinates inside the padded pill+wave box
    float lx = p.x - pad;
    float ly = p.y - pad;

    float d;
    if (lx < R) {
        // Exact left semicircle (seamless tangent at lx = R)
        d = length(vec2(lx - R, ly - R)) - R;
    } else if (lx > W - R) {
        // Exact right semicircle (seamless tangent at lx = W - R)
        d = length(vec2(lx - (W - R), ly - R)) - R;
    } else {
        // Middle straight top + drooping Cava wave bottom
        float alongSize = max(1.0, W - 2.0 * R);
        float wx = lx - R;
        float n = count;
        int last = int(n) - 1;
        float stepX = alongSize / max(1.0, n - 1.0);

        int k = iclamp(int(floor(wx / stepX + 0.5)), 0, last);
        float hk = waveHeight(k);
        float wy;
        float slope;
        if (k == 0) {
            float m0 = (hk + waveHeight(1)) * 0.5;
            slope = (m0 - hk) / (0.5 * stepX);
            wy = hk + slope * wx;
        } else if (k == last) {
            float m = (waveHeight(last - 1) + hk) * 0.5;
            float x0 = (float(last) - 0.5) * stepX;
            slope = (hk - m) / (0.5 * stepX);
            wy = m + slope * (wx - x0);
        } else {
            float a = (waveHeight(k - 1) + hk) * 0.5;
            float b = (hk + waveHeight(k + 1)) * 0.5;
            float u = clamp((wx - (float(k) - 0.5) * stepX) / stepX, 0.0, 1.0);
            wy = (1.0 - u) * (1.0 - u) * a + 2.0 * u * (1.0 - u) * hk + u * u * b;
            slope = (2.0 * (1.0 - u) * (hk - a) + 2.0 * u * (b - hk)) / stepX;
        }

        float dTop = -ly;
        float dBot = (ly - (H + wy)) / sqrt(1.0 + slope * slope);
        d = max(dTop, dBot);
    }

    // Unified antialiased fill + continuous 1px border around the entire 360-degree silhouette
    float outerAlpha = clamp(0.5 - d, 0.0, 1.0);
    if (outerAlpha <= 0.001) discard;

    float bw = max(0.85, borderWidth);
    float innerAlpha = clamp(0.5 - (d + bw), 0.0, 1.0);
    float rimMix = clamp(outerAlpha - innerAlpha, 0.0, 1.0);

    vec3 col = mix(fillColor.rgb, mix(fillColor.rgb, borderColor.rgb, borderColor.a), rimMix);
    float a = fillColor.a * outerAlpha * qt_Opacity;
    fragColor = vec4(col * a, a);
}
