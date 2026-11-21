pragma Singleton
import QtQuick
import Quickshell
import "../../"

// The Smart Weather style's ink: thin Noto Sans, and either pure Smart Mirror white ("mirror") or a light tint of
// the theme's colours ("theme"), as Edit panel → Weather → Smart → Tone saves it (panel.smartWeather.tone).
Singleton {
    id: root

    readonly property string toneMode: Config.getSetting("panel.smartWeather.tone", "mirror") === "theme" ? "theme" : "mirror"
    readonly property string uiFont: "Noto Sans"
    readonly property string iconFont: ThemeBackend.iconFont
    readonly property int cardRadius: Math.min(ThemeBackend.borderRadius, 20)

    readonly property color text: ThemeBackend.text
    readonly property color sapphire: ThemeBackend.sapphire

    readonly property color ink: toneMode === "theme" ? Qt.tint("#ffffff", Qt.alpha(text, 0.25)) : "#ffffff"
    readonly property color inkSoft: Qt.alpha(ink, 0.72)
    readonly property color inkMuted: Qt.alpha(ink, 0.46)
    readonly property color inkFaint: Qt.alpha(ink, 0.24)
    readonly property color hairline: toneMode === "theme" ? Qt.alpha(accent, 0.28) : Qt.rgba(1, 1, 1, 0.18)
    readonly property color hairlineStrong: toneMode === "theme" ? Qt.alpha(accent, 0.52) : Qt.rgba(1, 1, 1, 0.34)
    readonly property color accent: toneMode === "theme" ? readableAccent(ThemeBackend.mauve, ThemeBackend.peach) : "#ffffff"

    function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }
    function readableAccent(preferred, fallback) { return lum(preferred) < 0.36 ? fallback : preferred; }
}
