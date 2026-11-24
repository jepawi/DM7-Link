import QtQuick
import QtQuick.Controls.Basic

// One button. `kind`: "primary" (the one action of a view), "secondary", "quiet", "danger".
Button {
    id: b
    property string kind: "secondary"
    property bool compact: false
    property color tint: "transparent"
    implicitHeight: compact ? 28 : Theme.ctrl
    implicitWidth: Math.max(compact ? 28 : 64, contentItem.implicitWidth + (compact ? 20 : 28))
    focusPolicy: Qt.StrongFocus
    hoverEnabled: true

    font.family: Theme.ui
    font.pixelSize: compact ? Theme.small + 1 : Theme.body
    font.weight: Font.Medium

    contentItem: Text {
        text: b.text
        font: b.font
        color: !b.enabled ? Theme.text3
             : b.kind === "primary" ? Theme.onLight
             : b.kind === "danger" ? Theme.bad
             : Theme.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    background: Rectangle {
        radius: Theme.radius
        color: b.kind === "primary"
               ? (!b.enabled ? Theme.raised : b.down ? "#C9C6BF" : b.hovered ? "#FFFFFF" : Theme.text)
               : b.kind === "quiet"
                 ? (b.down ? Theme.raised : b.hovered ? Theme.raised : "transparent")
                 : (b.down ? Theme.hover : b.hovered ? Theme.raised : b.tint)
        border.width: b.kind === "secondary" || b.kind === "danger" ? 1 : 0
        border.color: b.kind === "danger" && b.enabled ? Qt.darker(Theme.bad, 1.6) : Theme.line
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: Theme.radius + 3
            color: "transparent"
            border.width: 2
            border.color: Theme.text
            visible: b.visualFocus
        }
    }
}
