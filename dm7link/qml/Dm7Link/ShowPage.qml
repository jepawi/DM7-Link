import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// SHOW: the show file -- new, open, save -- the desk it was built against, and working offline.
Item {
    id: page
    property var actions
    property var resolver
    readonly property var desk: Show.desk

    Flickable {
        anchors.fill: parent
        contentHeight: body.implicitHeight + 64
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar {}

        RowLayout {
            id: body
            x: 36; y: 32
            width: page.width - 72
            spacing: 48

            // -- left: the show, and the desk ------------------------------------------
            ColumnLayout {
                Layout.preferredWidth: 480
                Layout.alignment: Qt.AlignTop
                spacing: 28

                Column {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        width: parent.width
                        text: Show.name
                        elide: Text.ElideRight
                        color: Theme.text
                        font.family: Theme.cond
                        font.pixelSize: 44
                        font.weight: Font.DemiBold
                    }
                    Row {
                        spacing: 8
                        SLamp {
                            anchors.verticalCenter: parent.verticalCenter
                            state: Show.modified ? "armed" : Show.path !== "" ? "ok" : "off"
                        }
                        Text {
                            text: Show.modified ? "Not saved" : Show.path !== "" ? "Saved" : "Never saved"
                            color: Theme.text2
                            font.family: Theme.ui
                            font.pixelSize: Theme.label
                        }
                    }
                    Text {
                        visible: Show.path !== ""
                        width: parent.width
                        text: Show.path
                        elide: Text.ElideMiddle
                        color: Theme.text3
                        font.family: Theme.ui
                        font.pixelSize: Theme.small + 1
                    }
                    Row {
                        spacing: 8
                        topPadding: 14
                        SButton { kind: "primary"; text: "Save"; onClicked: page.actions.save() }
                        SButton { text: "Save as…"; onClicked: page.actions.saveAs() }
                        SButton { text: "Open…"; onClicked: page.actions.openShow() }
                        SButton { text: "New"; onClicked: page.actions.newShow() }
                    }
                }

                SSection {
                    Layout.fillWidth: true
                    title: "Desk"
                    caption: !page.desk.known ? "No desk read yet"
                             : [page.desk.name || "DM7", page.desk.firmware, "read " + page.desk.captured]
                               .filter(function (s) { return !!s }).join("  ·  ")
                    trailing: SButton {
                        visible: Show.issues.length > 0
                        kind: "primary"
                        text: Show.issues.length + (Show.issues.length === 1 ? " mismatch" : " mismatches")
                        onClicked: resolver.open()
                    }

                    Repeater {
                        model: page.desk.known ? [
                            { label: "Scenes, bank A", value: page.desk.scenesA },
                            { label: "Scenes, bank B", value: page.desk.scenesB },
                            { label: "Named channels", value: page.desk.channels }
                        ] : []
                        delegate: RowLayout {
                            required property var modelData
                            width: parent.width
                            height: 30
                            Text { Layout.fillWidth: true; text: modelData.label; color: Theme.text2
                                   font.family: Theme.ui; font.pixelSize: Theme.body }
                            Text { text: modelData.value; color: Theme.text
                                   font.family: Theme.cond; font.pixelSize: 19; font.weight: Font.DemiBold }
                        }
                    }
                }

                SSection {
                    Layout.fillWidth: true
                    title: "Offline"
                    SSwitch {
                        width: parent.width
                        text: "Work offline"
                        caption: !Session.offline ? "Connected to the console"
                                 : Session.offlineFrom === "blank" ? "Blank DM7, no scenes"
                                 : Session.offlineFrom === "show" ? "The show’s desk"
                                 : Session.message
                        checked: Session.offline
                        onToggled: on => Session.setOffline(on)
                    }
                }
            }

            // -- right: recent shows ----------------------------------------------------
            SSection {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                title: "Recent shows"
                caption: Show.recent.length === 0 ? "None" : ""

                Repeater {
                    model: Show.recent
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property bool current: modelData.path === Show.path
                        width: parent.width
                        height: 60
                        radius: Theme.radius
                        color: rma.containsMouse ? Theme.raised : Theme.surface
                        border.width: current ? 1 : 0
                        border.color: Theme.text2
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.right: buttons.left
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                width: parent.width
                                text: row.modelData.name
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Theme.cond
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }
                            Text {
                                width: parent.width
                                text: row.modelData.folder
                                elide: Text.ElideMiddle
                                color: Theme.text3
                                font.family: Theme.ui
                                font.pixelSize: Theme.small + 1
                            }
                        }
                        MouseArea {
                            id: rma
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                        Row {
                            id: buttons
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 6
                            SButton {
                                text: "Open"
                                kind: row.current ? "quiet" : "secondary"
                                enabled: !row.current
                                onClicked: page.actions.openPath(row.modelData.path)
                            }
                            SButton {
                                compact: true
                                kind: "quiet"
                                text: "×"
                                onClicked: Show.forgetRecent(row.modelData.path)
                            }
                        }
                    }
                }
            }
        }
    }

}
