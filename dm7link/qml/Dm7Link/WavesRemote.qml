import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// SUPERRACK: SuperRack's own racks and snapshots, and its keys -- from here, without the desk.
Item {
    id: v
    property int renaming: -1
    property int pickedSnap: -1

    component Group: Row {
        property string label
        spacing: 6
        Text {
            text: parent.label
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.text3
            font.family: Theme.ui
            font.pixelSize: Theme.small + 1
            rightPadding: 4
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 36
        anchors.rightMargin: 36
        anchors.topMargin: 20
        spacing: 16
        enabled: Waves.pcAnswering
        opacity: Waves.pcAnswering ? 1 : 0.55

        // SuperRack's keys
        Flow {
            Layout.fillWidth: true
            spacing: 28
            Group {
                label: "Rack"
                SButton { compact: true; text: "Previous"; onClicked: Waves.navigate("rack", 1) }
                SButton { compact: true; text: "Next"; onClicked: Waves.navigate("rack", 0) }
            }
            Group {
                label: "Plug-in"
                SButton { compact: true; text: "Previous"; onClicked: Waves.navigate("plugin", 1) }
                SButton { compact: true; text: "Next"; onClicked: Waves.navigate("plugin", 0) }
            }
            Group {
                label: "View"
                SSegmented {
                    implicitHeight: 28
                    options: [{ value: 1, label: "Normal" }, { value: 2, label: "Rack" }, { value: 3, label: "Overview" }]
                    current: Waves.now.view || 0
                    onPicked: value => Waves.setView(value)
                }
            }
            Group {
                label: "Tempo"
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: (Waves.now.bpm || "—") + " BPM"
                    color: Theme.text
                    font.family: Theme.cond
                    font.pixelSize: Theme.label + 2
                    font.weight: Font.DemiBold
                    font.features: { "tnum": 1 }
                    rightPadding: 4
                }
                SButton { compact: true; text: "−"; width: 28; onClicked: Waves.nudgeTempo(-1) }
                SButton { compact: true; text: "+"; width: 28; onClicked: Waves.nudgeTempo(1) }
                SButton { compact: true; text: "Tap"; onClicked: Waves.tapTempo() }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 20

            // racks
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 5
                spacing: 8
                Text {
                    text: "Racks  " + Waves.rackList.length
                    color: Theme.text
                    font.family: Theme.cond
                    font.pixelSize: Theme.h2
                    font.weight: Font.DemiBold
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.surface
                    radius: Theme.radius
                    clip: true
                    STableHead {
                        id: rh
                        width: parent.width
                        columns: [{ label: "#", w: 40 }, { label: "Rack", w: 1 }, { label: "In", w: 80 },
                                  { label: "Channels", w: 0.8 }, { label: "", w: 70 }]
                    }
                    ListView {
                        id: racks
                        anchors.top: rh.bottom
                        anchors.bottom: parent.bottom
                        width: parent.width
                        clip: true
                        model: Waves.rackList
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}
                        delegate: SRow {
                            required property var modelData
                            width: racks.width
                            live: modelData.live
                            dim: modelData.muted
                            onDoubleClicked: { v.renaming = modelData.index }
                            SCell { width: rh.colW[0]; text: String(modelData.index + 1); color: Theme.text3; cond: true }
                            Item {
                                width: rh.colW[1]; height: parent.height
                                SCell { anchors.fill: parent; visible: v.renaming !== modelData.index
                                        text: modelData.name; strong: true
                                        sub: (modelData.stereo ? "Stereo" : "Mono") + (modelData.muted ? " · bypassed" : "") }
                                SField {
                                    visible: v.renaming === modelData.index
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 12
                                    height: 30
                                    text: modelData.name
                                    onVisibleChanged: if (visible) { forceActiveFocus(); selectAll() }
                                    onAccepted: { Waves.renameRack(modelData.index, text); v.renaming = -1 }
                                    Keys.onEscapePressed: v.renaming = -1
                                    onActiveFocusChanged: if (!activeFocus && v.renaming === modelData.index) v.renaming = -1
                                }
                            }
                            SCell { width: rh.colW[2]; text: modelData.inputs; color: Theme.text2 }
                            SCell { width: rh.colW[3]; text: modelData.channels; color: Theme.text2 }
                            Item {
                                width: rh.colW[4]; height: parent.height
                                SButton { anchors.verticalCenter: parent.verticalCenter; compact: true
                                          kind: "quiet"; text: "Open"; onClicked: Waves.openRack(modelData.index) }
                            }
                        }
                    }
                }
            }

            // snapshots
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 4
                spacing: 8
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: "Snapshots  " + Waves.snapList.length
                        color: Theme.text
                        font.family: Theme.cond
                        font.pixelSize: Theme.h2
                        font.weight: Font.DemiBold
                    }
                    SButton { compact: true; text: "Previous"; onClicked: Waves.stepSnapshot(-1) }
                    SButton { compact: true; text: "Next"; onClicked: Waves.stepSnapshot(1) }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Theme.surface
                    radius: Theme.radius
                    clip: true
                    STableHead {
                        id: sh
                        width: parent.width
                        columns: [{ label: "#", w: 40 }, { label: "Snapshot", w: 1 }, { label: "Scenes", w: 0.7 }]
                    }
                    ListView {
                        id: snaps
                        anchors.top: sh.bottom
                        anchors.bottom: newRow.top
                        width: parent.width
                        clip: true
                        model: Waves.snapList
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}
                        delegate: SRow {
                            required property var modelData
                            width: snaps.width
                            live: modelData.live
                            selected: v.pickedSnap === modelData.number
                            onClicked: v.pickedSnap = (v.pickedSnap === modelData.number ? -1 : modelData.number)
                            onDoubleClicked: Waves.recallSnapshot(modelData.number)
                            SCell { width: sh.colW[0]; text: String(modelData.number + 1); color: Theme.text3; cond: true }
                            SCell { width: sh.colW[1]; text: modelData.name; strong: modelData.live }
                            SCell { width: sh.colW[2]; text: modelData.scenes; color: Theme.text2 }
                        }
                    }
                    Rectangle {
                        id: newRow
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: 96
                        color: Theme.surface
                        Rectangle { width: parent.width; height: 1; color: Theme.lineSoft }
                        Column {
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 8
                            Row {
                                spacing: 6
                                SButton { compact: true; kind: "primary"; text: "Recall"; enabled: v.pickedSnap >= 0
                                          onClicked: Waves.recallSnapshot(v.pickedSnap) }
                                SButton { compact: true; text: "Store"; enabled: v.pickedSnap >= 0 && !Waves.showMode
                                          onClicked: Waves.storeSnapshot(v.pickedSnap) }
                                SButton { compact: true; kind: "danger"; text: "Delete"; enabled: v.pickedSnap >= 0 && !Waves.showMode
                                          onClicked: confirmDelete.open() }
                            }
                            RowLayout {
                                width: parent.width
                                spacing: 6
                                SField { id: newName; Layout.fillWidth: true; implicitHeight: 28; placeholderText: "New snapshot name"
                                         onAccepted: add.clicked() }
                                SButton { id: add; compact: true; text: "Add"; enabled: newName.text.trim() !== "" && !Waves.showMode
                                          onClicked: { Waves.newSnapshot(newName.text.trim()); newName.text = "" } }
                            }
                        }
                    }
                }
            }

            // what happened
            ColumnLayout {
                Layout.fillHeight: true
                Layout.preferredWidth: 280
                Layout.maximumWidth: 320
                spacing: 8
                Text {
                    text: "Activity"
                    color: Theme.text
                    font.family: Theme.cond
                    font.pixelSize: Theme.h2
                    font.weight: Font.DemiBold
                }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 10
                    model: Waves.activity
                    delegate: Row {
                        required property var modelData
                        width: ListView.view.width
                        spacing: 10
                        Text { text: modelData.time; color: Theme.text3; font.family: Theme.cond
                               font.pixelSize: Theme.body; font.features: { "tnum": 1 } }
                        Text { width: parent.width - 70; text: modelData.text; wrapMode: Text.WordWrap
                               color: Theme.text2; font.family: Theme.ui; font.pixelSize: Theme.small + 1 }
                    }
                }
            }
        }
        Item { Layout.preferredHeight: 4 }
    }

    Text {
        visible: !Waves.pcAnswering && Waves.enabled
        anchors.centerIn: parent
        text: "SuperRack is not connected"
        color: Theme.text
        font.family: Theme.cond
        font.pixelSize: Theme.h1
        font.weight: Font.DemiBold
    }

    Dialog {
        id: confirmDelete
        anchors.centerIn: parent
        modal: true
        title: ""
        width: 380
        background: Rectangle { color: Theme.raised; radius: Theme.radius + 2; border.width: 1; border.color: Theme.line }
        contentItem: Column {
            spacing: 18
            padding: 6
            Text {
                width: 340
                wrapMode: Text.WordWrap
                text: {
                    var s = Waves.snapList.find(function (x) { return x.number === v.pickedSnap })
                    return "Delete snapshot " + (s ? "“" + s.name + "”" : "") + " in SuperRack?"
                }
                color: Theme.text
                font.family: Theme.ui
                font.pixelSize: Theme.label
            }
            Row {
                spacing: 8
                SButton { kind: "danger"; text: "Delete snapshot"
                          onClicked: { Waves.deleteSnapshots([v.pickedSnap]); v.pickedSnap = -1; confirmDelete.close() } }
                SButton { kind: "quiet"; text: "Cancel"; onClicked: confirmDelete.close() }
            }
        }
    }
}
