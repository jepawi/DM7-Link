import QtQuick
import QtQuick.Controls.Basic

// The desk no longer matches the show: one row per scene or channel the show refers to that
// moved, was renamed or is gone, each with what to do about it. Opens by itself when the desk
// check finds something; APPLY changes the show, LATER leaves it and asks again next connect.
Popup {
    id: d
    property var choices: ({})
    readonly property var issues: Show.issues

    anchors.centerIn: Overlay.overlay
    width: Math.min(700, (Overlay.overlay ? Overlay.overlay.width : 900) - 80)
    height: Math.min(implicitHeight, (Overlay.overlay ? Overlay.overlay.height : 700) - 80)
    modal: true
    focus: true
    padding: 24
    closePolicy: Popup.NoAutoClose
    background: Rectangle { color: Theme.raised; radius: Theme.radius + 2; border.width: 1; border.color: Theme.line }
    Overlay.modal: Rectangle { color: "#99000000" }

    onOpened: d.choices = ({})
    Connections {
        target: Show
        function onIssuesChanged() {
            if (Show.issues.length > 0 && !d.opened) d.open()
            else if (Show.issues.length === 0 && d.opened) d.close()
        }
    }

    function picked(issue) {
        return d.choices[issue.id] !== undefined ? d.choices[issue.id] : issue.choice
    }
    function pick(issue, value) {
        var next = Object.assign({}, d.choices)
        next[issue.id] = value
        d.choices = next
    }
    function kindText(kind) {
        return kind === "moved" ? "Moved" : kind === "renamed" ? "Renamed" : "Missing"
    }

    contentItem: Column {
        spacing: 18

        Column {
            width: parent.width
            spacing: 4
            Text {
                text: "The desk has changed"
                color: Theme.text
                font.family: Theme.cond
                font.pixelSize: Theme.h1
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                wrapMode: Text.WordWrap
                text: d.issues.length + (d.issues.length === 1 ? " reference in “" : " references in “")
                      + Show.name + "” no longer match" + (d.issues.length === 1 ? "es" : "")
                      + " " + (Session.consoleName || "the console") + "."
                color: Theme.text2
                font.family: Theme.ui
                font.pixelSize: Theme.body
            }
        }

        Flickable {
            id: list
            width: parent.width
            height: Math.min(rows.implicitHeight,
                             (Overlay.overlay ? Overlay.overlay.height : 700) - 80 - 2 * d.padding - 160)
            contentHeight: rows.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}

            Column {
                id: rows
                width: list.width - 12
                spacing: 10

                Repeater {
                    model: d.issues
                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        width: rows.width
                        height: inner.implicitHeight + 28
                        radius: Theme.radius
                        color: Theme.surface
                        border.width: 1
                        border.color: Theme.lineSoft

                        Column {
                            id: inner
                            x: 16; y: 14
                            width: card.width - 32
                            spacing: 8

                            Row {
                                width: parent.width
                                spacing: 10
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: tag.implicitWidth + 14
                                    height: 20
                                    radius: 10
                                    color: card.modelData.kind === "missing" ? Theme.badDim : Theme.amberDim
                                    Text {
                                        id: tag
                                        anchors.centerIn: parent
                                        text: d.kindText(card.modelData.kind)
                                        color: card.modelData.kind === "missing" ? Theme.bad : Theme.amber
                                        font.family: Theme.ui
                                        font.pixelSize: Theme.small
                                        font.weight: Font.DemiBold
                                    }
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - tag.implicitWidth - 24
                                    text: card.modelData.title
                                    elide: Text.ElideRight
                                    color: Theme.text
                                    font.family: Theme.cond
                                    font.pixelSize: 20
                                    font.weight: Font.DemiBold
                                }
                            }
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: card.modelData.now.charAt(0).toUpperCase() + card.modelData.now.slice(1)
                                      + "  ·  used by " + card.modelData.uses
                                color: Theme.text2
                                font.family: Theme.ui
                                font.pixelSize: Theme.small + 1
                            }

                            Column {
                                width: parent.width
                                spacing: 2
                                topPadding: 2
                                Repeater {
                                    model: card.modelData.options
                                    delegate: Rectangle {
                                        id: opt
                                        required property var modelData
                                        readonly property bool on: d.picked(card.modelData) === modelData.value
                                        width: parent.width
                                        height: 32
                                        radius: Theme.radius
                                        color: oma.containsMouse ? Theme.raised : "transparent"
                                        Rectangle {
                                            id: dot
                                            x: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: 16; height: 16; radius: 8
                                            color: "transparent"
                                            border.width: opt.on ? 5 : 1.5
                                            border.color: opt.on ? Theme.text : Theme.text3
                                        }
                                        Text {
                                            anchors.left: dot.right
                                            anchors.leftMargin: 10
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: opt.modelData.label
                                            elide: Text.ElideRight
                                            color: opt.on ? Theme.text : Theme.text2
                                            font.family: Theme.ui
                                            font.pixelSize: Theme.body
                                        }
                                        MouseArea {
                                            id: oma
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: d.pick(card.modelData, opt.modelData.value)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Row {
            spacing: 8
            SButton { kind: "primary"; text: "Apply"; onClicked: Show.resolve(d.choices) }
            SButton { kind: "quiet"; text: "Later"; onClicked: Show.later() }
        }
    }
}
