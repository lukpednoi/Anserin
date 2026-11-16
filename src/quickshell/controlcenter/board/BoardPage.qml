import QtQuick
import "../../"

// A board page: its cards one under another, scrolling within the page.
Flickable {
    id: page
    required property var rootObj
    required property int tabIndex
    property color accent: ThemeBackend.mauve
    default property alias cards: col.data
    property alias extras: extraHolder.data    // pickers and popups the page opens; kept out of the column
    anchors.fill: parent
    contentWidth: width
    contentHeight: col.implicitHeight + 16
    boundsBehavior: Flickable.StopAtBounds
    flickDeceleration: 3000
    clip: true
    Item { id: extraHolder; width: 0; height: 0 }
    Column {
        id: col
        width: page.width
        spacing: 12
    }
}
