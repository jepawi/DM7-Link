import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Choosing a meter for a block: a channel meter (section, metering point, channel) or a
// premium-rack plug-in's own meter (rack slot, then which of its meters).
Popup {
    id: m
    readonly property var pick: Macros.meterPicker
    readonly property string source: pick.source !== undefined ? pick.source : "channel"
    readonly property string how: pick.how !== undefined ? pick.how : "one"
    readonly property var chosen: pick.chosen !== undefined ? pick.chosen : []
    readonly property bool manyOk: pick.manyOk === true
    readonly property var vars: pick.vars !== undefined ? pick.vars : []
    readonly property string bind: pick.bind !== undefined ? pick.bind : ""
    readonly property var sections: pick.sections !== undefined ? pick.sections : []
    readonly property var taps: pick.taps !== undefined ? pick.taps : []
    readonly property int count: pick.count !== undefined ? pick.count : 0
    readonly property int index: pick.index !== undefined ? pick.index : 0
    readonly property var slots: pick.slots !== undefined ? pick.slots : []
    readonly property var rackTaps: pick.rackTaps !== undefined ? pick.rackTaps : []
    readonly property int word: pick.word !== undefined ? pick.word : -1
    readonly property bool premium: pick.section === "Premium"

    visible: Macros.pickingMeter
    onClosed: if (Macros.pickingMeter) Macros.meterCancel()
    anchors.centerIn: Overlay.overlay
    width: Math.min(Overlay.overlay ? Overlay.overlay.width - 80 : 900, 900)
    height: Math.min(Overlay.overlay ? Overlay.overlay.height - 80 : 680, 680)
    padding: 0
    modal: true
    focus: true
    background: Rectangle { color: Theme.raised; radius: Theme.radius + 2; border.width: 1; border.color: Theme.line }
    Overlay.modal: Rectangle { color: "#99000000" }

    component Label: Text {
        color: Theme.text3
        font.family: Theme.ui
        font.pixelSize: Theme.small + 1
    }

    contentItem: ColumnLayout {
        spacing: 12
        RowLayout {
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            Layout.topMargin: 18
            Text {
                Layout.fillWidth: true
                text: "Choose a meter"
                color: Theme.text
                font.family: Theme.cond
                font.pixelSize: Theme.h2 + 2
                font.weight: Font.DemiBold
            }
            SSegmented {
                options: [{ value: "channel", label: "Channel meters" }, { value: "rack", label: "Premium rack plug-in" }]
                current: m.source
                onPicked: value => Macros.meterSource(value)
            }
        }
        Text {
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            Layout.fillWidth: true
            visible: text !== ""
            text: m.pick.reading ? "Reads " + m.pick.reading : ""
            elide: Text.ElideRight
            color: Theme.text2
            font.family: Theme.ui
            font.pixelSize: Theme.body
        }

        // ---- channel meters --------------------------------------------------------
        ColumnLayout {
            visible: m.source === "channel"
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 8
            Label { text: "Section" }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: m.sections
                    delegate: SButton {
                        required property var modelData
                        compact: true
                        text: /^[A-Z][A-Z ]+$/.test(modelData.label)
                              ? modelData.label.charAt(0) + modelData.label.slice(1).toLowerCase() : modelData.label
                        kind: modelData.key === m.pick.section ? "primary" : "secondary"
                        onClicked: Macros.meterSection(modelData.key)
                    }
                }
            }
            Label { text: "Metering point" }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: m.taps
                    delegate: SButton {
                        required property var modelData
                        compact: true
                        text: modelData.label
                        kind: modelData.id === m.pick.tag ? "primary" : "secondary"
                        onClicked: Macros.meterTap(modelData.id)
                    }
                }
                Text { visible: m.taps.length === 0; text: "No meters in this section"; color: Theme.text3
                       font.family: Theme.ui; font.pixelSize: Theme.body }
            }
            RowLayout {
                spacing: 8
                Label { text: m.premium ? "Rack and slot" : "Channel" }
                SSegmented {
                    options: {
                        var o = [{ value: "one", label: "Single" }]
                        if (m.manyOk) o.push({ value: "many", label: "Multiple" })
                        o.push({ value: "variable", label: "Variable" })
                        return o
                    }
                    current: m.how
                    onPicked: value => Macros.meterHow(value)
                }
                SButton { compact: true; visible: m.how === "many"; text: "All"; onClicked: Macros.meterSpan(0, m.count - 1) }
                SButton { compact: true; visible: m.how === "many"; text: "First 8"; enabled: m.count >= 8
                          onClicked: Macros.meterSpan(0, 7) }
            }
            Flow {
                Layout.fillWidth: true
                visible: m.how === "variable"
                spacing: 6
                Repeater {
                    model: m.vars
                    delegate: SButton {
                        required property var modelData
                        compact: true
                        text: modelData
                        kind: modelData === m.bind ? "primary" : "secondary"
                        onClicked: Macros.meterBind(modelData === m.bind ? "" : modelData)
                    }
                }
                Text { visible: m.vars.length === 0; text: "No variables yet"; color: Theme.text3
                       font.family: Theme.ui; font.pixelSize: Theme.body }
            }
            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: m.how !== "variable"
                clip: true
                cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 64)))
                cellHeight: 40
                model: m.count
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: Item {
                    required property int index
                    width: grid.cellWidth
                    height: grid.cellHeight
                    readonly property bool picked: m.how === "many" ? m.chosen.indexOf(index) >= 0 : index === m.index
                    Rectangle {
                        anchors.fill: parent
                        anchors.rightMargin: 5
                        anchors.bottomMargin: 5
                        radius: Theme.radius
                        color: picked ? Theme.text : cma.containsMouse ? Theme.hover : Theme.surface
                        Text {
                            anchors.centerIn: parent
                            text: m.premium ? ("R" + (Math.floor(index / 16) + 1) + "." + (index % 16 + 1)) : (index + 1)
                            color: picked ? Theme.onLight : Theme.text
                            font.family: Theme.cond
                            font.pixelSize: Theme.body
                            font.weight: Font.DemiBold
                        }
                        MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor; onClicked: Macros.meterIndex(index) }
                    }
                }
            }
        }

        // ---- a plug-in's own meter ------------------------------------------------------
        RowLayout {
            visible: m.source === "rack"
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 16
            ColumnLayout {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                spacing: 6
                Label { text: "Rack slot" }
                ListView {
                    id: slotList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: m.slots
                    spacing: 4
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool here: modelData.rack === m.pick.rack && modelData.slot === m.pick.plug
                        width: slotList.width
                        height: 46
                        radius: Theme.radius
                        color: here ? Theme.text : sma.containsMouse ? Theme.hover : Theme.surface
                        Column {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: modelData.label + "  " + modelData.plugin; color: parent.parent.here ? Theme.onLight : Theme.text
                                   font.family: Theme.ui; font.pixelSize: Theme.body; font.weight: Font.Medium }
                            Text { text: modelData.meters > 0 ? modelData.meters + " meters" : "No meters of its own"
                                   color: parent.parent.here ? Theme.onLight : Theme.text3
                                   font.family: Theme.ui; font.pixelSize: Theme.small }
                        }
                        MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true
                                    onClicked: Macros.meterSlot(modelData.rack, modelData.slot) }
                    }
                }
                Text { visible: m.slots.length === 0
                       text: m.pick.ready === true ? "Nothing is loaded in the premium rack" : "Connect to the console"
                       color: Theme.text3; font.family: Theme.ui; font.pixelSize: Theme.body }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6
                Label { text: m.pick.plugin ? m.pick.plugin + " meters" : "Plug-in meters" }
                ListView {
                    id: tapList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    model: m.rackTaps
                    spacing: 4
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool here: modelData.word === m.word
                        width: tapList.width
                        height: 46
                        radius: Theme.radius
                        color: here ? Theme.text : tma.containsMouse ? Theme.hover : Theme.surface
                        Column {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            Text { text: modelData.name; color: parent.parent.here ? Theme.onLight : Theme.text
                                   font.family: Theme.ui; font.pixelSize: Theme.body; font.weight: Font.Medium }
                            Text { text: modelData.mkind === "gr" ? "Gain reduction" : (modelData.label || "")
                                   color: parent.parent.here ? Theme.onLight : Theme.text3
                                   font.family: Theme.ui; font.pixelSize: Theme.small }
                        }
                        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true
                                    onClicked: Macros.meterWord(modelData.word) }
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.line }
        RowLayout {
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            Layout.bottomMargin: 16
            spacing: 8
            Item { Layout.fillWidth: true }
            SButton { kind: "quiet"; text: "Cancel"; onClicked: Macros.meterCancel() }
            SButton {
                kind: "primary"
                text: "Use this meter"
                enabled: m.source === "rack" ? m.word >= 0 : m.taps.length > 0 && (m.how !== "variable" || m.bind !== "")
                onClicked: Macros.meterConfirm()
            }
        }
    }
}
