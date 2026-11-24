import QtQuick
import QtQuick.Layouts

// The left rail: the wordmark, the places in use, and what state each one is in.
// A feature switched off in Settings is not listed.
Rectangle {
    id: rail
    color: Theme.surface

    readonly property string consoleLamp: Session.offline ? (Session.online ? "armed" : "bad")
                                         : Session.online ? "ok" : Session.busy ? "busy"
                                         : Session.phase === "offline" && Session.message === "" ? "off" : "bad"
    readonly property string wavesLamp: !Waves.enabled ? "off" : Waves.pcAnswering ? "ok" : "busy"
    readonly property string tcLamp: {
        var s = Cues.timecode.state || "off"
        if (s === "off") return "off"
        if (s === "running" || s === "still") return "ok"
        if (s === "freewheel") return "armed"
        if (s === "closed") return "bad"
        return "busy"
    }
    readonly property int macrosRunning: (Macros.running || []).length
    readonly property string macrosLamp: rail.macrosRunning > 0 ? "busy"
                                         : Macros.armedCount > 0 ? "armed" : "off"

    readonly property var places: {
        var out = [{ key: "console", label: "Console", lamp: rail.consoleLamp,
                     sub: Session.offline ? "Working offline"
                          : Session.online ? (Session.consoleName || Session.ip) : Session.busy ? "Connecting" : "Not connected" },
                   { key: "show", label: "Show", lamp: Show.issues.length > 0 ? "bad" : Show.modified ? "armed" : "",
                     sub: Show.name + (Show.modified ? "  ·  not saved" : "") }]
        if (Features.wavesOn)
            out.push({ key: "waves", label: "Waves", lamp: rail.wavesLamp,
                       sub: Waves.pcAnswering ? "SuperRack connected" : "Waiting for SuperRack" })
        if (Features.timecodeOn)
            out.push({ key: "timecode", label: "Timecode", lamp: rail.tcLamp,
                       sub: Cues.armedCount + " of " + Cues.cueCount + " cues armed" })
        if (Features.macrosOn)
            out.push({ key: "macros", label: "Macros", lamp: rail.macrosLamp,
                       sub: rail.macrosRunning > 0 ? rail.macrosRunning + " running"
                            : Macros.armedCount + " of " + Macros.count + " armed" })
        return out
    }

    component Place: Rectangle {
        id: pl
        property string key
        property string label
        property string sub
        property string lamp: ""
        readonly property bool on: Shell.page === key
        Layout.fillWidth: true
        Layout.preferredHeight: sub !== "" ? 60 : 48
        color: on ? Theme.raised : ma.containsMouse ? Qt.lighter(Theme.surface, 1.12) : "transparent"
        activeFocusOnTab: true
        Keys.onReturnPressed: Shell.setPage(key)
        Keys.onSpacePressed: Shell.setPage(key)
        Rectangle { width: 3; height: parent.height; color: Theme.text; visible: pl.on }
        Rectangle {
            anchors.fill: parent; anchors.margins: 2
            color: "transparent"; border.width: 2; border.color: Theme.text
            visible: pl.activeFocus
        }
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 22
            anchors.right: lampItem.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            Text {
                text: pl.label
                color: pl.on ? Theme.text : Theme.text2
                font.family: Theme.cond
                font.pixelSize: 20
                font.weight: Font.DemiBold
            }
            Text {
                visible: pl.sub !== ""
                width: parent.width
                text: pl.sub
                elide: Text.ElideRight
                color: Theme.text3
                font.family: Theme.ui
                font.pixelSize: Theme.small
            }
        }
        SLamp {
            id: lampItem
            visible: pl.lamp !== ""
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            state: pl.lamp || "off"
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Shell.setPage(pl.key)
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: 22
        anchors.bottomMargin: 14
        spacing: 0

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            Layout.leftMargin: 22
            Text {
                id: mark
                text: "DM7 Link"
                color: Theme.text
                font.family: Theme.cond
                font.pixelSize: 30
                font.weight: Font.Bold
                font.letterSpacing: -0.3
            }
            Text {
                anchors.top: mark.bottom
                anchors.topMargin: -4
                text: "Show control for Yamaha DM7"
                color: Theme.text3
                font.family: Theme.ui
                font.pixelSize: Theme.small
            }
        }
        Item { Layout.preferredHeight: 26 }

        Repeater {
            model: rail.places
            delegate: Place {
                required property var modelData
                key: modelData.key
                label: modelData.label
                sub: modelData.sub
                lamp: modelData.lamp
            }
        }

        Item { Layout.fillHeight: true }

        Place { key: "settings"; label: "Settings"; sub: "" }
        Text {
            Layout.leftMargin: 22
            Layout.topMargin: 6
            text: "Version " + Shell.version
            color: Theme.text3
            font.family: Theme.ui
            font.pixelSize: Theme.small
        }
    }
}
