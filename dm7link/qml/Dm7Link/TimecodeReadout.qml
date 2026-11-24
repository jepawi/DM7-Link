import QtQuick

// The timecode, the way a show clock shows it: big amber digits, the state under them.
// Dim when nothing is arriving -- the last reading stays readable but does not pretend to run.
Rectangle {
    id: r
    property bool large: false
    readonly property var tc: Cues.timecode
    readonly property string st: tc.state || "off"
    readonly property bool running: st === "running" || st === "still"
    color: Theme.surface

    readonly property string stateText: {
        switch (st) {
        case "off": return "Timecode off"
        case "closed": return tc.error ? tc.error : "Input not open"
        case "no signal": return "No signal"
        case "unlocked": return "Reading"
        case "freewheel": return "Freewheel"
        case "still": return "Parked · " + (tc.rateText || "")
        case "running": return "Locked · " + (tc.rateText || "") + (tc.direction === "backward" ? " · reverse" : "")
        }
        return st
    }

    Column {
        anchors.left: parent.left
        anchors.leftMargin: 22
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0
        Text {
            text: r.st === "off" ? "--:--:--:--" : (r.tc.text || "--:--:--:--")
            color: r.running ? Theme.amber : r.st === "freewheel" ? Qt.darker(Theme.amber, 1.25) : Theme.text3
            font.family: Theme.cond
            font.pixelSize: r.large ? 72 : 40
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            font.letterSpacing: 0.5
        }
        Row {
            spacing: 7
            width: r.width - 40
            SLamp {
                anchors.verticalCenter: parent.verticalCenter
                size: 8
                state: r.running ? "ok" : r.st === "freewheel" ? "armed" : r.st === "closed" ? "bad"
                       : r.st === "off" ? "off" : "busy"
            }
            Text {
                width: parent.width - 15
                elide: Text.ElideRight
                text: r.stateText
                color: r.st === "closed" ? Theme.bad : Theme.text2
                font.family: Theme.ui
                font.pixelSize: Theme.small + 1
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        visible: !r.large
        cursorShape: Qt.PointingHandCursor
        onClicked: Shell.setPage("timecode")
    }
}
