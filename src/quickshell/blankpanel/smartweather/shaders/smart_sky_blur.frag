#version 440

// Full-page Atmospheric Blur + Smart Mirror Horizon shader.
// Lightweight analytical scattering & soft blurred cloud lobes (zero heavy noise loops)
// so Intel Iris Plus G1 holds 60 FPS even in 1920x1080 Fullscreen.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 res;
    float time;
    float cloudDrift;
    vec4 skyTop;
    vec4 skyMid;
    vec4 skyLow;
    vec4 groundCol;
    vec4 bodyCol;       // rgb = sun/moon tint, a = bodyShow (0..1)
    vec2 bodyPos;       // normalized (0..1) x, y of sun/moon
    float horizonY;     // normalized (0..1) horizon line position
    float daylight;     // 0 = night, 1 = day
    float sunUp;        // 1 = sun, 0 = moon
    float cloudCover;   // 0..1
    float cloudTone;    // 0 = bright white/warm, 1 = dark storm
    float mistAmt;      // 0..1
    float flashAmt;     // 0..1
    float cornerRadius; // px
};

float sdRoundRect(vec2 p, vec2 b, float r) {
    vec2 q = abs(p) - b + vec2(r);
    return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r;
}

// Smooth cheap trigonometric soft-focus bokeh/cloud field (looks like a 40px blurred sky photo)
float softCloudField(vec2 uv, float drift) {
    vec2 p = vec2(uv.x * 3.2 - drift * 0.055, uv.y * 5.0);
    float a = sin(p.x * 1.15 + sin(p.y * 1.3 + time * 0.06)) * 0.5 + 0.5;
    float b = sin(p.x * 2.15 - p.y * 0.9 - drift * 0.03 + 1.7) * 0.5 + 0.5;
    float c = cos(p.x * 0.72 + p.y * 1.8 + drift * 0.02 + 3.1) * 0.5 + 0.5;
    float blob = a * 0.45 + b * 0.35 + c * 0.20;
    return smoothstep(0.28, 0.82, blob);
}

