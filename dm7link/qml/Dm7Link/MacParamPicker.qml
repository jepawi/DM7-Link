import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// Choosing one of the console's parameters for a block: browse or search the catalogue (only
// what this slot can use is offered), then say which channel, bus or band -- one, several, or
// whichever one a variable names.
Popup {
    id: p
    readonly property var pick: Macros.picker
    readonly property string stage: pick.stage !== undefined ? pick.stage : "select"
    readonly property var rows: pick.rows !== undefined ? pick.rows : []
    readonly property var crumbs: pick.crumbs !== undefined ? pick.crumbs : []
    readonly property var levels: pick.levels !== undefined ? pick.levels : []
    readonly property var names: pick.names !== undefined ? pick.names : []
    readonly property int count: pick.count !== undefined ? pick.count : 0
    readonly property int level: pick.level !== undefined ? pick.level : 0
    readonly property var vars: pick.vars !== undefined ? pick.vars : []
    readonly property bool searching: pick.searching === true
    readonly property string only: pick.only !== undefined ? pick.only : ""
    readonly property string mode: pick.mode !== undefined ? pick.mode : "one"
    readonly property bool manyOk: pick.manyOk === true
    readonly property var chosen: pick.chosen !== undefined ? pick.chosen : []
    readonly property var fits: pick.fits !== undefined ? pick.fits : []
    readonly property string scope: pick.scope !== undefined ? pick.scope : ""
    readonly property int elsewhere: pick.elsewhere !== undefined ? pick.elsewhere : 0
    readonly property var here: {
        for (var i = 0; i < levels.length; i++) if (levels[i].level === level) return levels[i]
        return ({})
    }
    function allowed(i) { return fits.length === 0 || fits[i] === true }
    function words(t) {
        t = String(t)
        if (!/^[A-Z][A-Z ]+$/.test(t)) return t
        var low = t.toLowerCase()
        return low.charAt(0).toUpperCase() + low.slice(1)
    }

    visible: Macros.picking
    onClosed: if (Macros.picking) Macros.pickCancel()
    onOpened: { search.text = p.pick.query || ""; search.forceActiveFocus() }
    anchors.centerIn: Overlay.overlay
    width: Math.min(Overlay.overlay ? Overlay.overlay.width - 80 : 900, 900)
    height: Math.min(Overlay.overlay ? Overlay.overlay.height - 80 : 680, 680)
    padding: 0
    modal: true
    focus: true
    background: Rectangle { color: Theme.raised; radius: Theme.radius + 2; border.width: 1; border.color: Theme.line }
    Overlay.modal: Rectangle { color: "#99000000" }

    component Trail: Flow {
        property var path: []
        signal go(int depth)
        spacing: 4
        Repeater {
            model: parent.path
            delegate: Row {
                required property var modelData
                required property int index
                spacing: 4
                SButton { compact: true; kind: "quiet"; text: p.words(modelData.label)
                          onClicked: parent.parent.go(modelData.depth !== undefined ? modelData.depth : modelData.level) }
                Text { visible: index < parent.parent.path.length - 1; text: "›"; color: Theme.text3
                       font.pixelSize: Theme.body; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 10

        // ---- head ------------------------------------------------------------------
        ColumnLayout {
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            Layout.topMargin: 18
            spacing: 6
            Text {
                text: p.stage === "index" ? (p.pick.label || "Parameter") : "Choose a parameter"
                color: Theme.text
                font.family: Theme.cond
                font.pixelSize: Theme.h2 + 2
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            Text {
                visible: p.only !== "" && p.stage === "select"
                Layout.fillWidth: true
                text: "Only " + p.only + " this block can use"
                color: Theme.text3
                font.family: Theme.ui
                font.pixelSize: Theme.small + 1
                elide: Text.ElideRight
            }
            SField {
                id: search
                visible: p.stage === "select"
                Layout.fillWidth: true
                placeholderText: p.scope !== "" ? "Search in " + p.scope : "Search every parameter"
                onTextEdited: Macros.pickSearch(text)
            }
            Trail {
                Layout.fillWidth: true
                visible: p.stage === "select" && !p.searching
                path: p.crumbs
                onGo: depth => Macros.pickUpTo(depth)
            }
            Trail {
                Layout.fillWidth: true
                visible: p.stage === "index"
                path: p.pick.path !== undefined ? p.pick.path : []
                onGo: depth => Macros.pickGotoEntry(depth)
            }
            Text {
                visible: p.stage === "index" && !!p.pick.reading
                text: "Reads " + (p.pick.reading || "")
                color: Theme.text2
                font.family: Theme.ui
                font.pixelSize: Theme.body
            }
        }

        // ---- browsing / searching -------------------------------------------------------
        Rectangle {
            visible: p.stage === "select"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            color: Theme.surface
            radius: Theme.radius
            clip: true
            ListView {
                id: list
                anchors.fill: parent
                clip: true
                model: p.rows
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: list.width
                    height: p.searching ? 62 : 42
                    color: rma.containsMouse ? Theme.hover : "transparent"
                    MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor; onClicked: Macros.pickChoose(index) }
                    Column {
                        x: 16
                        width: parent.width - 32 - meta.width
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2
                        Text {
                            width: parent.width
                            text: modelData.label
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.ui
                            font.pixelSize: Theme.body
                            font.weight: modelData.kind === "parameter" ? Font.Medium : Font.DemiBold
                        }
                        Trail {
                            width: parent.width
                            visible: p.searching && modelData.path !== undefined
                            path: modelData.path !== undefined ? modelData.path : []
                            onGo: depth => Macros.pickGotoHit(index, depth)
                        }
                    }
                    Text {
                        id: meta
                        anchors.right: parent.right
                        anchors.rightMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.meta !== "" ? modelData.meta : modelData.kind === "parameter" ? "" : "›"
                        color: Theme.text3
                        font.family: Theme.ui
                        font.pixelSize: Theme.small + 1
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.lineSoft }
                }
            }
            Text {
                anchors.centerIn: parent
                width: parent.width - 60
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                visible: p.rows.length === 0
                text: !p.pick.ready ? "Connect to the console to choose a parameter"
                      : p.searching ? (p.scope !== "" ? "Nothing in " + p.scope : "No parameter matches")
                      : "Nothing in here this block can use"
                color: Theme.text2
                font.family: Theme.ui
                font.pixelSize: Theme.body
            }
            SButton {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                visible: p.searching && p.scope !== "" && p.elsewhere > 0
                kind: "primary"
                text: "Search everywhere  (" + p.elsewhere + " more)"
                onClicked: Macros.pickEverywhere(true)
            }
        }

        // ---- which element(s) ----------------------------------------------------------
        RowLayout {
            visible: p.stage === "index"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            spacing: 16

            // the repeated levels of the path
            ColumnLayout {
                Layout.preferredWidth: 250
                Layout.alignment: Qt.AlignTop
                spacing: 6
                Repeater {
                    model: p.levels
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: modelData.level === p.level
                        Layout.fillWidth: true
                        implicitHeight: 52
                        radius: Theme.radius
                        color: on ? Theme.hover : lma.containsMouse ? Theme.surface : "transparent"
                        border.width: on ? 1 : 0
                        border.color: Theme.text2
                        Column {
                            x: 12
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 24
                            Text { text: modelData.label; color: Theme.text; font.family: Theme.ui
                                   font.pixelSize: Theme.body; font.weight: Font.Medium
                                   width: parent.width; elide: Text.ElideRight }
                            Text {
                                width: parent.width
                                elide: Text.ElideRight
                                text: modelData.mode === "variable" ? "= " + (modelData.bind || "a variable")
                                      : modelData.mode === "many" ? modelData.chosen.length + " of " + modelData.count
                                      : (modelData.element + 1) + (modelData.name ? "  " + modelData.name : "")
                                        + "  of " + modelData.count
                                color: Theme.text2
                                font.family: Theme.ui
                                font.pixelSize: Theme.small + 1
                            }
                        }
                        MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true
                                    onClicked: Macros.pickLevel(modelData.level) }
                    }
                }
            }

            // the elements of the level being answered
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 8
                RowLayout {
                    spacing: 8
                    SSegmented {
                        options: {
                            var o = [{ value: "one", label: "Single" }]
                            if (p.manyOk) o.push({ value: "many", label: "Multiple" })
                            o.push({ value: "variable", label: "Variable" })
                            return o
                        }
                        current: p.mode
                        onPicked: value => Macros.pickMode(p.level, value)
                    }
                    SButton { compact: true; visible: p.mode === "many"; text: "All"
                              onClicked: Macros.pickSpan(p.level, 0, p.count - 1) }
                    SButton { compact: true; visible: p.mode === "many"; text: "First 8"; enabled: p.count >= 8
                              onClicked: Macros.pickSpan(p.level, 0, 7) }
                }
                Flow {
                    Layout.fillWidth: true
                    visible: p.mode === "variable"
                    spacing: 6
                    Repeater {
                        model: p.vars
                        delegate: SButton {
                            required property var modelData
                            text: modelData
                            kind: modelData === p.here.bind ? "primary" : "secondary"
                            onClicked: Macros.pickBind(p.level, modelData === p.here.bind ? "" : modelData)
                        }
                    }
                    Text { visible: p.vars.length === 0; text: "No variables yet"; color: Theme.text3
                           font.family: Theme.ui; font.pixelSize: Theme.body }
                }
                GridView {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    visible: p.mode !== "variable"
                    clip: true
                    cellWidth: Math.floor(width / Math.max(1, Math.floor(width / 96)))
                    cellHeight: 52
                    model: p.count
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollBar {}
                    delegate: Item {
                        required property int index
                        width: grid.cellWidth
                        height: grid.cellHeight
                        readonly property bool usable: p.allowed(index)
                        readonly property bool picked: p.mode === "many" ? p.chosen.indexOf(index) >= 0
                                                                           : index === p.here.element
                        Rectangle {
                            anchors.fill: parent
                            anchors.rightMargin: 6
                            anchors.bottomMargin: 6
                            radius: Theme.radius
                            opacity: usable ? 1 : 0.35
                            color: picked ? Theme.text : ema.containsMouse ? Theme.hover : Theme.surface
                            Column {
                                anchors.centerIn: parent
                                width: parent.width - 8
                                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter
                                       text: index + 1; color: picked ? Theme.onLight : Theme.text
                                       font.family: Theme.cond; font.pixelSize: Theme.label
                                       font.weight: Font.DemiBold }
                                Text { width: parent.width; horizontalAlignment: Text.AlignHCenter
                                       visible: text !== ""; elide: Text.ElideRight
                                       text: index < p.names.length ? p.names[index] : ""
                                       color: picked ? Theme.onLight : Theme.text3
                                       font.family: Theme.ui; font.pixelSize: Theme.small }
                            }
                            MouseArea { id: ema; anchors.fill: parent; hoverEnabled: true; enabled: usable
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: Macros.pickElement(p.level, index) }
                        }
                    }
                }
            }
        }

        // ---- the way out ---------------------------------------------------------------
        Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.line }
        RowLayout {
            Layout.leftMargin: 22
            Layout.rightMargin: 22
            Layout.bottomMargin: 16
            spacing: 8
            SButton { kind: "quiet"; text: "Back"; visible: p.stage === "index"; onClicked: Macros.pickBack() }
            SButton { kind: "quiet"; text: "Up"; visible: p.stage === "select" && !p.searching && p.crumbs.length > 1
                      onClicked: Macros.pickUp() }
            Item { Layout.fillWidth: true }
            SButton { kind: "quiet"; text: "Cancel"; onClicked: Macros.pickCancel() }
            SButton { kind: "primary"; text: "Use this parameter"; visible: p.stage === "index"
                      enabled: p.mode !== "variable" || !!p.here.bind || p.levels.length === 0
                      onClicked: Macros.pickConfirm() }
        }
    }
}
