import QtQuick
import QtQuick.Controls.Basic

TextField {
    id: f
    property bool mono: false
    implicitHeight: Theme.ctrl
    implicitWidth: 200
    font.family: mono ? Theme.cond : Theme.ui
    font.pixelSize: mono ? Theme.label + 1 : Theme.body
    font.features: { "tnum": 1 }
    color: Theme.text
    placeholderTextColor: Theme.text3
    selectionColor: Theme.hover
    selectedTextColor: Theme.text
    leftPadding: 10
    rightPadding: 10
    verticalAlignment: TextInput.AlignVCenter
    background: Rectangle {
        radius: Theme.radius
        color: Theme.ground
        border.width: f.activeFocus ? 2 : 1
        border.color: f.activeFocus ? Theme.text : Theme.line
    }
}
