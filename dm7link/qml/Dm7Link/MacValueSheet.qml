import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Fills one slot of one block. What it offers comes from the slot's target (`slotTarget`):
// a number in the parameter's own unit, a setting from its list, on/off, text, a variable name
// -- or the value of a variable, another parameter, a meter or the timecode.
Popup {
    id: s
    property string path: ""
    property string slot: ""
    property var target: ({})
    property string source: "constant"

    signal wantParameter()
    signal wantMeter()
    signal wantTimecode()

    readonly property string kind: target.kind !== undefined ? target.kind : "any"
    readonly property string pool: target.pool !== undefined ? target.pool : ""
    readonly property var allow: target.allow !== undefined ? target.allow : ["value"]
    readonly property var names: target.names !== undefined ? target.names : []
    readonly property bool field: target.field === true
    readonly property string unit: target.unit !== undefined ? target.unit : ""
    readonly property bool numeric: (kind === "number" || kind === "any") && pool === ""
    readonly property bool texty: pool === "" && (kind === "string" || kind === "words" || kind === "message")
    function allows(what) { return allow.indexOf(what) >= 0 }

    function show(p, sl, t) {
        s.target = t
        s.slot = sl
        s.path = p
        s.source = allows("value") ? "constant" : "variable"
        s.open()
    }
    function commit(payload) {
        if (s.field) Macros.setField(s.path, s.slot, payload.text !== undefined ? payload.text : "")
        else Macros.setValue(s.path, s.slot, payload)
        s.close()
    }
    function useConstant(text) {
        if (String(text).trim() === "") return
        s.commit({ "kind": "constant", "text": String(text).trim(), "unit": s.unit,
                   "plain": s.target.plain === true })
    }
    function useVariable(name) {
        if (s.field) Macros.setField(s.path, s.slot, name)
        else if (name !== "") Macros.setValue(s.path, s.slot, { "kind": "variable", "name": name })
        s.close()
    }

    anchors.centerIn: Overlay.overlay
    width: 560
    padding: 0
    modal: true
    focus: true
    onOpened: {
        newVar.text = ""
        entry.text = s.texty && s.target.currentText !== undefined ? s.target.currentText : ""
        if (entry.visible) entry.forceActiveFocus()
    }
    background: Rectangle { color: Theme.raised; radius: Theme.radius + 2; border.width: 1; border.color: Theme.line }
    Overlay.modal: Rectangle { color: "#99000000" }

    contentItem: ColumnLayout {
        spacing: 14
        Item { Layout.preferredHeight: 4 }

        // what this slot is
        ColumnLayout {
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            spacing: 3
            Text {
                Layout.fillWidth: true
                text: s.target.target ? s.target.target : (s.field ? "Value" : "Value source")
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.cond
                font.pixelSize: Theme.h2
                font.weight: Font.DemiBold
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: s.target.reading ? "Reads " + s.target.reading
                      : s.target.current ? "Now " + s.target.current : ""
                elide: Text.ElideRight
                color: Theme.text2
                font.family: Theme.ui
                font.pixelSize: Theme.small + 1
            }
            Text {
                Layout.fillWidth: true
                visible: text !== ""
                text: s.target.accepts ? "Range " + s.target.accepts : (s.unit !== "" ? "Unit " + s.unit : "")
                elide: Text.ElideRight
                color: Theme.text3
                font.family: Theme.ui
                font.pixelSize: Theme.small + 1
            }
        }

        // where the value comes from
        SSegmented {
            Layout.leftMargin: 22
            visible: s.allow.length > 1
            options: {
                var out = []
                if (s.allows("value"))
                    out.push({ value: "constant",
                               label: s.kind === "enum" ? "Setting" : s.kind === "bool" ? "State"
                                    : s.texty ? "Text" : s.kind === "name" ? "Name" : "Value" })
                if (s.allows("variable")) out.push({ value: "variable", label: "Variable" })
                if (s.allows("parameter")) out.push({ value: "parameter", label: "Parameter" })
                if (s.allows("meter")) out.push({ value: "meter", label: "Meter" })
                if (s.allows("timecode")) out.push({ value: "timecode", label: "Timecode" })
                return out
            }
            current: s.source
            onPicked: value => {
                if (value === "parameter") { s.close(); s.wantParameter() }
                else if (value === "meter") { s.close(); s.wantMeter() }
                else if (value === "timecode") { s.close(); s.wantTimecode() }
                else s.source = value
            }
        }

        // ---- a typed value: number, clock, timecode, text, a patch source -------------
        ColumnLayout {
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            spacing: 8
            visible: s.source === "constant"
                     && (s.numeric || s.kind === "clock" || s.kind === "tc" || s.texty || s.pool !== "")
            RowLayout {
                spacing: 8
                SField {
                    id: entry
                    Layout.fillWidth: true
                    mono: s.numeric || s.kind === "clock" || s.kind === "tc"
                    placeholderText: s.kind === "clock" ? "20:00"
                                   : s.kind === "tc" ? "01:00:00:00"
                                   : s.pool !== "" ? (s.pool === "channel" ? "CH 12" : "Dante 10")
                                   : s.texty ? "Text" : s.unit !== "" ? "0 " + s.unit : "0"
                    inputMask: s.kind === "tc" ? "99:99:99:99;_" : s.kind === "clock" ? "99:99;_" : ""
                    onAccepted: enter.clicked()
                }
                Text {
                    visible: s.numeric && s.unit !== ""
                    text: s.unit
                    color: Theme.text2
                    font.family: Theme.ui
                    font.pixelSize: Theme.body
                }
                SButton {
                    visible: s.kind === "tc"
                    text: "Take"
                    enabled: Macros.timecodeNow !== ""
                    onClicked: entry.text = Macros.timecodeNow
                }
                SButton {
                    visible: s.numeric && !!s.target.floor
                    text: s.target.floor || ""
                    onClicked: s.useConstant(s.target.floor)
                }
            }
            Text {
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                text: s.kind === "tc" ? (Macros.timecodeNow !== "" ? "Timecode in: " + Macros.timecodeNow : "")
                    : s.kind === "clock" ? "Hours and minutes; fires once a day"
                    : s.pool !== "" ? "As the console names it"
                    : s.numeric && s.unit === "" && s.target.plain === true ? "No unit"
                    : s.numeric && s.unit === "" ? "Takes the unit of its target" : ""
                visible: text !== ""
                color: Theme.text3
                font.family: Theme.ui
                font.pixelSize: Theme.small + 1
            }
        }

        // ---- one of a list -----------------------------------------------------------
        Flow {
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            Layout.fillWidth: true
            spacing: 6
            visible: s.source === "constant" && s.kind === "enum"
            Repeater {
                model: s.target.options !== undefined ? s.target.options : []
                delegate: SButton {
                    required property var modelData
                    text: modelData.label
                    kind: String(modelData.raw) === String(s.target.currentRaw) ? "primary" : "secondary"
                    onClicked: s.commit({ "kind": "option", "raw": modelData.raw, "label": modelData.label })
                }
            }
        }
        Row {
            Layout.leftMargin: 22
            spacing: 8
            visible: s.source === "constant" && s.kind === "bool"
            SButton { text: "On"; onClicked: s.commit({ "kind": "switch", "on": true }) }
            SButton { text: "Off"; onClicked: s.commit({ "kind": "switch", "on": false }) }
        }

        // ---- a variable: its name (a slot that names one), or its value ---------------
        ColumnLayout {
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            spacing: 8
            visible: (s.source === "constant" && s.kind === "name") || s.source === "variable"
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Repeater {
                    model: s.names
                    delegate: SButton {
                        required property var modelData
                        text: modelData
                        kind: modelData === s.target.current ? "primary" : "secondary"
                        onClicked: s.useVariable(modelData)
                    }
                }
                Text {
                    visible: s.names.length === 0
                    text: "No variables yet"
                    color: Theme.text3
                    font.family: Theme.ui
                    font.pixelSize: Theme.body
                    height: Theme.ctrl
                    verticalAlignment: Text.AlignVCenter
                }
            }
            RowLayout {
                spacing: 8
                SField {
                    id: newVar
                    Layout.fillWidth: true
                    placeholderText: "New variable"
                    onAccepted: if (text.trim() !== "") s.useVariable(text.trim())
                }
                SButton { text: "Add"; enabled: newVar.text.trim() !== ""; onClicked: s.useVariable(newVar.text.trim()) }
                SButton { kind: "quiet"; text: "None"; visible: s.target.clearable === true
                          onClicked: s.useVariable("") }
            }
        }

        // ---- the way out ------------------------------------------------------------
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.line }
        RowLayout {
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            Layout.bottomMargin: 16
            spacing: 8
            SButton {
                kind: "quiet"
                text: "Clear"
                visible: !s.field
                onClicked: { Macros.clearSlot(s.path, s.slot); s.close() }
            }
            Item { Layout.fillWidth: true }
            SButton { kind: "quiet"; text: "Cancel"; onClicked: s.close() }
            SButton {
                id: enter
                kind: "primary"
                text: "Set"
                visible: s.source === "constant"
                         && (s.numeric || s.kind === "clock" || s.kind === "tc" || s.texty || s.pool !== "")
                enabled: entry.text.replace(/[_:]/g, "").trim() !== ""
                onClicked: {
                    if (s.texty && !s.field) s.commit({ "kind": "text", "text": entry.text })
                    else if (s.texty) s.commit({ "text": entry.text })
                    else if (s.pool !== "") s.commit({ "kind": "constant", "text": entry.text.trim(),
                                                       "unit": "", "plain": false })
                    else if (s.field) s.commit({ "text": entry.text.trim() })
                    else s.useConstant(entry.text)
                }
            }
        }
    }
}
