import QtQuick
import QtQuick.Controls.Basic

// A name or a line of text, typed: a new folder, a renamed folder.
Popup {
    id: d
    property string title
    property string placeholder
    property string action: "Save"
    property bool allowEmpty: false
    signal accepted(string text)

    function ask(t, current, ph, act) {
        d.title = t
        d.placeholder = ph || ""
        d.action = act || "Save"
        field.text = current || ""
        d.open()
    }
    anchors.centerIn: Overlay.overlay
    width: 420
    modal: true
    focus: true
    padding: 22
    onOpened: { field.forceActiveFocus(); field.selectAll() }
    background: Rectangle { color: Theme.raised; radius: Theme.radius + 2; border.width: 1; border.color: Theme.line }
    Overlay.modal: Rectangle { color: "#99000000" }
    contentItem: Column {
        spacing: 14
        Text { text: d.title; color: Theme.text; font.family: Theme.cond; font.pixelSize: Theme.h2
               font.weight: Font.DemiBold }
        SField { id: field; width: 376; placeholderText: d.placeholder; onAccepted: ok.clicked() }
        Row {
            spacing: 8
            SButton { id: ok; kind: "primary"; text: d.action
                      enabled: d.allowEmpty || field.text.trim() !== ""
                      onClicked: { d.accepted(field.text.trim()); d.close() } }
            SButton { kind: "quiet"; text: "Cancel"; onClicked: d.close() }
        }
    }
}
