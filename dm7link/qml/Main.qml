import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts
import Dm7Link

ApplicationWindow {
    id: win
    width: initialWidth
    height: initialHeight
    minimumWidth: 1180
    minimumHeight: 720
    visible: true
    title: Show.name + (Show.modified ? " •" : "") + " — DM7 Link"
    color: Theme.ground
    font.family: Theme.ui

    RowLayout {
        anchors.fill: parent
        spacing: 0

        Rail {
            Layout.fillHeight: true
            Layout.preferredWidth: 212
        }
        Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Theme.lineSoft }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0

            ShowBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 88
            }
            Rectangle { Layout.fillWidth: true; Layout.preferredHeight: 1; color: Theme.lineSoft }

            StackLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                currentIndex: ["console", "show", "waves", "timecode", "macros", "settings"].indexOf(Shell.page)
                ConsolePage {}
                ShowPage { actions: showActions; resolver: resolver }
                WavesPage {}
                TimecodePage {}
                MacrosPage {}
                SettingsPage {}
            }
        }
    }

    // A page whose feature was switched off is left for the console page.
    function leaveHidden() {
        if ((Shell.page === "waves" && !Features.wavesOn)
                || (Shell.page === "timecode" && !Features.timecodeOn)
                || (Shell.page === "macros" && !Features.macrosOn))
            Shell.setPage("console")
    }
    Connections { target: Features; function onChanged() { win.leaveHidden() } }
    Component.onCompleted: leaveHidden()

    // Show files: one set of actions for the SHOW page and the keyboard.
    ShowActions { id: showActions }
    Shortcut { sequences: [StandardKey.Save]; onActivated: showActions.save() }
    Shortcut { sequences: [StandardKey.SaveAs]; onActivated: showActions.saveAs() }
    Shortcut { sequences: [StandardKey.Open]; onActivated: showActions.openShow() }
    Shortcut { sequences: [StandardKey.New]; onActivated: showActions.newShow() }

    // The desk no longer matches the show: asked when the desk check finds it.
    ResolveDialog { id: resolver }

    // One line at the foot of the window for what just happened -- scene and cue notices.
    Toast {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
    }
}
