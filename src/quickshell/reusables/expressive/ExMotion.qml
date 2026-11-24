pragma Singleton
import QtQuick

// Motion tokens for the expressive controls (after Material 3 Expressive, as Iridium uses them): springs, not
// fixed durations. "spatial" springs move things and may overshoot; "effects" springs fade or tint and never do.
// stiffness k and damping ratio zeta of a mass-1 spring.
QtObject {
    // [stiffness, damping ratio]
    readonly property var springs: ({
        spatialFast: [800, 0.6], spatialDefault: [380, 0.8], spatialSlow: [200, 0.8],
        effectsFast: [3800, 1.0], effectsDefault: [1600, 1.0], effectsSlow: [800, 1.0]
    })
    // a global knob for how lively the whole set is (0 = no overshoot at all, 1 = as designed, 1.5 = bouncier)
    property real bounce: 1.0
    function stiffness(token) { return springs[token][0] }
    function damping(token) {
        const z = springs[token][1];
        return token.indexOf("spatial") === 0 ? Math.max(0.25, Math.min(1, 1 - (1 - z) * bounce)) : z;
    }
    // the same springs for Qt's SpringAnimation (spring, damping)
    function qtSpring(token) { return stiffness(token) / 79.4 }
    function qtDamping(token) { return 2 * damping(token) * Math.sqrt(stiffness(token)) / 75.4 * 0.93 }

    readonly property int fast: 150
    readonly property int normal: 220
    readonly property int slow: 320
}
