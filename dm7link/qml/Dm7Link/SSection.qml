import QtQuick

// A titled block of a page: the heading on a hairline, an optional line under it, then content.
Column {
    id: sec
    property string title
    property string caption
    default property alias content: body.data
    property alias trailing: tail.data
    spacing: 12

    Item {
        width: parent.width
        height: Math.max(head.implicitHeight, tail.childrenRect.height)
        Column {
            id: head
            anchors.left: parent.left
            anchors.right: tail.left
            anchors.rightMargin: 12
            spacing: 3
            Text {
                text: sec.title
                color: Theme.text
                font.family: Theme.cond
                font.pixelSize: Theme.h2
                font.weight: Font.DemiBold
                font.letterSpacing: 0.2
            }
            Text {
                visible: sec.caption !== ""
                width: parent.width
                text: sec.caption
                color: Theme.text2
                font.family: Theme.ui
                font.pixelSize: Theme.small + 1
                wrapMode: Text.WordWrap
            }
        }
        Row {
            id: tail
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
        }
    }
    Rectangle { width: parent.width; height: 1; color: Theme.lineSoft }
    Column {
        id: body
        width: parent.width
        spacing: 6
    }
}
