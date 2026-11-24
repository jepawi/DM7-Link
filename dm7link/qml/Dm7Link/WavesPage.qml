import QtQuick
import QtQuick.Layouts

// WAVES: the rack bridge, inside this app. SuperRack's ProLink connects here.
Item {
    id: page
    readonly property var tabs: [
        { key: "channels", label: "Channels" },
        { key: "scenes",   label: "Scenes" },
        { key: "superrack", label: "SuperRack" },
        { key: "setup",    label: "Setup" }
    ]
    property string tab: initialSection !== "" ? initialSection : "channels"

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // tabs
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 56
            Row {
                x: 36
                anchors.bottom: parent.bottom
                spacing: 28
                Repeater {
                    model: page.tabs
                    delegate: Item {
                        required property var modelData
                        readonly property bool on: page.tab === modelData.key
                        width: tl.implicitWidth
                        height: 42
                        activeFocusOnTab: true
                        Keys.onReturnPressed: page.tab = modelData.key
                        Text {
                            id: tl
                            anchors.top: parent.top
                            text: modelData.label
                            color: parent.on ? Theme.text : tma.containsMouse ? Theme.text : Theme.text2
                            font.family: Theme.cond
                            font.pixelSize: 19
                            font.weight: parent.on ? Font.DemiBold : Font.Medium
                        }
                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width; height: 2
                            color: parent.on ? Theme.text : parent.activeFocus ? Theme.text2 : "transparent"
                        }
                        MouseArea { id: tma; anchors.fill: parent; hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor; onClicked: page.tab = modelData.key }
                    }
                }
            }
            Row {
                anchors.right: parent.right
                anchors.rightMargin: 36
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10
                SLamp { anchors.verticalCenter: parent.verticalCenter; state: Waves.pcAnswering ? "ok" : "busy" }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Waves.pcAnswering ? "SuperRack connected" : "Waiting for SuperRack on port " + Waves.srPort
                    color: Theme.text2
                    font.family: Theme.ui
                    font.pixelSize: Theme.small + 1
                }
            }
            Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Theme.lineSoft }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: ["channels", "scenes", "superrack", "setup"].indexOf(page.tab)
            WavesChannels {}
            WavesScenes {}
            WavesRemote {}
            WavesSetup {}
        }
    }
}
