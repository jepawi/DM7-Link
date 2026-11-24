import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// CHANNELS: every desk channel that reaches SuperRack through the card, and the rack its SEL opens.
Item {
    id: v
    readonly property var cols: [
        { label: "Channel", w: 130 }, { label: "Name", w: 0.8 }, { label: Waves.card + " port", w: 120 },
        { label: "Rack", w: 280 }, { label: "Status", w: 1 }
    ]
    readonly property var rackItems: Waves.rackList.map(function (r) {
        return { label: r.name, raw: r.name,
                 hint: (r.stereo ? "Stereo" : "Mono") + (r.inputs ? " · " + r.inputs : "") }
    })

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 36
        anchors.rightMargin: 36
        anchors.topMargin: 20
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                Layout.fillWidth: true
                text: Waves.chList.length + (Waves.chList.length === 1 ? " channel" : " channels")
                      + " on the " + (Waves.card === "PY" ? "PY card" : "Dante window")
                      + "   ·   " + Waves.rackList.length + " racks in SuperRack"
                color: Theme.text2
                font.family: Theme.ui
                font.pixelSize: Theme.body
            }
            SSwitch {
                Layout.preferredWidth: 230
                text: "Follow SuperRack's patch"
                checked: Waves.followPatch
                onToggled: on => Waves.setFollowPatch(on)
            }
            SButton {
                text: "Name racks after channels"
                enabled: Waves.pcAnswering && !Waves.showMode
                onClicked: Waves.nameAllRacks()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Theme.surface
            radius: Theme.radius
            clip: true

            STableHead { id: head; width: parent.width; columns: v.cols }
            ListView {
                id: list
                anchors.top: head.bottom
                anchors.bottom: parent.bottom
                width: parent.width
                clip: true
                model: Waves.chList
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: SRow {
                    required property var modelData
                    width: list.width
                    live: modelData.live
                    SCell { width: head.colW[0]; text: modelData.label; cond: true; strong: true
                            sub: modelData.stereo ? "Stereo" : "" }
                    SCell { width: head.colW[1]; text: modelData.name; color: Theme.text2 }
                    SCell { width: head.colW[2]; text: modelData.py; cond: true; color: Theme.text2 }
                    Item {
                        width: head.colW[3]
                        height: parent.height
                        SDropdown {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 16
                            quiet: true
                            title: modelData.label + (modelData.name ? " · " + modelData.name : "")
                            items: v.rackItems
                            current: modelData.rack
                            display: modelData.rack
                            placeholder: "No rack"
                            clearLabel: "No rack"
                            textColor: modelData.missing || modelData.mismatch ? Theme.bad : Theme.text
                            onChosen: (raw, label) => Waves.setChannelRack(modelData.ch, raw)
                        }
                    }
                    SCell {
                        width: head.colW[4]
                        text: modelData.where ? modelData.where.charAt(0).toUpperCase() + modelData.where.slice(1) : ""
                        color: modelData.missing || modelData.mismatch ? Theme.bad
                               : modelData.follows ? Theme.text2 : Theme.text3
                    }
                    onDoubleClicked: {
                        var r = Waves.rackList.find(function (x) { return x.name === modelData.rack })
                        if (r) Waves.openRack(r.index)
                    }
                }
            }
            Column {
                visible: Waves.chList.length === 0
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Session.online ? "Nothing is patched to the " + (Waves.card === "PY" ? "PY card" : "Dante window")
                                         : "Connect to the console to read its patch"
                    color: Theme.text2
                    font.family: Theme.cond
                    font.pixelSize: Theme.h2
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Session.online
                    text: "Patch an insert or an output to " + (Waves.card === "PY" ? "a PY port" : "a Dante output")
                          + " on the desk and it appears here."
                    color: Theme.text3
                    font.family: Theme.ui
                    font.pixelSize: Theme.body
                }
            }
        }
        Item { Layout.preferredHeight: 8 }
    }
}
