import QtQuick

// A field that shows the current choice and opens an SPicker.
Rectangle {
    id: d
    property var items: []
    property string current
    property string display
    property string placeholder: "Choose"
    property string clearLabel: ""
    property string title
    property bool quiet: false            // inside a table row: no box until hovered
    property color textColor: Theme.text
    signal chosen(string raw, string label)
    signal aboutToOpen()
    implicitHeight: quiet ? 30 : Theme.ctrl
    implicitWidth: 220
    radius: Theme.radius
    color: quiet ? (ma.containsMouse ? Theme.raised : "transparent") : Theme.ground
    border.width: quiet ? (ma.containsMouse || activeFocus ? 1 : 0) : 1
    border.color: activeFocus ? Theme.text : Theme.line
    opacity: enabled ? 1 : 0.45
    activeFocusOnTab: true
    Keys.onSpacePressed: open()
    Keys.onReturnPressed: open()

    function open() {
        if (!enabled) return
        d.aboutToOpen()
        picker.x = 0
        picker.y = d.height + 4
        picker.open()
    }
    Text {
        anchors.left: parent.left
        anchors.leftMargin: d.quiet ? 8 : 10
        anchors.right: chevron.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: d.display !== "" ? d.display : d.placeholder
        color: d.display !== "" ? d.textColor : Theme.text3
        elide: Text.ElideRight
        font.family: Theme.ui
        font.pixelSize: Theme.body
    }
    Canvas {
        id: chevron
        width: 10; height: 6
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        opacity: d.quiet && !ma.containsMouse ? 0 : 1
        onPaint: {
            var c = getContext("2d"); c.reset()
            c.strokeStyle = Theme.text2; c.lineWidth = 1.5
            c.beginPath(); c.moveTo(1, 1); c.lineTo(5, 5); c.lineTo(9, 1); c.stroke()
        }
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: d.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: { d.forceActiveFocus(); d.open() }
    }
    SPicker {
        id: picker
        width: Math.max(d.width, 280)
        items: d.items
        title: d.title
        current: d.current
        clearLabel: d.clearLabel
        onChosen: (raw, label) => d.chosen(raw, label)
    }
}
