import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// TIMECODE: LTC on an audio interface input, and the scene cues it fires.
Item {
    id: page
    readonly property var cfg: Cues.settings
    readonly property var tc: Cues.timecode
    property string editing: ""            // the cue whose time is being typed

    Component.onCompleted: Cues.setWatching(true)

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // ---------------------------------------------------------------- input
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 148
            color: Theme.surface
            RowLayout {
                anchors.fill: parent
                anchors.rightMargin: 36
                spacing: 36
                TimecodeReadout {
                    large: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 440
                    color: "transparent"
                }
                GridLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    columns: 4
                    columnSpacing: 14
                    rowSpacing: 10

                    Text { text: "Input"; color: Theme.text3; font.family: Theme.ui; font.pixelSize: Theme.small + 1 }
                    SDropdown {
                        Layout.preferredWidth: 300
                        title: "Audio interface"
                        items: [{ label: "System default", raw: "auto" }].concat(
                                   Cues.devices.map(function (d) {
                                       return { label: d.label, raw: d.raw, hint: d.channels + " in" } }))
                        current: String(page.cfg.device || "auto")
                        display: page.cfg.device && page.cfg.device !== "auto" ? page.cfg.device : "System default"
                        onAboutToOpen: Cues.rescanInputs()
                        onChosen: (raw, label) => Cues.setOption("device", raw)
                    }
                    Text { text: "Channel"; color: Theme.text3; font.family: Theme.ui; font.pixelSize: Theme.small + 1 }
                    SDropdown {
                        Layout.preferredWidth: 120
                        title: "Input channel"
                        items: {
                            var out = []
                            for (var i = 1; i <= Math.max(1, Cues.inputChannels); i++)
                                out.push({ label: "Input " + i, raw: String(i) })
                            return out
                        }
                        current: String(page.cfg.channel || 1)
                        display: "Input " + (page.cfg.channel || 1)
                        onChosen: (raw, label) => Cues.setOption("channel", parseInt(raw))
                    }
                    Text { text: "Frame rate"; color: Theme.text3; font.family: Theme.ui; font.pixelSize: Theme.small + 1 }
                    SSegmented {
                        options: Cues.rates.map(function (r) { return { value: r, label: r === "auto" ? "Auto" : r } })
                        current: String(page.cfg.rate || "auto")
                        onPicked: value => Cues.setOption("rate", value)
                    }
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.lineSoft }
        }

        // ---------------------------------------------------------------- timeline
        Timeline {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(220, 66 + Cues.lanes.length * 52)
            Layout.leftMargin: 36
            Layout.rightMargin: 36
            Layout.topMargin: 18
        }

        // ---------------------------------------------------------------- cue list toolbar
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 36
            Layout.rightMargin: 36
            Layout.topMargin: 14
            Layout.bottomMargin: 10
            spacing: 8
            Text {
                text: "Cues"
                color: Theme.text
                font.family: Theme.cond
                font.pixelSize: Theme.h1 - 2
                font.weight: Font.DemiBold
            }
            Text {
                Layout.leftMargin: 8
                text: Cues.armedCount + " of " + Cues.cueCount + " armed"
                color: Cues.armedCount ? Theme.amber : Theme.text3
                font.family: Theme.ui
                font.pixelSize: Theme.body
            }
            Item { Layout.fillWidth: true }
            SSwitch {
                Layout.preferredWidth: 160
                text: "Live update"
                checked: Cues.retime.on
                onToggled: on => Cues.setRetime(on)
            }
            SButton {
                visible: !!Cues.retime.on
                kind: "primary"
                enabled: !!Cues.retime.live && !!Cues.retime.id
                text: Cues.retime.id ? "Move Q" + Cues.retime.number + " here" : "No cue to move"
                onClicked: Cues.updateCue(true)
            }
            SButton {
                visible: Cues.retime.on && Cues.retime.undo !== ""
                kind: "quiet"
                text: "Undo"
                onClicked: Cues.undoUpdate()
            }
            Rectangle { visible: Cues.retime.on; width: 1; height: 24; color: Theme.line }
            SButton { text: "Arm all"; enabled: Cues.cueCount > 0; onClicked: Cues.armAll(true) }
            SButton { text: "Disarm all"; enabled: Cues.armedCount > 0; onClicked: Cues.armAll(false) }
            SButton {
                kind: "primary"
                text: page.tc.live ? "Add cue at " + page.tc.text : "Add cue"
                onClicked: Cues.addCue()
            }
        }

        // ---------------------------------------------------------------- cue list
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 36
            Layout.rightMargin: 36
            Layout.bottomMargin: 20
            color: Theme.surface
            radius: Theme.radius
            clip: true

            STableHead {
                id: head
                width: parent.width
                columns: [{ label: "Armed", w: 64 }, { label: "Cue", w: 52 }, { label: "Time", w: 200 },
                          { label: "Name", w: 0.8 }, { label: Features.macrosOn ? "Does" : "Recalls", w: 1 }, { label: "Song", w: 0.6 },
                          { label: "", w: 150 }]
            }
            ListView {
                id: list
                anchors.top: head.bottom
                anchors.bottom: parent.bottom
                width: parent.width
                clip: true
                model: Cues.rows
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: Loader {
                    required property var modelData
                    width: list.width
                    sourceComponent: modelData.type === "song" ? songRow : cueRow
                    property var row: modelData
                }
            }
            Column {
                visible: Cues.cueCount === 0
                anchors.centerIn: parent
                spacing: 6
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No cues"
                    color: Theme.text2
                    font.family: Theme.cond
                    font.pixelSize: Theme.h2
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Park the timecode where a scene should change and add a cue."
                    color: Theme.text3
                    font.family: Theme.ui
                    font.pixelSize: Theme.body
                }
            }
        }
    }

    // A song heading: its name, its span, how much of it is armed. Click to open or close it.
    Component {
        id: songRow
        Rectangle {
            height: 40
            color: sma.containsMouse ? Theme.hover : Theme.raised
            Rectangle { width: 3; height: parent.height; color: Theme.amber; visible: row.live }
            Row {
                x: 16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12
                Text {
                    text: row.open ? "▾" : "▸"
                    color: Theme.text2
                    font.pixelSize: Theme.body
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: row.name
                    color: Theme.text
                    font.family: Theme.cond
                    font.pixelSize: Theme.label + 2
                    font.weight: Font.DemiBold
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: row.first + " – " + row.last + "    " + row.count + (row.count === 1 ? " cue" : " cues")
                          + "    " + row.armed + " armed"
                    color: Theme.text2
                    font.family: Theme.ui
                    font.pixelSize: Theme.small + 1
                    font.features: { "tnum": 1 }
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: Cues.toggleSong(row.id) }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.lineSoft }
        }
    }

    Component {
        id: cueRow
        SRow {
            id: cr
            height: Theme.row + 4
            live: row.recent
            color: row.recent ? Theme.amberDim : hovered ? Qt.lighter(Theme.ground, 1.18) : "transparent"
            property bool hovered: rowHover.hovered
            HoverHandler { id: rowHover }

            // armed
            Item {
                width: head.colW[0]; height: parent.height
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38; height: 22; radius: 11
                    color: row.armed ? Theme.amber : "transparent"
                    border.width: row.armed ? 0 : 1.5
                    border.color: Theme.text3
                    Rectangle {
                        width: 16; height: 16; radius: 8
                        y: 3
                        x: row.armed ? parent.width - width - 3 : 3
                        color: row.armed ? Theme.onLight : Theme.text3
                    }
                    MouseArea { anchors.fill: parent; anchors.margins: -6; cursorShape: Qt.PointingHandCursor
                                onClicked: Cues.armCue(row.id, !row.armed) }
                }
            }
            SCell { width: head.colW[1]; text: "Q" + row.number; strong: true
                    color: row.past ? Theme.text3 : Theme.text }
            // time: click to type, or take the incoming timecode, or nudge a frame
            Item {
                width: head.colW[2]; height: parent.height
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Item {
                        width: 112; height: 30
                        Text {
                            visible: page.editing !== row.id
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.at
                            color: row.past ? Theme.text3 : Theme.text
                            font.family: Theme.cond
                            font.pixelSize: Theme.label + 3
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor
                                        onClicked: page.editing = row.id }
                        }
                        SField {
                            visible: page.editing === row.id
                            anchors.fill: parent
                            mono: true
                            text: row.at
                            inputMask: "99:99:99:99;_"
                            onVisibleChanged: if (visible) { forceActiveFocus(); selectAll() }
                            onAccepted: { Cues.setCueAt(row.id, text); page.editing = "" }
                            Keys.onEscapePressed: page.editing = ""
                            onActiveFocusChanged: if (!activeFocus && page.editing === row.id) page.editing = ""
                        }
                    }
                    SButton { compact: true; kind: "quiet"; text: "−1"; width: 30; visible: cr.hovered
                              onClicked: Cues.nudgeCue(row.id, -1) }
                    SButton { compact: true; kind: "quiet"; text: "+1"; width: 30; visible: cr.hovered
                              onClicked: Cues.nudgeCue(row.id, 1) }
                }
            }
            // name
            Item {
                width: head.colW[3]; height: parent.height
                SField {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 16
                    height: 30
                    text: row.name
                    placeholderText: "Name"
                    background: Rectangle {
                        radius: Theme.radius
                        color: parent.activeFocus ? Theme.ground : "transparent"
                        border.width: parent.activeFocus ? 2 : (cr.hovered ? 1 : 0)
                        border.color: parent.activeFocus ? Theme.text : Theme.line
                    }
                    onEditingFinished: if (text !== row.name) Cues.setCueName(row.id, text)
                }
            }
            // what the cue does: recall a scene, or (with Macros on) run a macro
            Item {
                width: head.colW[4]; height: parent.height
                SDropdown {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 16
                    quiet: true
                    title: "Q" + row.number + (Features.macrosOn ? " does" : " recalls")
                    property var choices: []
                    onAboutToOpen: {
                        var all = Cues.sceneChoices(row.id).filter(function (c) {
                            return c.raw !== "" && c.label !== "Custom Number" }).map(function (c) {
                            return { label: /^[0-9]/.test(c.label) ? "Scene " + c.label
                                            : c.label.charAt(0).toUpperCase() + c.label.slice(1),
                                     raw: "scene:" + c.raw, hint: c.hint } })
                        // next / previous first, then a number typed by hand -- any scene,
                        // connected or not -- then the console's own list.
                        var ways = all.filter(function (c) { return c.raw === "scene:next" || c.raw === "scene:previous" })
                        var rest = all.filter(function (c) { return ways.indexOf(c) < 0 })
                        var out = ways.concat([{ label: "Scene number…", raw: "typed",
                                                 hint: Scenes.ready ? "" : "any scene, by number" }]).concat(rest)
                        if (Features.macrosOn)
                            out = out.concat(Macros.macros.map(function (m) {
                                return { label: "Run " + m.name, raw: "macro:" + m.id,
                                         hint: m.folder || "" } }))
                        choices = out
                    }
                    items: choices
                    current: row.kind === "macro" ? "macro:" + row.macro : "scene:" + row.scene
                    display: !row.macroName ? ""
                             : row.kind === "macro" ? "Run " + row.macroName
                             : /^[0-9]/.test(row.macroName) ? "Scene " + row.macroName
                             : row.macroName.charAt(0).toUpperCase() + row.macroName.slice(1)
                    placeholder: Features.macrosOn ? "Choose a scene or macro" : "Choose a scene"
                    textColor: row.missing || row.faulty || (row.kind === "macro" && !Features.macrosOn)
                               ? Theme.bad : Theme.text
                    onChosen: (raw, label) => {
                        if (raw === "typed") { sceneNumber.cue = row.id; sceneNumber.was = row.kind === "scene" ? row.scene : ""; sceneNumber.open(); return }
                        if (raw.indexOf("macro:") === 0) Cues.setCueMacro(row.id, raw.slice(6))
                        else Cues.setCueScene(row.id, raw.slice(6))
                    }
                }
            }
            // song
            Item {
                width: head.colW[5]; height: parent.height
                SDropdown {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 16
                    quiet: true
                    title: "Song"
                    items: Cues.songs.map(function (s) { return { label: s.name, raw: s.id } })
                           .concat([{ label: "New song…", raw: "__new" }])
                    current: row.group
                    display: row.song
                    placeholder: "—"
                    clearLabel: "No song"
                    onChosen: (raw, label) => {
                        if (raw === "__new") { newSong.cue = row.id; newSong.open() }
                        else Cues.setCueSong(row.id, raw)
                    }
                }
            }
            // actions
            Item {
                width: head.colW[6]; height: parent.height
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    SButton { compact: true; text: "Run"
                              enabled: Session.online && (row.kind === "macro" ? !!row.macro && Features.macrosOn : !!row.scene)
                              onClicked: Cues.runCue(row.id) }
                    SButton { compact: true; kind: "quiet"; text: "Take"; visible: cr.hovered
                              enabled: !!page.tc.live; onClicked: Cues.captureCue(row.id) }
                    SButton { compact: true; kind: "quiet"; text: "✕"; width: 28; visible: cr.hovered
                              onClicked: Cues.removeCue(row.id) }
                }
            }
        }
    }

    // A scene by number: 12, or 12.01 for a sub-scene. Checked here, normalised by the cue book.
    Dialog {
        id: sceneNumber
        property string cue: ""
        property string was: ""
        readonly property bool valid: {
            var m = /^\s*(\d{1,3})(?:\.(\d{1,2}))?\s*$/.exec(numberField.text)
            return m !== null && parseInt(m[1]) >= 1 && parseInt(m[1]) <= 999
        }
        anchors.centerIn: parent
        modal: true
        width: 380
        onOpened: {
            // a scene the cue already holds ("012.00") is offered as the desk prints it ("12")
            var m = /^(\d+)\.(\d+)$/.exec(was)
            numberField.text = m ? String(parseInt(m[1])) + (parseInt(m[2]) ? "." + m[2] : "") : ""
            numberField.forceActiveFocus()
            numberField.selectAll()
        }
        background: Rectangle { color: Theme.raised; radius: Theme.radius + 2; border.width: 1; border.color: Theme.line }
        contentItem: Column {
            spacing: 14
            padding: 6
            Text { text: "Recall scene"; color: Theme.text; font.family: Theme.cond; font.pixelSize: Theme.h2
                   font.weight: Font.DemiBold }
            SField {
                id: numberField
                width: 160
                mono: true
                placeholderText: "12 or 12.01"
                onAccepted: if (sceneNumber.valid) useNumber.clicked()
            }
            Text {
                width: 340
                wrapMode: Text.WordWrap
                text: numberField.text !== "" && !sceneNumber.valid ? "Scene numbers run from 1 to 999"
                      : Scenes.ready ? "" : "Checked once the console is connected"
                color: numberField.text !== "" && !sceneNumber.valid ? Theme.bad : Theme.text3
                font.family: Theme.ui
                font.pixelSize: Theme.small + 1
                visible: text !== ""
            }
            Row {
                spacing: 8
                SButton { id: useNumber; kind: "primary"; text: "Use scene"; enabled: sceneNumber.valid
                          onClicked: { Cues.setCueScene(sceneNumber.cue, numberField.text.trim()); sceneNumber.close() } }
                SButton { kind: "quiet"; text: "Cancel"; onClicked: sceneNumber.close() }
            }
        }
    }

    Dialog {
        id: newSong
        property string cue: ""
        anchors.centerIn: parent
        modal: true
        width: 380
        onOpened: { songName.text = ""; songName.forceActiveFocus() }
        background: Rectangle { color: Theme.raised; radius: Theme.radius + 2; border.width: 1; border.color: Theme.line }
        contentItem: Column {
            spacing: 14
            padding: 6
            Text { text: "New song"; color: Theme.text; font.family: Theme.cond; font.pixelSize: Theme.h2
                   font.weight: Font.DemiBold }
            SField { id: songName; width: 340; placeholderText: "Song name"; onAccepted: makeSong.clicked() }
            Row {
                spacing: 8
                SButton { id: makeSong; kind: "primary"; text: "Add song"; enabled: songName.text.trim() !== ""
                          onClicked: { Cues.newSongFor(newSong.cue, songName.text.trim()); newSong.close() } }
                SButton { kind: "quiet"; text: "Cancel"; onClicked: newSong.close() }
            }
        }
    }
}
