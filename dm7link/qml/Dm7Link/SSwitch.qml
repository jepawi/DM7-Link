import QtQuick
import QtQuick.Controls.Basic

// A setting that is on or off: the label, an optional line under it, the switch at the right.
Item {
    id: s
    property string text
    property string caption
    property bool checked
    signal toggled(bool on)
    implicitHeight: Math.max(40, col.implicitHeight + 14)
    implicitWidth: 360
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Keys.onSpacePressed: if (enabled) s.toggled(!checked)

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: knob.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
            width: parent.width
            text: s.text
            color: Theme.text
            font.family: Theme.ui
            font.pixelSize: Theme.body
            wrapMode: Text.WordWrap
        }
        Text {
            width: parent.width
            visible: s.caption !== ""
            text: s.caption
            color: Theme.text2
            font.family: Theme.ui
            font.pixelSize: Theme.small + 1
            wrapMode: Text.WordWrap
        }
    }
    Rectangle {
        id: knob
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 40; height: 22; radius: 11
        color: s.checked ? Theme.text : Theme.raised
        border.width: s.checked ? 0 : 1
        border.color: Theme.line
        Behavior on color { ColorAnimation { duration: 120 } }
        Rectangle {
            width: 16; height: 16; radius: 8
            y: 3
            x: s.checked ? parent.width - width - 3 : 3
            color: s.checked ? Theme.ground : Theme.text2
            Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: -3; radius: 14
            color: "transparent"; border.width: 2; border.color: Theme.text
            visible: s.activeFocus
        }
    }
    MouseArea {
        anchors.fill: parent
        enabled: s.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: { s.forceActiveFocus(); s.toggled(!s.checked) }
    }
}
