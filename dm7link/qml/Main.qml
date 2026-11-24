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
    title: "DM7 Link"
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
                currentIndex: ["console", "waves", "timecode", "macros", "settings"].indexOf(Shell.page)
                ConsolePage {}
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

    // One line at the foot of the window for what just happened -- scene and cue notices.
    Toast {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
    }
}
