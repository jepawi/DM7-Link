import QtQuick

// One table row: hover, the LIVE mark (what the desk is on now), a hairline under it.
// Cells go in a Row, sized from the table head's `colW`.
Rectangle {
    id: r
    property bool live: false
    property bool selected: false
    property bool dim: false
    default property alias cells: line.data
    signal clicked()
    signal doubleClicked()
    implicitHeight: Theme.row
    color: selected ? Theme.raised : ma.containsMouse ? Qt.lighter(Theme.ground, 1.18) : "transparent"
    opacity: dim ? 0.5 : 1

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: r.clicked()
        onDoubleClicked: r.doubleClicked()
    }
    Rectangle { width: 3; height: parent.height; color: Theme.text; visible: r.live }
    Row {
        id: line
        x: 16
        height: parent.height
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.lineSoft }
}
