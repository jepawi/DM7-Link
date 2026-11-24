import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Layouts

// MACROS: the console's own automation, written as blocks that read as sentences.
// The list on the left; the open macro -- what starts it, and its blocks -- in the middle.
// Every slot is filled by clicking its chip. RECORD is what the macros did, and the variables.
Item {
    id: page
    property string view: "edit"                  // edit | record
    property var shut: ({})                       // folders collapsed in the list

    readonly property var macro: Macros.current
    readonly property string macroId: macro.id !== undefined ? macro.id : ""
    readonly property bool running: Macros.running.indexOf(page.macroId) >= 0
    readonly property var report: Macros.problems
    readonly property bool reporting: report.items !== undefined && report.items.length > 0

    function sentence(t) {
        t = String(t)
        if (!/^[A-Z][A-Z ]+$/.test(t)) return t
        var low = t.toLowerCase()
        return low.charAt(0).toUpperCase() + low.slice(1)
    }
    // A line the engine wrote with its keywords in capitals ("ON RECALL OF 10"), as prose.
    function prose(t) {
        t = String(t).replace(/\b[A-Z]{2,}(?: [A-Z]{2,})*\b/g, function (w) { return w.toLowerCase() })
        return t.charAt(0).toUpperCase() + t.slice(1)
    }
    function localPath(url) {
        var s = url.toString()
        if (s.indexOf("file://") === 0) s = s.substring(7)
        if (/^\/[A-Za-z]:\//.test(s)) s = s.substring(1)          // file:///C:/... on Windows
        return decodeURIComponent(s)
    }

    // ---- what a click on a chip opens ---------------------------------------------------
    function editSlot(path, slot) {
        var target = Macros.slotTarget(path, slot)
        if (target.kind === "dir") {
            Macros.setField(path, slot, target.other)
            return
        }
        if (target.kind === "op") {
            var items = []
            for (var i = 0; i < target.options.length; i++)
                items.push({ "label": page.sentence(target.options[i].label),
                             "hint": target.options[i].hint !== undefined ? target.options[i].hint : "",
                             "raw": String(target.options[i].raw) })
            ops.path = path
            ops.slot = slot
            ops.title = target.title !== undefined ? page.sentence(target.title) : "Choose"
            ops.current = target.current !== undefined ? String(target.current) : ""
            ops.items = items
            ops.open()
            return
        }
        if (slot === "ref") {
            Macros.pickStart(path, slot)
            return
        }
        sheet.show(path, slot, target)
    }

    // the macro list as rows: folder headings, then their macros while open
    readonly property var listRows: {
        var out = []
        var groups = Macros.groups
        for (var g = 0; g < groups.length; g++) {
            var grp = groups[g]
            var key = grp.folder !== "" ? grp.folder : "\u0000"
            var open = page.shut[key] !== true
            if (grp.folder !== "" || groups.length > 1)
                out.push({ "type": "folder", "folder": grp.folder, "count": grp.count,
                           "armed": grp.armed, "open": open, "key": key })
            if (open)
                for (var i = 0; i < grp.macros.length; i++)
                    out.push({ "type": "macro", "m": grp.macros[i] })
        }
        return out
    }

    // Screenshots: `--page macros --section edit|record|pick` opens straight on that view.
    Component.onCompleted: {
        if (Shell.page !== "macros" || initialSection === "") return
        if (initialSection === "record") { page.view = "record"; return }
        if (Macros.count > 0) Macros.openMacro(Macros.macros[0].id)
        if (initialSection === "value") Qt.callLater(function () { page.editSlot("0", "value") })
        if (initialSection === "pick") Qt.callLater(function () { Macros.pickStart("0", "ref") })
        if (initialSection === "meter") Qt.callLater(function () { Macros.meterStart("t0", "cond.left") })
    }

    Keys.onPressed: event => {
        if (page.view !== "edit" || Macros.selection === "") return
        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            Macros.removeBlock(); event.accepted = true
        } else if (event.key === Qt.Key_Up && (event.modifiers & Qt.ControlModifier)) {
            Macros.moveBlock(-1); event.accepted = true
        } else if (event.key === Qt.Key_Down && (event.modifiers & Qt.ControlModifier)) {
            Macros.moveBlock(1); event.accepted = true
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---- tabs and the page's own actions ---------------------------------------------
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            Row {
                x: 36
                anchors.bottom: parent.bottom
                spacing: 28
                Repeater {
                    model: [{ key: "edit", label: "Macros" },
                            { key: "record", label: Macros.errorCount > 0 ? "Record  " + Macros.errorCount : "Record" }]
                    delegate: Item {
                        required property var modelData
                        readonly property bool on: page.view === modelData.key
                        width: tl.implicitWidth
                        height: 42
                        Text {
                            id: tl
                            text: modelData.label
                            color: parent.on || tma.containsMouse ? Theme.text : Theme.text2
                            font.family: Theme.cond
                            font.pixelSize: 19
                            font.weight: parent.on ? Font.DemiBold : Font.Medium
                        }
                        Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2
                                    color: parent.on ? Theme.text : "transparent" }
                        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { page.view = modelData.key; if (modelData.key === "record") Macros.seenLog() } }
                    }
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 36
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 8
                    text: Macros.armedCount + " of " + Macros.count + " armed"
                          + (Macros.running.length ? "   ·   " + Macros.running.length + " running" : "")
                    color: Macros.armedCount || Macros.running.length ? Theme.amber : Theme.text3
                    font.family: Theme.ui
                    font.pixelSize: Theme.body
                }
                SButton { kind: "danger"; text: "Stop all"; visible: Macros.running.length > 0
                          onClicked: Macros.stopAll() }
                SButton { text: "Import from file"; onClicked: importDialog.open() }
                SButton { text: "Export all"; enabled: Macros.count > 0
                          onClicked: { exportDialog.which = ""; exportDialog.open() } }
                SButton { kind: "primary"; text: "New macro"
                          onClicked: { Macros.newMacro(""); page.view = "edit" } }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.lineSoft }
        }

        // ---- what the macros just said ---------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 36
            Layout.rightMargin: 36
            Layout.topMargin: 12
            Layout.preferredHeight: Macros.note !== "" ? 40 : 0
            visible: Macros.note !== ""
            radius: Theme.radius
            color: Macros.noteTone === "error" ? Theme.badDim : Macros.noteTone === "warn" ? Theme.amberDim : Theme.raised
            Text {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.right: closeNote.left
                anchors.verticalCenter: parent.verticalCenter
                text: Macros.note
                elide: Text.ElideRight
                color: Theme.text
                font.family: Theme.ui
                font.pixelSize: Theme.body
            }
            SButton { id: closeNote; anchors.right: parent.right; anchors.rightMargin: 6
                      anchors.verticalCenter: parent.verticalCenter; compact: true; kind: "quiet"; text: "✕"
                      onClicked: Macros.dismissNote() }
        }

        // ---- a macro that would not run: what to fix -------------------------------------
        Rectangle {
            Layout.fillWidth: true
            Layout.leftMargin: 36
            Layout.rightMargin: 36
            Layout.topMargin: 12
            visible: page.reporting
            Layout.preferredHeight: visible ? probCol.implicitHeight + 24 : 0
            radius: Theme.radius
            color: Theme.badDim
            border.width: 1
            border.color: Qt.darker(Theme.bad, 1.6)
            Column {
                id: probCol
                x: 16; y: 12
                width: parent.width - 32
                spacing: 6
                RowLayout {
                    width: parent.width
                    Text {
                        Layout.fillWidth: true
                        text: "“" + (page.report.name || "") + "” cannot be " + (page.report.what || "armed")
                              + " — " + (page.report.items ? page.report.items.length : 0)
                              + ((page.report.items && page.report.items.length === 1) ? " problem" : " problems")
                        color: Theme.text
                        font.family: Theme.ui
                        font.pixelSize: Theme.body
                        font.weight: Font.DemiBold
                    }
                    SButton { compact: true; kind: "quiet"; text: "Dismiss"; onClicked: Macros.dismissProblems() }
                }
                Repeater {
                    model: page.report.items || []
                    delegate: Text {
                        required property var modelData
                        width: probCol.width
                        wrapMode: Text.WordWrap
                        text: (modelData.where ? modelData.where + ": " : "") + modelData.why
                        color: pma.containsMouse ? Theme.text : Theme.text2
                        font.family: Theme.ui
                        font.pixelSize: Theme.small + 1
                        font.underline: pma.containsMouse
                        MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { page.view = "edit"; Macros.revealBlock(page.report.id, modelData.path) } }
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: 16
            currentIndex: page.view === "record" ? 1 : 0

            // ================================================================== EDIT
            RowLayout {
                spacing: 20

                // ---- the list ------------------------------------------------------------
                Rectangle {
                    Layout.leftMargin: 36
                    Layout.preferredWidth: 320
                    Layout.fillHeight: true
                    Layout.bottomMargin: 20
                    color: Theme.surface
                    radius: Theme.radius
                    clip: true
                    ListView {
                        id: macroList
                        anchors.fill: parent
                        clip: true
                        model: page.listRows
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar {}
                        delegate: Loader {
                            required property var modelData
                            width: macroList.width
                            sourceComponent: modelData.type === "folder" ? folderRow : macroRow
                            property var row: modelData
                        }
                    }
                    Column {
                        visible: Macros.count === 0
                        anchors.centerIn: parent
                        spacing: 6
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "No macros"
                               color: Theme.text2; font.family: Theme.cond; font.pixelSize: Theme.h2 }
                        Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Create one with New macro."
                               color: Theme.text3; font.family: Theme.ui; font.pixelSize: Theme.body }
                    }
                }

                // ---- the open macro --------------------------------------------------------
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.rightMargin: 36
                    Layout.bottomMargin: 20

                    Column {
                        visible: !Macros.hasOpen
                        y: 40
                        spacing: 8
                        Text { text: "No macro open"; color: Theme.text; font.family: Theme.cond
                               font.pixelSize: Theme.h1; font.weight: Font.DemiBold }
                        Text { text: "Choose one from the list, or create a new one."
                               color: Theme.text2; font.family: Theme.ui; font.pixelSize: Theme.body }
                    }

                    ColumnLayout {
                        visible: Macros.hasOpen
                        anchors.fill: parent
                        spacing: 14

                        // name, folder, armed, run
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            SField {
                                id: nameField
                                Layout.fillWidth: true
                                Layout.maximumWidth: 380
                                implicitHeight: 40
                                font.family: Theme.cond
                                font.pixelSize: 22
                                font.weight: Font.DemiBold
                                text: page.macro.name || ""
                                onEditingFinished: if (text.trim() !== "" && text !== page.macro.name) Macros.renameMacro(text)
                                Connections { target: Macros
                                              function onScriptChanged() { if (!nameField.activeFocus) nameField.text = page.macro.name || "" } }
                            }
                            SDropdown {
                                Layout.preferredWidth: 190
                                title: "Folder"
                                placeholder: "No folder"
                                display: page.macro.folder || ""
                                current: page.macro.folder || ""
                                clearLabel: "No folder"
                                items: Macros.folders.map(function (f) { return { label: f, raw: f } })
                                       .concat([{ label: "New folder…", raw: "\u0001new" }])
                                onChosen: (raw, label) => {
                                    if (raw === "\u0001new")
                                        textDialog.ask("New folder", "", "Show, Monitors, Rehearsal", "Move")
                                    else Macros.setFolder(page.macroId, raw)
                                }
                            }
                            Item { Layout.fillWidth: true }
                            // armed: the macro's triggers are watched
                            Rectangle {
                                implicitWidth: armText.implicitWidth + 50
                                implicitHeight: Theme.ctrl
                                radius: Theme.ctrl / 2
                                color: page.macro.armed ? Theme.amber : "transparent"
                                border.width: page.macro.armed ? 0 : 1
                                border.color: Theme.line
                                Rectangle {
                                    x: 10; anchors.verticalCenter: parent.verticalCenter
                                    width: 12; height: 12; radius: 6
                                    color: page.macro.armed ? Theme.onLight : "transparent"
                                    border.width: page.macro.armed ? 0 : 1.5
                                    border.color: Theme.text3
                                }
                                Text {
                                    id: armText
                                    x: 30; anchors.verticalCenter: parent.verticalCenter
                                    text: page.macro.armed ? "Armed" : "Not armed"
                                    color: page.macro.armed ? Theme.onLight : Theme.text2
                                    font.family: Theme.ui; font.pixelSize: Theme.body; font.weight: Font.Medium
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: Macros.armMacro(page.macroId, !page.macro.armed) }
                            }
                            SButton {
                                kind: page.running ? "danger" : "primary"
                                text: page.running ? "Stop" : "Run"
                                onClicked: page.running ? Macros.stopMacro(page.macroId) : Macros.runMacro(page.macroId)
                            }
                            SButton { text: "Export"; onClicked: { exportDialog.which = page.macroId; exportDialog.open() } }
                            SButton { kind: "danger"; text: "Delete"; onClicked: confirmDelete.open() }
                        }

                        // what starts it
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: trigCol.implicitHeight + 20
                            color: Theme.surface
                            radius: Theme.radius
                            Column {
                                id: trigCol
                                x: 0; y: 10
                                width: parent.width
                                spacing: 4
                                RowLayout {
                                    x: 16
                                    width: parent.width - 32
                                    Text {
                                        Layout.fillWidth: true
                                        text: Macros.triggers.length === 0 ? "Starts with Run only" : "Starts when"
                                        color: Theme.text
                                        font.family: Theme.cond
                                        font.pixelSize: Theme.h2
                                        font.weight: Font.DemiBold
                                    }
                                    SDropdown {
                                        Layout.preferredWidth: 200
                                        implicitHeight: 30
                                        title: "What starts this macro"
                                        placeholder: "Add a trigger"
                                        items: Macros.triggerKinds.map(function (t) {
                                            return { label: page.sentence(t.label), raw: t.kind, hint: "" } })
                                        onChosen: (raw, label) => Macros.addTrigger(raw)
                                    }
                                }
                                Repeater {
                                    model: Macros.triggers
                                    delegate: Item {
                                        id: trigItem
                                        required property var modelData
                                        readonly property int tIndex: modelData.index
                                        width: trigCol.width
                                        height: trigFlow.implicitHeight + 12
                                        Flow {
                                            id: trigFlow
                                            x: 24
                                            y: 6
                                            width: parent.width - 80
                                            spacing: 6
                                            Repeater {
                                                model: modelData.parts
                                                delegate: MacChip {
                                                    required property var modelData
                                                    required property int index
                                                    part: modelData
                                                    first: index === 0
                                                    maxWidth: Math.max(160, trigFlow.width)
                                                    onClicked: page.editSlot("t" + trigItem.tIndex, modelData.slot)
                                                }
                                            }
                                        }
                                        SButton {
                                            anchors.right: parent.right
                                            anchors.rightMargin: 12
                                            y: 6
                                            compact: true; kind: "quiet"; text: "✕"
                                            onClicked: Macros.removeTrigger(modelData.index)
                                        }
                                    }
                                }
                            }
                        }

                        // the blocks
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Text {
                                text: "Blocks"
                                color: Theme.text
                                font.family: Theme.cond
                                font.pixelSize: Theme.h2
                                font.weight: Font.DemiBold
                            }
                            Text {
                                Layout.leftMargin: 6
                                Layout.fillWidth: true
                                text: page.macro.unfinished > 0
                                      ? page.macro.unfinished + (page.macro.unfinished === 1 ? " slot to fill" : " slots to fill")
                                      : page.macro.blocks > 0 ? "Run top to bottom" : ""
                                color: Theme.text3
                                font.family: Theme.ui
                                font.pixelSize: Theme.small + 1
                            }
                            SDropdown {
                                Layout.preferredWidth: 190
                                implicitHeight: 30
                                title: "Add at the line"
                                placeholder: "Add a block"
                                items: Macros.palette.map(function (b) {
                                    return { label: page.sentence(b.label), raw: b.kind, hint: "" } })
                                onChosen: (raw, label) => Macros.addBlock(raw)
                            }
                            SButton { compact: true; text: "Up"; enabled: Macros.selection !== ""; onClicked: Macros.moveBlock(-1) }
                            SButton { compact: true; text: "Down"; enabled: Macros.selection !== ""; onClicked: Macros.moveBlock(1) }
                            SButton { compact: true; kind: "danger"; text: "Remove"; enabled: Macros.selection !== ""
                                      onClicked: Macros.removeBlock() }
                        }
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: Theme.surface
                            radius: Theme.radius
                            clip: true
                            Rectangle {                    // the line, before the first block
                                visible: Macros.caret === ":0"
                                x: 12; y: 4
                                width: parent.width - 24
                                height: 2
                                color: Theme.text
                                z: 2
                            }
                            ListView {
                                id: blocks
                                anchors.fill: parent
                                anchors.topMargin: 8
                                clip: true
                                model: Macros.rows
                                boundsBehavior: Flickable.StopAtBounds
                                ScrollBar.vertical: ScrollBar {}
                                delegate: MacBlockRow {
                                    required property var modelData
                                    width: blocks.width
                                    row: modelData
                                    selected: modelData.path !== "" && modelData.path === Macros.selection
                                              && modelData.form === "block"
                                    caretHere: modelData.caret === Macros.caret
                                    onTapped: { page.forceActiveFocus(); Macros.selectRow(modelData.path, modelData.caret) }
                                    onSlotTapped: slot => {
                                        Macros.selectRow(modelData.path, modelData.caret)
                                        page.editSlot(modelData.path, slot)
                                    }
                                }
                            }
                            Text {
                                visible: Macros.rows.length === 0
                                anchors.centerIn: parent
                                text: "No blocks yet. Add one with Add a block."
                                color: Theme.text3
                                font.family: Theme.ui
                                font.pixelSize: Theme.body
                            }
                        }
                        // the block that is selected, in words
                        Text {
                            Layout.fillWidth: true
                            visible: text !== ""
                            elide: Text.ElideRight
                            text: {
                                var f = Macros.focus
                                if (f.path === undefined) return ""
                                var bits = []
                                if (f.control) bits.push(f.control + (f.reading ? " reads " + f.reading : ""))
                                if (f.accepts) bits.push("range " + f.accepts)
                                return bits.length ? bits.join("   ·   ") : (f.hint || "")
                            }
                            color: Theme.text2
                            font.family: Theme.ui
                            font.pixelSize: Theme.small + 1
                        }
                    }
                }
            }

            // ================================================================== RECORD
            RowLayout {
                spacing: 20
                ColumnLayout {
                    Layout.leftMargin: 36
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.bottomMargin: 20
                    spacing: 8
                    RowLayout {
                        Text { Layout.fillWidth: true; text: "What the macros did"; color: Theme.text
                               font.family: Theme.cond; font.pixelSize: Theme.h2; font.weight: Font.DemiBold }
                        SButton { compact: true; kind: "quiet"; text: "Clear"; enabled: Macros.record.length > 0
                                  onClicked: Macros.clearLog() }
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Theme.surface
                        radius: Theme.radius
                        clip: true
                        ListView {
                            id: log
                            anchors.fill: parent
                            anchors.margins: 12
                            clip: true
                            spacing: 6
                            model: Macros.record
                            onCountChanged: positionViewAtEnd()
                            ScrollBar.vertical: ScrollBar {}
                            delegate: Row {
                                required property var modelData
                                width: log.width
                                spacing: 12
                                Text { text: modelData.at; color: Theme.text3; font.family: Theme.cond
                                       font.pixelSize: Theme.body; font.features: { "tnum": 1 } }
                                SLamp { anchors.verticalCenter: parent.verticalCenter; size: 7
                                        state: modelData.tone === "error" ? "bad" : modelData.tone === "warn" ? "armed" : "off" }
                                Text { width: parent.width - 120; text: modelData.text; wrapMode: Text.WordWrap
                                       color: modelData.tone === "error" ? Theme.bad : Theme.text2
                                       font.family: Theme.ui; font.pixelSize: Theme.body }
                            }
                        }
                        Text { visible: Macros.record.length === 0; anchors.centerIn: parent
                               text: "Nothing has run yet"; color: Theme.text3
                               font.family: Theme.ui; font.pixelSize: Theme.body }
                    }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                        text: "A run stops after " + Macros.limits.steps + " steps, " + Macros.limits.writes
                              + " changes or " + Macros.limits.seconds + " s."
                        color: Theme.text3
                        font.family: Theme.ui
                        font.pixelSize: Theme.small + 1
                    }
                }
                ColumnLayout {
                    Layout.preferredWidth: 420
                    Layout.maximumWidth: 460
                    Layout.fillHeight: true
                    Layout.rightMargin: 36
                    Layout.bottomMargin: 20
                    spacing: 8
                    Text { text: "Variables"; color: Theme.text; font.family: Theme.cond
                           font.pixelSize: Theme.h2; font.weight: Font.DemiBold }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: Theme.surface
                        radius: Theme.radius
                        clip: true
                        STableHead { id: vh; width: parent.width
                                     columns: [{ label: "Name", w: 0.8 }, { label: "Value", w: 1 }, { label: "", w: 40 }] }
                        ListView {
                            id: vars
                            anchors.top: vh.bottom
                            anchors.bottom: parent.bottom
                            width: parent.width
                            clip: true
                            model: Macros.variables
                            delegate: SRow {
                                required property var modelData
                                width: vars.width
                                live: modelData.fresh
                                SCell { width: vh.colW[0]; text: modelData.name; strong: true }
                                SCell { width: vh.colW[1]; text: modelData.value + (modelData.unit && modelData.value.indexOf(modelData.unit) < 0 ? " " + modelData.unit : "")
                                        sub: modelData.from ? "from " + modelData.from : "" }
                                Item { width: vh.colW[2]; height: parent.height
                                       SButton { anchors.verticalCenter: parent.verticalCenter; compact: true; kind: "quiet"
                                                 text: "✕"; onClicked: Macros.deleteVariable(modelData.name) } }
                            }
                        }
                        Text { visible: Macros.variables.length === 0; anchors.centerIn: parent
                               text: "No variables"; color: Theme.text3; font.family: Theme.ui; font.pixelSize: Theme.body }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        SField { id: varName; Layout.fillWidth: true; placeholderText: "New variable"
                                 onAccepted: addVar.clicked() }
                        SButton { id: addVar; text: "Add"; enabled: varName.text.trim() !== ""
                                  onClicked: { Macros.newVariable(varName.text.trim()); varName.text = "" } }
                    }
                }
            }
        }
    }

    // ---- list rows ------------------------------------------------------------------------
    Component {
        id: folderRow
        Rectangle {
            height: 38
            color: fma.containsMouse ? Theme.hover : Theme.raised
            Text {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                text: (row.open ? "▾  " : "▸  ") + (row.folder !== "" ? row.folder : "No folder")
                color: Theme.text
                font.family: Theme.cond
                font.pixelSize: Theme.label + 1
                font.weight: Font.DemiBold
            }
            Text {
                anchors.right: ren.visible ? ren.left : parent.right
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: row.count + (row.armed ? "  ·  " + row.armed + " armed" : "")
                color: row.armed ? Theme.amber : Theme.text3
                font.family: Theme.ui
                font.pixelSize: Theme.small + 1
            }
            MouseArea {
                id: fma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { var s = Object.assign({}, page.shut); s[row.key] = row.open; page.shut = s }
            }
            SButton {
                id: ren
                visible: row.folder !== "" && fma.containsMouse
                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                compact: true
                kind: "quiet"
                text: "Rename"
                onClicked: { textDialog.folder = row.folder
                             textDialog.ask("Rename folder", row.folder, "Empty takes its macros out of the folder", "Rename") }
            }
        }
    }
    Component {
        id: macroRow
        Rectangle {
            readonly property var m: row.m
            readonly property bool isOpen: m.id === page.macroId
            readonly property bool isRunning: Macros.running.indexOf(m.id) >= 0
            height: 56
            color: isOpen ? Theme.hover : mma.containsMouse ? Qt.lighter(Theme.surface, 1.12) : "transparent"
            Rectangle { width: 3; height: parent.height; color: Theme.text; visible: parent.isOpen }
            MouseArea { id: mma; anchors.fill: parent; hoverEnabled: true
                        onClicked: { Macros.openMacro(m.id); page.view = "edit" } }
            // armed pill
            Rectangle {
                x: 14
                anchors.verticalCenter: parent.verticalCenter
                width: 34; height: 20; radius: 10
                color: m.armed ? Theme.amber : "transparent"
                border.width: m.armed ? 0 : 1.5
                border.color: Theme.text3
                Rectangle { width: 14; height: 14; radius: 7; y: 3
                            x: m.armed ? parent.width - width - 3 : 3
                            color: m.armed ? Theme.onLight : Theme.text3 }
                MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                            onClicked: Macros.armMacro(m.id, !m.armed) }
            }
            Column {
                x: 60
                width: parent.width - 60 - (runBtn.visible ? runBtn.width + 20 : 36)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Text { width: parent.width; text: m.name; elide: Text.ElideRight; color: Theme.text
                       font.family: Theme.ui; font.pixelSize: Theme.body; font.weight: Font.Medium }
                Text {
                    width: parent.width
                    elide: Text.ElideRight
                    text: (m.trigger ? page.prose(m.trigger) : "Run only")
                          + (m.unfinished ? "  ·  " + m.unfinished + " to fill" : "")
                    color: Theme.text3
                    font.family: Theme.ui
                    font.pixelSize: Theme.small
                }
            }
            SLamp { visible: isRunning; anchors.right: parent.right; anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter; state: "busy" }
            SButton {
                id: runBtn
                visible: !isRunning && mma.containsMouse
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                compact: true
                text: "Run"
                onClicked: Macros.runMacro(m.id)
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.lineSoft }
        }
    }

    // ---- sheets ---------------------------------------------------------------------------
    MacValueSheet {
        id: sheet
        onWantParameter: Macros.pickStart(sheet.path, sheet.slot)
        onWantMeter: Macros.meterStart(sheet.path, sheet.slot)
        onWantTimecode: tcPicker.open()
    }
    MacParamPicker {}
    MacMeterPicker {}

    SPicker {
        id: ops
        property string path: ""
        property string slot: ""
        anchors.centerIn: parent
        width: 380
        onChosen: (raw, label) => {
            if (raw === "#number") {
                sheet.show(ops.path, ops.slot,
                           { "kind": "number", "field": true, "allow": ["value"], "unit": "", "plain": true,
                             "low": 1, "high": 999, "accepts": "1 to 999", "target": "Scene number",
                             "current": "" })
                return
            }
            Macros.setField(ops.path, ops.slot, raw)
        }
    }
    SPicker {
        id: tcPicker
        anchors.centerIn: parent
        width: 380
        title: Macros.timecodeNow !== "" ? "Timecode · now " + Macros.timecodeNow : "Timecode · nothing arriving"
        items: Macros.timecodeReadings.map(function (t) { return { label: page.sentence(t.label), raw: t.key, hint: t.hint || "" } })
        onChosen: (raw, label) => Macros.setValue(sheet.path, sheet.slot, { "kind": "timecode", "what": raw })
    }
    MacTextDialog {
        id: textDialog
        property string folder: ""
        allowEmpty: textDialog.title === "Rename folder"
        onAccepted: text => {
            if (textDialog.title === "Rename folder") Macros.renameFolder(textDialog.folder, text)
            else if (text !== "") Macros.setFolder(page.macroId, text)
        }
    }
    Dialog {
        id: confirmDelete
        anchors.centerIn: parent
        modal: true
        width: 400
        background: Rectangle { color: Theme.raised; radius: Theme.radius + 2; border.width: 1; border.color: Theme.line }
        contentItem: Column {
            spacing: 16
            padding: 6
            Text { width: 360; wrapMode: Text.WordWrap; text: "Delete “" + (page.macro.name || "") + "”?"
                   color: Theme.text; font.family: Theme.cond; font.pixelSize: Theme.h2; font.weight: Font.DemiBold }
            Text { width: 360; wrapMode: Text.WordWrap; text: "Its blocks and triggers are removed. This cannot be undone."
                   color: Theme.text2; font.family: Theme.ui; font.pixelSize: Theme.body }
            Row {
                spacing: 8
                SButton { kind: "danger"; text: "Delete macro"
                          onClicked: { Macros.deleteMacro(page.macroId); confirmDelete.close() } }
                SButton { kind: "quiet"; text: "Cancel"; onClicked: confirmDelete.close() }
            }
        }
    }
    FileDialog {
        id: importDialog
        title: "Import macros"
        nameFilters: ["Macro files (*.json)"]
        onAccepted: Macros.importFile(page.localPath(selectedFile))
    }
    FolderDialog {
        id: exportDialog
        property string which: ""
        title: "Export macros to a folder"
        onAccepted: Macros.exportMacros(page.localPath(selectedFolder), exportDialog.which)
    }
}
