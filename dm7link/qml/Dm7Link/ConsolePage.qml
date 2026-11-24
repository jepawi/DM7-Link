import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

// CONSOLE: find the DM7 on the network, connect, and see the link.
Item {
    id: page
    Component.onCompleted: if (!Session.online && Session.found.length === 0) Session.scan()

    readonly property string phaseText: {
        switch (Session.phase) {
        case "online": return "Connected"
        case "connecting": return "Connecting"
        case "subscribing": return "Opening the session"
        case "syncing": return "Reading the console"
        }
        return Session.retryIn > 0 ? "Retrying in " + Session.retryIn + " s" : "Not connected"
    }

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

            // -- left: status, then the address --------------------------------------
            ColumnLayout {
                Layout.preferredWidth: 440
                Layout.alignment: Qt.AlignTop
                spacing: 28

                Column {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: page.phaseText
                        color: Session.online ? Theme.text : Theme.text
                        font.family: Theme.cond
                        font.pixelSize: 44
                        font.weight: Font.DemiBold
                    }
                    Row {
                        spacing: 8
                        SLamp {
                            anchors.verticalCenter: parent.verticalCenter
                            state: Session.online ? "ok" : Session.busy ? "busy" : Session.message ? "bad" : "off"
                        }
                        Text {
                            text: Session.online ? (Session.consoleName || "DM7") + "  ·  " + Session.ip
                                  : Session.message || "Choose a console to connect to"
                            color: Theme.text2
                            font.family: Theme.ui
                            font.pixelSize: Theme.label
                        }
                    }
                    Text {
                        visible: !Session.online && Session.detail !== ""
                        width: 440
                        text: Session.detail
                        color: Theme.text3
                        font.family: Theme.ui
                        font.pixelSize: Theme.small + 1
                        wrapMode: Text.WordWrap
                    }
                }

                SSection {
                    Layout.fillWidth: true
                    title: "Console address"
                    RowLayout {
                        width: parent.width
                        spacing: 8
                        SField {
                            id: ip
                            Layout.fillWidth: true
                            mono: true
                            text: Session.ip
                            placeholderText: "192.168.0.2"
                            onTextEdited: Session.setIp(text)
                            onAccepted: Session.connectNow()
                            Connections { target: Session; function onIpChanged() { if (!ip.activeFocus) ip.text = Session.ip } }
                        }
                        SButton {
                            kind: "primary"
                            text: Session.online && !Session.dirty ? "Reconnect" : "Connect"
                            enabled: Session.valid
                            onClicked: Session.connectNow()
                        }
                    }
                    Row {
                        spacing: 8
                        topPadding: 6
                        SButton {
                            visible: Session.online || Session.busy || Session.retryIn > 0
                            text: Session.busy || Session.retryIn > 0 ? "Stop" : "Disconnect"
                            onClicked: Session.busy || Session.retryIn > 0 ? Session.pauseRetry() : Session.disconnect()
                        }
                        SButton {
                            visible: Session.retryIn > 0
                            kind: "quiet"
                            text: "Retry now"
                            onClicked: Session.retryNow()
                        }
                    }
                    Flow {
                        width: parent.width
                        spacing: 6
                        topPadding: 8
                        visible: Session.recentIps.length > 0
                        Text {
                            text: "Recent"
                            color: Theme.text3
                            font.family: Theme.ui
                            font.pixelSize: Theme.small + 1
                            height: 28
                            verticalAlignment: Text.AlignVCenter
                            rightPadding: 4
                        }
                        Repeater {
                            model: Session.recentIps
                            delegate: SButton {
                                required property var modelData
                                compact: true
                                kind: "quiet"
                                text: modelData
                                onClicked: { Session.setIp(modelData); Session.connectNow() }
                            }
                        }
                    }
                }
            }

            // -- right: consoles found on the network ---------------------------------
            SSection {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                title: "Consoles on the network"
                caption: Session.scanning ? "Searching…" : Session.found.length === 0
                         ? "None found. Check that this computer is on the console's network, or type the address."
                         : Session.found.length + (Session.found.length === 1 ? " console" : " consoles")
                trailing: SButton { text: Session.scanning ? "Searching" : "Rescan"; enabled: !Session.scanning
                                    onClicked: Session.scan() }

                Repeater {
                    model: Session.found
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool current: Session.online && Session.ip === modelData.ip
                        width: parent.width
                        height: 64
                        radius: Theme.radius
                        color: fma.containsMouse ? Theme.raised : Theme.surface
                        border.width: current ? 1 : 0
                        border.color: Theme.text2
                        Column {
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 2
                            Text {
                                text: modelData.name || modelData.label || modelData.model || "DM7"
                                color: Theme.text
                                font.family: Theme.cond
                                font.pixelSize: 20
                                font.weight: Font.DemiBold
                            }
                            Text {
                                text: [modelData.maker, modelData.model].filter(function (s) { return !!s }).join(" ")
                                      + (modelData.model ? "   " : "") + modelData.ip
                                color: Theme.text2
                                font.family: Theme.ui
                                font.pixelSize: Theme.small + 1
                            }
                        }
                        SButton {
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.current ? "Connected" : "Connect"
                            kind: parent.current ? "quiet" : "secondary"
                            enabled: !parent.current
                            onClicked: Session.useFound(modelData.ip)
                        }
                        MouseArea {
                            id: fma
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.NoButton
                        }
                    }
                }
            }
        }
    }
}