void main() {
    vec2 uv = qt_TexCoord0;
    vec2 px = uv * res;
    float aspect = res.x / max(res.y, 1.0);

    // Rounded corner alpha mask (exact anti-aliased edge)
    float mask = 1.0;
    if (cornerRadius > 0.5) {
        vec2 halfSize = res * 0.5;
        float d = sdRoundRect(px - halfSize, halfSize, cornerRadius);
        mask = 1.0 - smoothstep(-0.75, 0.75, d);
        if (mask <= 0.001) {
            fragColor = vec4(0.0);
            return;
        }
    }

    float hY = horizonY;
    bool above = uv.y <= hY;

    // Sky normalized vertical coordinate: 0 at top, 1 at horizon
    float skyT = clamp(uv.y / max(hY, 0.001), 0.0, 1.0);
    // Reflection normalized vertical coordinate: 0 at horizon, 1 at bottom
    float refT = clamp((uv.y - hY) / max(1.0 - hY, 0.001), 0.0, 1.0);

    // Base multi-stop sky gradient
    vec3 skyCol = mix(skyTop.rgb, skyMid.rgb, smoothstep(0.0, 0.62, skyT));
    skyCol = mix(skyCol, skyLow.rgb, smoothstep(0.45, 1.0, skyT));

    // Distance to sun/moon in aspect-corrected space
    vec2 dBody = (uv - bodyPos) * vec2(aspect, 1.0);
    float distBody = length(dBody);

    // Elevation factor: 1 when body is near horizon (sunrise/sunset bloom), 0 when high
    float nearHorizon = 1.0 - smoothstep(0.0, 0.36, max(0.0, hY - bodyPos.y));
    float bodyAbove = smoothstep(-0.08, 0.04, hY - bodyPos.y);
    float bodyVis = bodyCol.a * bodyAbove;

    // Atmospheric Mie/Rayleigh glow around sun or moon (silky continuous bloom — zero ring banding!)
    float wideBloom = exp(-distBody * (sunUp > 0.5 ? 2.4 : 3.4)) * (sunUp > 0.5 ? (0.34 + 0.16 * nearHorizon) : 0.22);
    float midBloom = exp(-distBody * (sunUp > 0.5 ? 7.0 : 9.0)) * (sunUp > 0.5 ? 0.36 : 0.24);
    float tightBloom = exp(-distBody * (sunUp > 0.5 ? 16.0 : 18.0)) * (sunUp > 0.5 ? 0.42 : 0.26);

    // Horizon warm/silver lateral spread right along the horizon plane (stronger at dawn/sunset, calm at noon)
    float horizBand = exp(-abs(uv.y - hY) * 15.0);
    float horizX = exp(-abs(uv.x - bodyPos.x) * aspect * (1.35 - 0.55 * nearHorizon));
    float horizIntensity = sunUp > 0.5 ? (0.14 + 0.46 * nearHorizon) : 0.22;
    float horizGlow = horizBand * (0.20 + 0.65 * horizX * (0.45 + 0.55 * nearHorizon)) * horizIntensity;

    // Soft blurred atmospheric clouds (only above horizon, fading cleanly into the horizon haze)
    float cloudMask = smoothstep(0.0, 0.18, skyT) * (1.0 - smoothstep(0.76, 1.0, skyT));
    float cloudDensity = softCloudField(vec2(uv.x, skyT), cloudDrift) * cloudMask * cloudCover;

    vec3 cloudLight = mix(vec3(0.24, 0.29, 0.42), vec3(0.95, 0.96, 0.99), daylight);
    vec3 cloudDark = mix(vec3(0.09, 0.11, 0.17), vec3(0.42, 0.47, 0.56), daylight);
    vec3 cloudCol = mix(cloudLight, cloudDark, cloudTone);
    // Warm sunlit under-rim on blurred clouds near sunrise/sunset
    cloudCol = mix(cloudCol, bodyCol.rgb, 0.32 * nearHorizon * (1.0 - cloudTone) * sunUp * bodyVis);

    vec3 col;
    if (above) {
        col = skyCol;
        // Soft blurred atmospheric bokeh wash
        col += bodyCol.rgb * (wideBloom + midBloom + tightBloom) * bodyVis * (1.0 - 0.55 * cloudCover);
        col += mix(skyLow.rgb, bodyCol.rgb, 0.62) * horizGlow * (0.35 + 0.65 * bodyVis);
        // Blend blurred cloud layer softly
        col = mix(col, cloudCol, clamp(cloudDensity * 0.62, 0.0, 0.72));
    } else {
        // Below horizon: smoked smart-mirror glass reflection of the blurred sky
        vec3 mirrorSky = mix(skyLow.rgb, skyMid.rgb, smoothstep(0.0, 0.55, refT));
        mirrorSky = mix(mirrorSky, groundCol.rgb, smoothstep(0.06, 0.85, refT));
        // Darken into sleek smart-mirror obsidian glass so bottom typography pops crisply
        float mirrorDarken = mix(0.22, 0.36, daylight);
        col = mix(groundCol.rgb, mirrorSky * mirrorDarken, 1.0 - smoothstep(0.0, 0.95, refT) * 0.75);

        // Soft vertical light shimmer reflected straight down from the sun/moon azimuth
        float shimmerWave = sin(refT * 34.0 - time * 1.4 + sin(uv.x * 18.0)) * 0.012 * refT;
        float dxRef = abs((uv.x + shimmerWave) - bodyPos.x) * aspect;
        float spread = 0.045 + refT * 0.18 + nearHorizon * 0.06;
        float pillar = exp(-(dxRef * dxRef) / max(spread * spread, 0.0005)) * exp(-refT * 3.1);
        col += bodyCol.rgb * pillar * bodyVis * (sunUp > 0.5 ? 0.36 : 0.22) * (1.0 - 0.5 * cloudCover);

        // Soft glow bleed right under the horizon rim
        col += mix(skyLow.rgb, bodyCol.rgb, 0.45) * exp(-refT * 11.0) * (0.14 + 0.22 * horizX * bodyVis);
    }

    // Velvety low mist hovering across the horizon
    if (mistAmt > 0.005) {
        float mistBand = exp(-abs(uv.y - (hY - 0.02)) * 7.5);
        float mistWave = 0.72 + 0.28 * sin(uv.x * 5.0 - time * 0.14 + uv.y * 6.0);
        vec3 mistCol = mix(vec3(0.32, 0.38, 0.48), vec3(0.86, 0.90, 0.95), daylight);
        col = mix(col, mistCol, clamp(mistBand * mistWave * mistAmt * 0.58, 0.0, 0.65));
    }

    // Razor-thin luminous Smart Mirror Horizon Line (fades gently toward left & right edges)
    float edgeFade = smoothstep(0.0, 0.12, uv.x) * (1.0 - smoothstep(0.88, 1.0, uv.x));
    float pxDistH = abs(px.y - hY * res.y);
    float coreLine = exp(-pxDistH * 1.15);
    float softLine = exp(-pxDistH * 0.16);
    vec3 lineTint = mix(vec3(0.76, 0.85, 1.0), mix(vec3(1.0, 0.96, 0.90), bodyCol.rgb, 0.55), sunUp);
    float lineStrength = (0.34 + 0.46 * horizX * bodyVis) * edgeFade;
    col += lineTint * (coreLine * 0.42 + softLine * 0.14) * lineStrength;

    // Adaptive Smart-Mirror readability scrim:
    // Softly cools/darkens the top-most header and bottom telemetry band during bright daytime
    // so ultra-thin white typography stays effortlessly crisp in every hour & weather state.
    float topScrim = (1.0 - smoothstep(0.0, 0.32, uv.y)) * (0.18 + 0.22 * daylight);
    float botScrim = smoothstep(hY + 0.02, 1.0, uv.y) * (0.12 + 0.18 * daylight);
    float vignette = smoothstep(0.45, 1.25, length((uv - 0.5) * vec2(1.15, 1.0))) * 0.24;
    col *= (1.0 - clamp(topScrim + botScrim + vignette, 0.0, 0.52));

    // Gentle filmic highlight rolloff so midday & sunrise glow stays velvety without flat clipping
    col = col / (1.0 + col * 0.22);

    // Storm lightning illumination flash
    col = mix(col, vec3(0.92, 0.95, 1.0), clamp(flashAmt * 0.55, 0.0, 0.55));

    // Subtle filmic grain (breaks 8-bit gradient banding on smooth atmospheric skies)
    float grain = fract(sin(dot(floor(px), vec2(12.9898, 78.233))) * 43758.5453) - 0.5;
    col += grain * (1.0 / 255.0);

    fragColor = vec4(clamp(col, 0.0, 1.0) * mask, mask) * qt_Opacity;
}
