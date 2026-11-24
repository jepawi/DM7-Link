import QtQuick

// A plain text cell.
Item {
    id: c
    property string text
    property string sub
    property color color: Theme.text
    property bool strong: false
    property bool cond: false
    height: parent ? parent.height : Theme.row
    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - 12
        spacing: 1
        Text {
            width: parent.width
            text: c.text
            elide: Text.ElideRight
            color: c.color
            font.family: c.cond ? Theme.cond : Theme.ui
            font.pixelSize: c.cond ? Theme.label + 1 : Theme.body
            font.weight: c.strong ? Font.DemiBold : Font.Normal
        }
        Text {
            visible: c.sub !== ""
            width: parent.width
            text: c.sub
            elide: Text.ElideRight
            color: Theme.text3
            font.family: Theme.ui
            font.pixelSize: Theme.small
        }
    }
}
