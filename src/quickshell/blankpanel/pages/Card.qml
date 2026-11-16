import QtQuick
import "../../"
import "../../reusables"

// A raised surface, the tone of the Control tab's setting rows.
Rectangle {
    radius: ThemeBackend.clampedBorderRadius
    color: (tileGlass1.active ? "transparent" : Qt.darker(ThemeBackend.surface0, 1.04))
    GlassFill { id: tileGlass1; anchors.fill: parent; radius: parent.radius; tintColor: ThemeBackend.surface0; tintAmount: ThemeBackend.glassTint; sharp: true; frost: ThemeBackend.glassFrost; rim: 0.9; z: -1 }
}
