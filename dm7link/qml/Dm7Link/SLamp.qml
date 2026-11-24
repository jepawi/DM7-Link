import QtQuick

// A status lamp. state: "ok" | "busy" | "bad" | "armed" | "off"
Rectangle {
    id: l
    property string state: "off"
    property int size: 9
    width: size; height: size; radius: size / 2
    color: state === "ok" ? Theme.ok
         : state === "bad" ? Theme.bad
         : state === "armed" || state === "busy" ? Theme.amber
         : "transparent"
    border.width: state === "off" ? 1.5 : 0
    border.color: Theme.text3
    SequentialAnimation on opacity {
        running: l.state === "busy"
        loops: Animation.Infinite
        NumberAnimation { to: 0.3; duration: 520; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 520; easing.type: Easing.InOutSine }
        onRunningChanged: if (!running) l.opacity = 1
    }
}
