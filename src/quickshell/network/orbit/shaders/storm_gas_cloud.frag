#version 440

// Baked Volumetric Storm Gas & Smoke Cloud Shader for [3/3] (`stormGasMode: true`).
// Executed ONCE into an offscreen GPU texture (`ShaderEffectSource { live: false }`, 0% runtime FBM cost!)
// Renders smoky cosmic grey & subtle warm champagne-gold volumetric gas billows woven INSIDE
// the 2x-expanded constellation network (matching Gargantua's palette, airy enough to keep stars
// & Wi-Fi labels crystal-clear, and providing dramatic smoky cloud structure for lightning flashes!).

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float layerMode; // 0.0 = back deep smoke/gas billows, 1.0 = front airy wisps over web
    vec2 res;
};

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

float astroFbm6(vec2 p) {
    float v = 0.0;
    float a = 0.50;
    float norm = 0.0;
    for (int i = 0; i < 6; i++) {
        v += a * noise(p);
        norm += a;
        p = ROT * p * 2.08 + vec2(15.7, 9.3);
        a *= 0.51;
    }
    return v / norm;
}

float billowFbm5(vec2 p) {
    float v = 0.0;
    float a = 0.50;
    float norm = 0.0;
    for (int i = 0; i < 5; i++) {
        float n = 1.0 - abs(2.0 * noise(p) - 1.0);
        n = pow(n, 1.45);
        v += a * n;
        norm += a;
        p = ROT * p * 2.14 + vec2(11.3, 21.7);
        a *= 0.50;
    }
    return v / norm;
}

vec2 sampleStormCloud(vec2 e) {
    float r = length(e);
    if (r >= 0.97) return vec2(0.0);

    // Gentle clockwise spiral swirl matching the rotating constellation
    float swirl = -0.58 * exp(-r * 1.15);
    vec2 ps = rot2(e, swirl) * 2.75;

    vec2 w = vec2(
        astroFbm6(ps * 0.65 + vec2(1.4, -0.9)),
        astroFbm6(ps * 0.65 + vec2(5.2, 3.1))
    );
    vec2 pw = ps + (w - 0.5) * 0.72;

    float body = astroFbm6(pw * 1.15 + vec2(2.3, -2.7));
    float ridge = billowFbm5(pw * 1.85 + vec2(-3.1, 4.2));
    float fine = astroFbm6(pw * 3.70 + vec2(7.8, -5.4));

    // Inner clearing around center icon + organic feathered outer edge around the 2x network
    float innerClear = smoothstep(0.09, 0.26, r);
    float plume = (body - 0.46) * 0.26;
    float outerFade = 1.0 - smoothstep(0.58, 0.89, r - plume);
    float quadSafe = 1.0 - smoothstep(0.89, 0.97, r);
    float env = clamp(innerClear * outerFade * quadSafe, 0.0, 1.0);

    // Swirling storm-bank channels so clouds have dramatic dark pockets + dense smoky banks
    float ang = atan(e.y, e.x);
    float spiralBank = 0.68 + 0.32 * sin(ang * 3.0 + r * 5.2 + (body - 0.5) * 3.0);

    float density = smoothstep(0.32, 0.78, body * 0.64 + ridge * 0.24 + fine * 0.18) * env * spiralBank;
    float wisp = smoothstep(0.36, 0.86, ridge * 0.62 + fine * 0.44) * env * spiralBank;
    return vec2(density, wisp);
}

void main() {
    vec2 e = (qt_TexCoord0 - 0.5) * 2.0;
    float r = length(e);
    if (r >= 0.975) {
        fragColor = vec4(0.0);
        return;
    }

    // Smoky cosmic grey + soft warm champagne-gold palette (Decision 3.1 = A)
    vec3 darkStormSmoke = vec3(0.065, 0.066, 0.078);
    vec3 midSilverSmoke = vec3(0.22, 0.22, 0.25);
    vec3 warmChampagne  = vec3(0.68, 0.55, 0.36);
    vec3 paleGoldEdge   = vec3(0.92, 0.84, 0.68);

    if (layerMode < 0.5) {
        // Back/Mid volumetric smoky storm banks with directional rim lighting
        vec2 s0 = sampleStormCloud(e);
        float d0 = s0.x;
        float w0 = s0.y;
        if (d0 < 0.004 && w0 < 0.004) {
            fragColor = vec4(0.0);
            return;
        }

        vec2 toCore = -e / max(r, 0.001);
        vec2 sLit = sampleStormCloud(e + toCore * 0.024);
        float rim = pow(clamp((d0 - sLit.x) * 3.8, 0.0, 1.0), 1.35) * (0.45 + 0.85 * w0);

        // Subtle warm champagne glow closer to the inner-mid ring, smoky silver-grey further out
        float warmZone = smoothstep(0.75, 0.16, r) * (0.55 + 0.45 * noise(e * 3.4));
        vec3 cloudCol = mix(midSilverSmoke, warmChampagne, warmZone * 0.56);
        vec3 smokeBase = darkStormSmoke * smoothstep(0.14, 0.72, d0);
        vec3 litGas = cloudCol * (d0 * 0.42 + w0 * 0.34) + mix(midSilverSmoke * 1.6, paleGoldEdge, 0.45 + 0.40 * warmZone) * rim * 0.68;

        vec3 rgb = clamp(smokeBase + litGas, 0.0, 1.0);
        float alpha = clamp(d0 * 0.56 + w0 * 0.22 + rim * 0.38, 0.0, 0.68);
        fragColor = vec4(rgb, alpha) * qt_Opacity;
        return;
    }

    // Layer 1 (Front): Airy translucent gossamer smoke wisps weaving softly over the constellation lines
    vec2 pf = rot2(e, -0.68 * exp(-r * 1.1)) * 3.45;
    float fBillow = billowFbm5(pf + vec2(-2.7, 4.9));
    float fDetail = astroFbm6(pf * 1.85 + vec2(5.1, -3.6));
    float innerClear = smoothstep(0.12, 0.30, r);
    float outerFade = 1.0 - smoothstep(0.56, 0.90, r - (fDetail - 0.48) * 0.22);
    float quadSafe = 1.0 - smoothstep(0.90, 0.97, r);
    float env = clamp(innerClear * outerFade * quadSafe, 0.0, 1.0);

    float wisp = pow(smoothstep(0.48, 0.92, fBillow * 0.64 + fDetail * 0.42), 2.1) * env;
    vec3 wispCol = mix(vec3(0.45, 0.47, 0.54), paleGoldEdge, smoothstep(0.70, 0.20, r) * 0.48);
    vec3 rgb = clamp(wispCol * wisp * 0.62, 0.0, 1.0);
    float alpha = clamp(wisp * 0.34, 0.0, 0.32);
    fragColor = vec4(rgb, alpha) * qt_Opacity;
}
