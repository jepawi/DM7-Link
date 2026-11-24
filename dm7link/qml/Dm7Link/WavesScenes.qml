import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// SCENES: what a DM7 scene recall does in SuperRack -- nothing, the snapshot of the same
// number, or the snapshot chosen here. Several scenes may share one snapshot.
Item {
    id: v
    property var picked: ({})            // label -> true
    readonly property var pickedList: Object.keys(picked).filter(function (k) { return picked[k] })
    readonly property string mode: Waves.snapMode
    readonly property var cols: [
        { label: "", w: 34 }, { label: "Scene", w: 92 }, { label: "Title", w: 1 },
        { label: "SuperRack snapshot", w: 300 }, { label: "Recall", w: 120 }, { label: "", w: 92 }
    ]
    readonly property var snapItems: Waves.snapList.map(function (s) {
        return { label: s.name, raw: s.name, hint: s.scenes ? "Scenes " + s.scenes : "" }
    })
    function toggle(label) { var p = Object.assign({}, picked); p[label] = !p[label]; picked = p }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: 36
        anchors.rightMargin: 36
        anchors.topMargin: 20
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Text {
                text: "Scene recall"
                color: Theme.text2
                font.family: Theme.ui
                font.pixelSize: Theme.body
            }
            SSegmented {
                options: [{ value: "off", label: "Off" }, { value: "number", label: "Same number" },
                          { value: "table", label: "From table" }]
                current: v.mode
                onPicked: value => Waves.setSnapMode(value)
            }
            Item { Layout.preferredWidth: 10 }
            SSegmented {
                options: [{ value: 0, label: "Bank A" }, { value: 1, label: "Bank B" }]
                current: Waves.sceneListBank
                onPicked: value => { v.picked = ({}); Waves.setSceneList(value) }
            }
            Item { Layout.fillWidth: true }
            SButton {
                text: "Match by name"
                enabled: Waves.pcAnswering
                onClicked: Waves.matchSceneNames()
            }
        }

        // what is picked can be acted on together
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: v.pickedList.length ? 48 : 0
            visible: v.pickedList.length > 0
            radius: Theme.radius
            color: Theme.raised
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 8
                spacing: 8
                Text {
                    Layout.fillWidth: true
                    text: v.pickedList.length + (v.pickedList.length === 1 ? " scene picked" : " scenes picked")
                    color: Theme.text
                    font.family: Theme.ui
                    font.pixelSize: Theme.body
                    font.weight: Font.Medium
                }
                SDropdown {
                    Layout.preferredWidth: 240
                    placeholder: "Assign a snapshot"
                    title: "Assign to " + v.pickedList.length + " scenes"
                    items: v.snapItems
                    clearLabel: "No snapshot"
                    onChosen: (raw, label) => { Waves.assignScenes(v.pickedList, raw); v.picked = ({}) }
                }
                SButton { text: "New snapshots"; enabled: Waves.pcAnswering && !Waves.showMode
                          onClicked: { Waves.newSnapshotsFor(v.pickedList); v.picked = ({}) } }
                SButton { text: "Exclude"; onClicked: { Waves.excludeScenes(v.pickedList, true); v.picked = ({}) } }
                SButton { text: "Include"; onClicked: { Waves.excludeScenes(v.pickedList, false); v.picked = ({}) } }
                SButton { kind: "quiet"; text: "Clear"; onClicked: v.picked = ({}) }
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
                model: Waves.sceneList
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: SRow {
                    id: row
                    required property var modelData
                    width: list.width
                    live: modelData.live
                    selected: !!v.picked[modelData.label]
                    dim: modelData.skipped
                    onClicked: v.toggle(modelData.label)
                    Item {
                        width: head.colW[0]; height: parent.height
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 16; height: 16; radius: 4
                            color: row.selected ? Theme.text : "transparent"
                            border.width: row.selected ? 0 : 1.5
                            border.color: Theme.text3
                            Text { anchors.centerIn: parent; text: "✓"; visible: row.selected
                                   color: Theme.onLight; font.pixelSize: 12; font.bold: true }
                        }
                    }
                    SCell { width: head.colW[1]; text: modelData.label; cond: true; strong: true
                            color: modelData.onDesk ? Theme.text : Theme.text3 }
                    SCell { width: head.colW[2]; text: modelData.title || (modelData.onDesk ? "" : "Not on the desk")
                            color: modelData.onDesk ? Theme.text2 : Theme.text3 }
                    Item {
                        width: head.colW[3]; height: parent.height
                        SDropdown {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 16
                            quiet: true
                            enabled: v.mode !== "number"
                            title: modelData.label + (modelData.title ? " · " + modelData.title : "")
                            items: v.snapItems
                            current: modelData.mapped
                            display: modelData.snapshot
                            placeholder: v.mode === "number" ? "No snapshot at this number" : "No snapshot"
                            clearLabel: "No snapshot"
                            textColor: modelData.missing ? Theme.bad : v.mode === "off" ? Theme.text3 : Theme.text
                            onChosen: (raw, label) => Waves.setSceneSnapshot(modelData.label, raw)
                        }
                    }
                    SCell {
                        width: head.colW[4]
                        text: modelData.skipped ? "Excluded" : v.mode === "off" ? "Off"
                              : modelData.missing ? "Snapshot missing" : modelData.snapshot ? "Recalls" : "—"
                        color: modelData.missing ? Theme.bad : Theme.text3
                    }
                    Item {
                        width: head.colW[5]; height: parent.height
                        SButton {
                            anchors.verticalCenter: parent.verticalCenter
                            compact: true
                            kind: "quiet"
                            text: "Test"
                            enabled: Waves.pcAnswering && !!modelData.snapshot && !modelData.skipped
                            onClicked: Waves.testScene(modelData.label)
                        }
                    }
                }
            }
            Text {
                visible: Waves.sceneList.length === 0
                anchors.centerIn: parent
                text: Session.online ? "No scenes in bank " + "AB"[Waves.sceneListBank] : "Connect to the console to read its scenes"
                color: Theme.text2
                font.family: Theme.cond
                font.pixelSize: Theme.h2
            }
        }
        Item { Layout.preferredHeight: 8 }
    }
}
