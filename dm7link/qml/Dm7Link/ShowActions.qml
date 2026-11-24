import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Dialogs

// New, open, save and save as -- for the SHOW page and the keyboard alike. An action that would
// replace the working show asks first when it has changes that are not saved.
Item {
    id: acts

    // What runs once the unsaved changes are dealt with: "new", "open", or a path to open.
    property string pending: ""

    function newShow() { acts.guard("new") }
    function openShow() { acts.guard("open") }
    function openPath(path) { acts.guard(path) }
    function save() { if (!Show.save()) saveDialog.open() }
    function saveAs() { saveDialog.open() }

    function guard(what) {
        acts.pending = what
        if (Show.modified) unsaved.open()
        else acts.proceed()
    }
    function proceed() {
        var what = acts.pending
        acts.pending = ""
        if (what === "new") Show.newShow()
        else if (what === "open") openDialog.open()
        else if (what !== "") Show.open(what)
    }

    FileDialog {
        id: openDialog
        title: "Open show"
        nameFilters: ["DM7 Link shows (*" + Show.suffix + ")"]
        currentFolder: Show.folderUrl
        onAccepted: Show.open(selectedFile.toString())
    }
    FileDialog {
        id: saveDialog
        title: "Save show as"
        fileMode: FileDialog.SaveFile
        defaultSuffix: Show.suffix.substring(1)
        nameFilters: ["DM7 Link shows (*" + Show.suffix + ")"]
        currentFolder: Show.folderUrl
        selectedFile: Show.fileUrl
        onAccepted: {
            if (Show.saveAs(selectedFile.toString()) && acts.pending !== "")
                acts.proceed()
        }
        onRejected: acts.pending = ""
    }

    Popup {
        id: unsaved
        anchors.centerIn: Overlay.overlay
        width: 440
        modal: true
        focus: true
        padding: 22
        background: Rectangle { color: Theme.raised; radius: Theme.radius + 2; border.width: 1; border.color: Theme.line }
        Overlay.modal: Rectangle { color: "#99000000" }
        contentItem: Column {
            spacing: 16
            Text { width: 396; wrapMode: Text.WordWrap
                   text: "Save changes to “" + Show.name + "”?"
                   color: Theme.text; font.family: Theme.cond; font.pixelSize: Theme.h2; font.weight: Font.DemiBold }
            Row {
                spacing: 8
                SButton { kind: "primary"; text: "Save"
                          onClicked: {
                              unsaved.close()
                              if (Show.save()) acts.proceed()
                              else saveDialog.open()
                          } }
                SButton { text: "Don’t save"; onClicked: { unsaved.close(); acts.proceed() } }
                SButton { kind: "quiet"; text: "Cancel"; onClicked: { unsaved.close(); acts.pending = "" } }
            }
        }
    }
}
