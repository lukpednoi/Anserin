import QtQuick
import "../../"
import "../"

WallpaperBlur {
    id: root
    objectName: "glass-fillets"

    required property Rectangle card
    readonly property real margin: Math.ceil(filletRadius) + 64
    readonly property real leftMargin: margin
    readonly property real rightMargin: margin
    readonly property real topMargin: margin
    readonly property real bottomMargin: margin

    standalone: true
    earsOnly: true

    x: card.x - leftMargin
    y: card.y - topMargin
    width: card.width + leftMargin + rightMargin
    height: card.height + topMargin + bottomMargin

    topLeftRadius: card.topLeftRadius
    topRightRadius: card.topRightRadius
    bottomLeftRadius: card.bottomLeftRadius
    bottomRightRadius: card.bottomRightRadius
    boxRect: Qt.rect(leftMargin, topMargin, card.width, card.height)
    bezelSize: Math.max(5, Math.min(26, Math.min(card.width, card.height) * 0.36))
}
