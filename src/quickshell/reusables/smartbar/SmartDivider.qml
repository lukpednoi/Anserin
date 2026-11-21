import QtQuick
import "../../"

// The thin upright line between groups on a Smart bar row.
Rectangle {
    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
    width: 1
    height: Scaler.s(16)
    color: Qt.alpha(ThemeBackend.text, 0.15)
}
