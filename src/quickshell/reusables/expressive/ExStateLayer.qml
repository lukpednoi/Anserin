import QtQuick

// Hover / press tint over a control: 8% on hover, 12% while pressed, faded by an effects spring.
Rectangle {
    id: sl
    property bool hovered: false
    property bool pressed: false
    ExSpring { id: s; token: "effectsFast"; target: sl.pressed ? 0.12 : (sl.hovered ? 0.08 : 0) }
    opacity: Math.max(0, s.value)
}
