import QtQuick
import QtQuick.Controls.Basic

// A list to choose one from, opened under whatever asked for it.
// items = [{label, raw, hint?}]. A search field appears once the list is long.
Popup {
    id: p
    property var items: []
    property string title
    property string current
    property string clearLabel: ""        // a first row that chooses nothing
    signal chosen(string raw, string label)
    property string query: ""
    readonly property var shown: {
        var q = query.toLowerCase()
        var out = []
        for (var i = 0; i < items.length; i++) {
            var it = items[i]
            if (!q || String(it.label).toLowerCase().indexOf(q) >= 0
                   || String(it.hint || "").toLowerCase().indexOf(q) >= 0)
                out.push(it)
        }
        return out
    }
    width: 320
    padding: 0
    modal: true
    dim: false
    focus: true
    onOpened: { query = ""; if (search.visible) search.forceActiveFocus() }
    background: Rectangle {
        color: Theme.raised
        radius: Theme.radius + 2
        border.width: 1
        border.color: Theme.line
    }
    contentItem: Column {
        spacing: 0
        Text {
            visible: p.title !== ""
            width: parent.width
            leftPadding: 14; topPadding: 12; bottomPadding: 6
            text: p.title
            color: Theme.text2
            font.family: Theme.ui
            font.pixelSize: Theme.small + 1
        }
        Item {
            width: parent.width
            height: search.visible ? 44 : 0
            SField {
                id: search
                visible: p.items.length > 8
                anchors.fill: parent
                anchors.margins: 6
                placeholderText: "Search"
                text: p.query
                onTextChanged: p.query = text
                Keys.onReturnPressed: if (p.shown.length) { p.chosen(p.shown[0].raw, p.shown[0].label); p.close() }
            }
        }
        Rectangle {
            visible: p.clearLabel !== ""
            width: parent.width; height: 36
            color: clr.containsMouse ? Theme.hover : "transparent"
            Text {
                anchors.verticalCenter: parent.verticalCenter
                x: 14
                text: p.clearLabel
                color: Theme.text2
                font.family: Theme.ui; font.pixelSize: Theme.body; font.italic: true
            }
            MouseArea { id: clr; anchors.fill: parent; hoverEnabled: true
                        onClicked: { p.chosen("", ""); p.close() } }
        }
        ListView {
            id: list
            width: parent.width
            height: Math.min(contentHeight, 360)
            clip: true
            model: p.shown
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: list.contentHeight > list.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff }
            delegate: Rectangle {
                required property var modelData
                width: list.width
                height: 36
                color: ma.containsMouse ? Theme.hover : "transparent"
                readonly property bool isCurrent: String(modelData.raw) === p.current && p.current !== ""
                Rectangle { width: 3; height: parent.height; color: Theme.text; visible: parent.isCurrent }
                Text {
                    id: lab
                    anchors.verticalCenter: parent.verticalCenter
                    x: 14
                    width: parent.width - 28 - (hint.visible ? hint.implicitWidth + 12 : 0)
                    text: modelData.label
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Theme.ui
                    font.pixelSize: Theme.body
                    font.weight: parent.isCurrent ? Font.DemiBold : Font.Normal
                }
                Text {
                    id: hint
                    visible: !!modelData.hint
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 14
                    width: Math.min(implicitWidth, parent.width * 0.5)
                    elide: Text.ElideRight
                    text: modelData.hint || ""
                    color: Theme.text3
                    font.family: Theme.ui
                    font.pixelSize: Theme.small + 1
                }
                MouseArea {
                    id: ma
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { p.chosen(String(modelData.raw), String(modelData.label)); p.close() }
                }
            }
        }
        Text {
            visible: p.shown.length === 0
            width: parent.width
            padding: 14
            text: p.items.length ? "No match" : "Nothing to choose yet"
            color: Theme.text3
            font.family: Theme.ui
            font.pixelSize: Theme.body
        }
        Item { width: 1; height: 6 }
    }
}
