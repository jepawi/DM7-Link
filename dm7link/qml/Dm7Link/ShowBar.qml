import QtQuick
import QtQuick.Layouts

// The show bar: the chain the show runs down, left to right -- the console, the scene it is on,
// the channel selected and the rack it opens, SuperRack's snapshot and tempo -- and, at the
// end, the timecode. Visible on every page, so the one question during a show ("is everything
// where it should be?") is answered without leaving the page being worked on.
Rectangle {
    id: bar
    color: Theme.ground

    readonly property var tc: Cues.timecode
    readonly property var now: Waves.now
    readonly property var sc: Scenes.state

    component Stage: Item {
        id: st
        property string label
        property string value
        property string detail
        property string lamp: ""
        property color valueColor: Theme.text
        property bool last: false
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.minimumWidth: 120
        Layout.maximumWidth: 330
        implicitWidth: 220
        Column {
            anchors.left: parent.left
            anchors.leftMargin: 20
            anchors.right: arrow.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2
            Row {
                spacing: 7
                SLamp { visible: st.lamp !== ""; state: st.lamp; size: 8; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: st.label
                    color: Theme.text3
                    font.family: Theme.ui
                    font.pixelSize: Theme.small
                    font.weight: Font.Medium
                }
            }
            Text {
                width: parent.width
                text: st.value
                elide: Text.ElideRight
                color: st.valueColor
                font.family: Theme.cond
                font.pixelSize: 21
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                text: st.detail
                elide: Text.ElideRight
                color: Theme.text2
                font.family: Theme.ui
                font.pixelSize: Theme.small + 1
            }
        }
        // Signal flow: a hairline chevron to the next stage.
        Canvas {
            id: arrow
            visible: !st.last
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 12; height: 40
            onPaint: {
                var c = getContext("2d"); c.reset()
                c.strokeStyle = Theme.line; c.lineWidth = 1.2
                c.beginPath(); c.moveTo(2, 2); c.lineTo(10, 20); c.lineTo(2, 38); c.stroke()
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.rightMargin: 0
        spacing: 0

        Stage {
            label: "Console"
            lamp: Session.offline ? "armed" : Session.online ? "ok" : Session.busy ? "busy" : "bad"
            value: Session.offline ? "Offline"
                   : Session.online ? (Session.consoleName || "DM7") : Session.busy ? "Connecting" : "Not connected"
            detail: Session.offline ? (Session.offlineFrom === "blank" ? "Blank DM7" : (Show.desk.name || "The show’s desk"))
                    : Session.online || Session.busy ? Session.ip : (Session.message || "No console")
        }
        Stage {
            last: !Features.wavesOn
            label: "Scene" + (bar.sc.bank ? " · bank " + bar.sc.bank : "")
            value: bar.sc.number ? bar.sc.number + (bar.sc.edited ? "  edited" : "") : "—"
            valueColor: Session.online && !Session.offline ? Theme.text : Theme.text3
            detail: bar.sc.title || (Session.online ? "" : "Waiting for the console")
        }
        Stage {
            visible: Features.wavesOn
            label: "Selected"
            value: bar.now.channel ? bar.now.channel + (bar.now.name ? "  " + bar.now.name : "") : "—"
            valueColor: bar.now.channel ? Theme.text : Theme.text3
            detail: !Waves.enabled ? "Waves link off"
                    : bar.now.rack ? "Rack " + bar.now.rack + (bar.now.rackMissing ? " (not in SuperRack)" : "")
                    : bar.now.channel ? "No rack" : ""
        }
        Stage {
            visible: Features.wavesOn
            last: true
            label: "SuperRack"
            lamp: !Waves.enabled ? "off" : Waves.pcAnswering ? "ok" : "busy"
            value: !Waves.enabled ? "Off" : !Waves.pcAnswering ? "Not connected"
                   : (bar.now.snapshot || "No snapshot") + (bar.now.dirty ? "  *" : "")
            valueColor: Waves.enabled && Waves.pcAnswering ? Theme.text : Theme.text3
            detail: Waves.enabled && Waves.tempoBpm > 0 ? Waves.tempoBpm + " BPM"
                    : Waves.enabled && Waves.pcAnswering ? bar.now.peer : ""
        }

        Item { Layout.fillWidth: true; Layout.minimumWidth: 8 }

        // Show mode: SuperRack takes recalls, SEL and tempo only. Loud when on.
        Rectangle {
            visible: Features.wavesOn
            Layout.alignment: Qt.AlignVCenter
            Layout.rightMargin: 18
            implicitWidth: smText.implicitWidth + 26
            implicitHeight: 30
            radius: 15
            color: Waves.showMode ? Theme.amber : "transparent"
            border.width: Waves.showMode ? 0 : 1
            border.color: Theme.line
            Text {
                id: smText
                anchors.centerIn: parent
                text: Waves.showMode ? "Show mode" : "Show mode off"
                color: Waves.showMode ? Theme.onLight : Theme.text2
                font.family: Theme.ui
                font.pixelSize: Theme.small + 1
                font.weight: Font.DemiBold
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: Waves.toggleShowMode() }
        }

        TimecodeReadout {
            visible: Features.timecodeOn
            Layout.fillHeight: true
            Layout.preferredWidth: 300
        }
    }
}
