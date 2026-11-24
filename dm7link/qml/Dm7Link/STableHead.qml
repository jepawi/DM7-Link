import QtQuick

// A table's column titles. columns = [{label, w}] -- w > 1 is pixels, w <= 1 a share of the rest.
Rectangle {
    id: h
    property var columns: []
    implicitHeight: 34
    color: "transparent"

    function widths(total) {
        var fixed = 0, share = 0
        for (var i = 0; i < columns.length; i++) {
            if (columns[i].w > 1) fixed += columns[i].w; else share += columns[i].w
        }
        var rest = Math.max(0, total - fixed)
        var out = []
        for (var j = 0; j < columns.length; j++)
            out.push(columns[j].w > 1 ? columns[j].w : (share > 0 ? rest * columns[j].w / share : 0))
        return out
    }
    readonly property var colW: widths(width - 32)

    Row {
        x: 16
        anchors.verticalCenter: parent.verticalCenter
        Repeater {
            model: h.columns
            delegate: Text {
                required property var modelData
                required property int index
                width: h.colW[index] || 0
                text: modelData.label
                elide: Text.ElideRight
                color: Theme.text3
                font.family: Theme.ui
                font.pixelSize: Theme.small
                font.weight: Font.Medium
            }
        }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.lineSoft }
}
