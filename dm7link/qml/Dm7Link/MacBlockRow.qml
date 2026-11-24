import QtQuick

// One line of a macro: a block, an ELSE, an END, or an empty branch to click into.
// row = {form, path, kind, tone, depth, parts, ready, hint, caret}
Rectangle {
    id: r
    property var row: ({})
    property bool selected: false
    property bool caretHere: false            // the insertion line sits under this row
    signal tapped()
    signal slotTapped(string slot)

    readonly property bool flow: row.form === "else" || row.form === "end" || row.form === "empty"
    readonly property color rail: row.tone === "scene" ? Theme.ok
                                : row.tone === "set" ? Theme.text
                                : row.tone === "flow" ? Theme.text2
                                : Theme.text3

    width: parent ? parent.width : 600
    height: Math.max(40, line.implicitHeight + 12) + (caretHere ? 3 : 0)
    color: selected ? Theme.raised : ma.containsMouse ? Qt.lighter(Theme.surface, 1.12) : "transparent"

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        onClicked: r.tapped()
    }
    // depth guides
    Repeater {
        model: row.depth || 0
        delegate: Rectangle {
            required property int index
            x: 20 + index * 24
            width: 1
            height: r.height
            color: Theme.lineSoft
        }
    }
    Rectangle {
        visible: row.form === "block"
        x: 12 + (row.depth || 0) * 24
        y: 8
        width: 3
        height: r.height - 16 - (caretHere ? 3 : 0)
        radius: 1.5
        color: r.rail
        opacity: row.ready === false ? 0.4 : 1
    }
    Flow {
        id: line
        x: 24 + (row.depth || 0) * 24
        y: 6
        width: r.width - x - (unfinished.visible ? unfinished.width + 24 : 16)
        spacing: 6
        Repeater {
            model: row.parts || []
            delegate: MacChip {
                required property var modelData
                required property int index
                part: modelData
                first: index === 0
                dim: r.flow
                maxWidth: Math.max(160, line.width)
                onClicked: r.slotTapped(modelData.slot)
            }
        }
    }
    Text {
        id: unfinished
        visible: row.form === "block" && row.ready === false
        anchors.right: parent.right
        anchors.rightMargin: 16
        y: 12
        text: "Incomplete"
        color: Theme.text3
        font.family: Theme.ui
        font.pixelSize: Theme.small
    }
    // the insertion line: the next block added goes here
    Rectangle {
        visible: r.caretHere
        anchors.bottom: parent.bottom
        x: 12 + (row.form === "block" && row.caret && row.caret.indexOf(row.path + ".") === 0
                 ? ((row.depth || 0) + 1) * 24 : (row.depth || 0) * 24)
        width: r.width - x - 12
        height: 2
        color: Theme.text
    }
}
