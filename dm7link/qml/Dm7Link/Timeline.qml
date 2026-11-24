import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// The show as lanes, one per hour, each showing the first part of its hour. Cue marks sit at
// their time; the playhead runs along the lane the timecode is in.
Item {
    id: tl
    readonly property var head: Cues.playhead

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Timeline"
                color: Theme.text
                font.family: Theme.cond
                font.pixelSize: Theme.h2
                font.weight: Font.DemiBold
            }
            Text {
                Layout.leftMargin: 10
                Layout.fillWidth: true
                text: Cues.beyond.text || ""
                color: Theme.text3
                font.family: Theme.ui
                font.pixelSize: Theme.small + 1
                elide: Text.ElideRight
            }
            Text { text: "Lane"; color: Theme.text3; font.family: Theme.ui; font.pixelSize: Theme.small + 1 }
            SSegmented {
                implicitHeight: 28
                options: Cues.spans.map(function (s) {
                    var l = String(s.label).toLowerCase()
                    return { value: s.raw, label: l.charAt(0).toUpperCase() + l.slice(1) } })
                current: Cues.spanSet
                onPicked: value => Cues.setSpan(value)
            }
        }

        ListView {
            id: lanes
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 6
            model: Cues.lanes
            boundsBehavior: Flickable.StopAtBounds
            delegate: Item {
                id: lane
                required property var modelData
                required property int index
                width: lanes.width
                height: 46
                Column {
                    id: label
                    width: 96
                    anchors.verticalCenter: track.verticalCenter
                    Text {
                        text: lane.modelData.label
                        color: Theme.text2
                        font.family: Theme.cond
                        font.pixelSize: Theme.body + 1
                        font.weight: Font.DemiBold
                        font.features: { "tnum": 1 }
                    }
                    Text {
                        width: parent.width
                        visible: !!lane.modelData.name
                        text: lane.modelData.name || ""
                        elide: Text.ElideRight
                        color: Theme.text3
                        font.family: Theme.ui
                        font.pixelSize: Theme.small
                    }
                }
                Rectangle {
                    id: track
                    anchors.left: label.right
                    anchors.right: parent.right
                    y: 4
                    height: 24
                    radius: 3
                    color: Theme.surface
                    // ticks
                    Repeater {
                        model: 13
                        delegate: Rectangle {
                            required property int index
                            x: track.width * index / 12
                            width: 1
                            height: track.height
                            color: Theme.lineSoft
                        }
                    }
                    // cues
                    Repeater {
                        model: lane.modelData.cues
                        delegate: Rectangle {
                            required property var modelData
                            x: Math.round(track.width * modelData.pos) - 1
                            y: 3
                            width: 3
                            height: track.height - 6
                            radius: 1
                            color: modelData.missing ? Theme.bad : modelData.armed ? Theme.amber : Theme.text2
                            ToolTip.visible: cm.containsMouse
                            ToolTip.text: "Q" + modelData.number + "  " + modelData.at
                                          + (modelData.macroName ? "  ·  " + modelData.macroName : "")
                            MouseArea { id: cm; anchors.fill: parent; anchors.margins: -5; hoverEnabled: true }
                        }
                    }
                    // playhead
                    Rectangle {
                        visible: tl.head.live && tl.head.index === lane.modelData.index
                        x: Math.round(track.width * (tl.head.pos || 0)) - 1
                        y: -4
                        width: 2
                        height: track.height + 8
                        color: Theme.text
                    }
                }
                Row {
                    anchors.left: track.left
                    anchors.right: track.right
                    anchors.top: track.bottom
                    anchors.topMargin: 2
                    Repeater {
                        model: lane.modelData.ticks
                        delegate: Text {
                            required property var modelData
                            required property int index
                            width: index < 12 ? track.width / 12 : 0
                            text: modelData
                            color: Theme.text3
                            font.family: Theme.cond
                            font.pixelSize: Theme.small
                            font.features: { "tnum": 1 }
                        }
                    }
                }
            }
        }
        Text {
            visible: Cues.lanes.length === 0
            text: "Cues and the incoming timecode are drawn here."
            color: Theme.text3
            font.family: Theme.ui
            font.pixelSize: Theme.body
        }
    }
}
