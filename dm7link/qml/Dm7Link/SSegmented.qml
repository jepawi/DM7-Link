import QtQuick

// One choice of a few: options = [{value, label}].
Rectangle {
    id: seg
    property var options: []
    property var current
    signal picked(var value)
    implicitHeight: Theme.ctrl
    implicitWidth: row.implicitWidth + 6
    radius: Theme.radius
    color: Theme.surface
    border.width: 1
    border.color: Theme.line
    opacity: enabled ? 1 : 0.45

    Row {
        id: row
        anchors.fill: parent
        anchors.margins: 3
        spacing: 2
        Repeater {
            model: seg.options
            delegate: Rectangle {
                required property var modelData
                readonly property bool on: modelData.value === seg.current
                height: row.height
                width: Math.max(56, t.implicitWidth + 24)
                radius: Theme.radius - 2
                color: on ? Theme.text : ma.containsMouse ? Theme.raised : "transparent"
                Text {
                    id: t
                    anchors.centerIn: parent
                    text: modelData.label
                    color: on ? Theme.onLight : Theme.text2
                    font.family: Theme.ui
                    font.pixelSize: Theme.small + 1
                    font.weight: on ? Font.DemiBold : Font.Medium
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: seg.enabled
                    cursorShape: Qt.PointingHandCursor
                    onClicked: seg.picked(modelData.value)
                }
            }
        }
    }
}
