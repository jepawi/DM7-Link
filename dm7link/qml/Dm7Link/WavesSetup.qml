import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// SETUP: the link, where SuperRack is fed from, and what follows the desk.
Item {
    id: v
    readonly property bool on: Waves.enabled
    readonly property int cols: width > 1180 ? 2 : 1
    readonly property real colW: (width - 72 - (cols - 1) * 56) / cols

    Flickable {
        anchors.fill: parent
        contentHeight: grid.implicitHeight + 72
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        GridLayout {
            id: grid
            x: 36; y: 24
            width: v.width - 72
            columns: v.cols
            columnSpacing: 56
            rowSpacing: 36

            // ---------------------------------------------------------------- link
            SSection {
                Layout.fillWidth: true
                Layout.preferredWidth: v.colW
                Layout.alignment: Qt.AlignTop
                title: "Waves link"
                Row {
                    spacing: 8
                    SLamp { anchors.verticalCenter: parent.verticalCenter; state: Waves.pcAnswering ? "ok" : "busy" }
                    Text {
                        text: Waves.pcAnswering ? "SuperRack connected" + (Waves.now.peer ? " from " + Waves.now.peer : "")
                                                : "Waiting for SuperRack on port " + Waves.srPort
                        color: Theme.text2
                        font.family: Theme.ui
                        font.pixelSize: Theme.body
                    }
                }
                RowLayout {
                    width: parent.width
                    spacing: 12
                    Column {
                        Layout.fillWidth: true
                        spacing: 2
                        Text { text: "Adapter"; color: Theme.text; font.family: Theme.ui; font.pixelSize: Theme.body }
                        Text {
                            width: parent.width
                            text: "The network SuperRack is on"
                            color: Theme.text2
                            font.family: Theme.ui
                            font.pixelSize: Theme.small + 1
                        }
                    }
                    SDropdown {
                        Layout.preferredWidth: 260
                        title: "Network adapter"
                        items: Adapter.items
                        current: Adapter.device
                        display: Adapter.missing ? Adapter.missingName + " (not connected)" : Adapter.name
                        placeholder: "No network"
                        textColor: Adapter.missing ? Theme.bad : Theme.text
                        onAboutToOpen: Adapter.rescan()
                        onChosen: (raw, label) => Adapter.choose(raw)
                    }
                }
                // The one address to type into SuperRack.
                Rectangle {
                    width: parent.width
                    height: 76
                    radius: Theme.radius
                    color: Theme.surface
                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        Text {
                            text: "Console IP in SuperRack"
                            color: Theme.text3
                            font.family: Theme.ui
                            font.pixelSize: Theme.small + 1
                        }
                        Text {
                            text: Adapter.ip || "—"
                            color: Adapter.ip ? Theme.text : Theme.text3
                            font.family: Theme.cond
                            font.pixelSize: 32
                            font.weight: Font.DemiBold
                            font.features: { "tnum": 1 }
                        }
                    }
                    SButton {
                        id: cp
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Adapter.ip !== ""
                        text: "Copy"
                        onClicked: { Shell.copy(Adapter.ip); text = "Copied"; back.restart() }
                        Timer { id: back; interval: 1400; onTriggered: cp.text = "Copy" }
                    }
                }
                Rectangle {
                    width: parent.width
                    height: 52
                    radius: Theme.radius
                    color: Theme.surface
                    visible: Adapter.portText !== ""
                    Column {
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "Port in SuperRack"; color: Theme.text3; font.family: Theme.ui
                               font.pixelSize: Theme.small + 1 }
                        Text { text: Adapter.portText; color: Theme.text; font.family: Theme.cond
                               font.pixelSize: Theme.label + 2; font.weight: Font.DemiBold
                               font.features: { "tnum": 1 } }
                    }
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: Adapter.wireless
                          ? "SuperRack cannot use Wi-Fi as its ProLink Port. Choose a wired adapter."
                          : "In SuperRack: Setup ▸ Controllers ▸ ProLink, then tick Assign. Port number " + Waves.srPort + "."
                    color: Adapter.wireless ? Theme.bad : Theme.text3
                    font.family: Theme.ui
                    font.pixelSize: Theme.small + 1
                }
                SSwitch {
                    width: parent.width
                    enabled: v.on
                    text: "Show mode"
                    caption: "SuperRack takes scene recalls, SEL and tempo only"
                    checked: Waves.showMode
                    onToggled: Waves.toggleShowMode()
                }
            }

            // ---------------------------------------------------------------- feed
            SSection {
                Layout.fillWidth: true
                Layout.preferredWidth: v.colW
                Layout.alignment: Qt.AlignTop
                title: "SuperRack is fed by"
                SSegmented {
                    options: [{ value: "PY", label: "PY card" }, { value: "Dante", label: "Dante" }]
                    current: Waves.card
                    onPicked: value => Waves.setCard(value)
                }
                GridLayout {
                    width: parent.width
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 10
                    Item { Layout.preferredHeight: 4; Layout.columnSpan: 2 }
                    Text {
                        visible: Waves.card === "Dante"
                        Layout.fillWidth: true
                        text: "First desk Dante output to SuperRack"
                        color: Theme.text
                        font.family: Theme.ui
                        font.pixelSize: Theme.body
                    }
                    SSpin {
                        visible: Waves.card === "Dante"
                        from: 1; to: 144
                        value: Waves.cardBase
                        onChanged: n => Waves.setCardBase(n)
                    }
                    Text {
                        Layout.fillWidth: true
                        text: (Waves.card === "Dante" ? "Dante " + Waves.cardBase : "PY 1") + " arrives on SuperRack input"
                        color: Theme.text
                        font.family: Theme.ui
                        font.pixelSize: Theme.body
                    }
                    SSpin {
                        enabled: v.on
                        from: 1; to: 128
                        value: Waves.srOffset
                        onChanged: n => Waves.setSrOffset(n)
                    }
                }
                Text {
                    width: parent.width
                    topPadding: 4
                    wrapMode: Text.WordWrap
                    text: Waves.card === "Dante"
                          ? "Dante " + Waves.cardBase + " to " + Math.min(144, Waves.cardBase + 127)
                            + " are read as SuperRack's inputs and outputs."
                          : "PY 1 to 64 are read as SuperRack's inputs and outputs."
                    color: Theme.text3
                    font.family: Theme.ui
                    font.pixelSize: Theme.small + 1
                }
            }

            // ---------------------------------------------------------------- SEL
            SSection {
                Layout.fillWidth: true
                Layout.preferredWidth: v.colW
                Layout.alignment: Qt.AlignTop
                title: "Channels"
                SSwitch { width: parent.width; enabled: v.on; text: "SEL on the desk opens the rack"
                          checked: Waves.sendSelect; onToggled: on => Waves.setSendSelect(on) }
                SSwitch { width: parent.width; enabled: v.on && Waves.sendSelect
                          text: "SEL again steps to the next plug-in"
                          caption: "Pressing SEL on the channel already selected"
                          checked: Waves.selAgain; onToggled: on => Waves.setSelAgain(on) }
                SSwitch { width: parent.width; enabled: v.on; text: "Switch SuperRack to the rack page"
                          checked: Waves.openRackPage; onToggled: on => Waves.setOpenRackPage(on) }
                SSwitch { width: parent.width; enabled: v.on; text: "A channel with no rack shows the overview"
                          checked: Waves.unmappedOverview; onToggled: on => Waves.setUnmappedOverview(on) }
                SSwitch { width: parent.width; enabled: v.on; text: "Name racks after desk channels"
                          caption: "When a channel is patched to the " + (Waves.card === "PY" ? "PY card" : "Dante window") + " or renamed"
                          checked: Waves.sendNames; onToggled: on => Waves.setSendNames(on) }
            }

            // ---------------------------------------------------------------- scenes
            SSection {
                Layout.fillWidth: true
                Layout.preferredWidth: v.colW
                Layout.alignment: Qt.AlignTop
                title: "Scenes"
                SSwitch { width: parent.width; enabled: v.on; text: "Scene recall recalls a snapshot"
                          caption: "Mapped on the Scenes tab"
                          checked: Waves.sendScenes; onToggled: on => Waves.setSendScenes(on) }
                SSwitch { width: parent.width; enabled: v.on; text: "Scene store stores its snapshot"
                          checked: Waves.sendStores && Waves.snapStore
                          onToggled: on => { Waves.setSendStores(on); Waves.setSnapStore(on) } }
                SSwitch { width: parent.width; enabled: v.on && Waves.sendStores && Waves.snapStore
                          text: "A scene with no snapshot gets a new one"
                          caption: "Named after the scene"
                          checked: Waves.snapNew; onToggled: on => Waves.setSnapNew(on) }
            }

            // ---------------------------------------------------------------- tempo
            SSection {
                Layout.fillWidth: true
                Layout.preferredWidth: v.colW
                Layout.alignment: Qt.AlignTop
                title: "Tempo"
                SSwitch { width: parent.width; enabled: v.on; text: "Desk tempo sets SuperRack's tempo"
                          checked: Waves.sendTempo; onToggled: on => Waves.setSendTempo(on) }
                RowLayout {
                    width: parent.width
                    Text { Layout.fillWidth: true; text: "Source"; color: Theme.text
                           font.family: Theme.ui; font.pixelSize: Theme.body }
                    SDropdown {
                        Layout.preferredWidth: 220
                        enabled: v.on
                        title: "Tempo source"
                        items: Waves.tempos.map(function (t) {
                            return { label: t.label, raw: String(t.source), hint: t.bpm ? t.bpm + " BPM" : "" } })
                        current: String(Waves.tempoSource)
                        display: (Waves.tempoSource === 5 ? "MIDI clock" : "Tempo " + Waves.tempoSource)
                                 + (Waves.tempoBpm ? "  ·  " + Waves.tempoBpm + " BPM" : "")
                        onChosen: (raw, label) => Waves.setTempoSource(parseInt(raw))
                    }
                }
            }
        }
    }
}
