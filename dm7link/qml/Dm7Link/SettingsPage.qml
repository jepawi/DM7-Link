import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// SETTINGS: which parts of DM7 Link are in use. A part switched off stops and is hidden.
Item {
    id: page

    Flickable {
        anchors.fill: parent
        contentHeight: body.implicitHeight + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        Column {
            id: body
            x: 36; y: 32
            width: Math.min(page.width - 72, 640)
            spacing: 36

            SSection {
                width: parent.width
                title: "Features"
                caption: "A feature that is off stops working and is hidden."
                SSwitch {
                    width: parent.width
                    text: "Waves SuperRack"
                    caption: Features.wavesOn
                             ? (Waves.pcAnswering ? "SuperRack connected" : "Waiting for SuperRack on port " + Waves.srPort)
                             : "SuperRack link closed"
                    checked: Features.wavesOn
                    onToggled: on => Features.set("waves", on)
                }
                SSwitch {
                    width: parent.width
                    text: "Timecode"
                    caption: Features.timecodeOn
                             ? (Cues.armedCount + " of " + Cues.cueCount + " cues armed")
                             : "Audio input closed, no cue fires"
                    checked: Features.timecodeOn
                    onToggled: on => Features.set("timecode", on)
                }
                SSwitch {
                    width: parent.width
                    text: "Macros"
                    caption: Features.macrosOn
                             ? (Macros.armedCount + " of " + Macros.count + " macros armed")
                             : "No macro runs, no trigger is watched"
                    checked: Features.macrosOn
                    onToggled: on => Features.set("macros", on)
                }
            }

            SSection {
                width: parent.width
                title: "Settings folder"
                caption: Shell.dataDir
                trailing: SButton { text: "Open"; onClicked: Shell.openDataFolder() }
            }

            Text {
                text: "DM7 Link " + Shell.version
                color: Theme.text3
                font.family: Theme.ui
                font.pixelSize: Theme.small + 1
            }
        }
    }
}
