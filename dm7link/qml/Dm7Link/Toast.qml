import QtQuick

// The last thing the scene list or the cue list said, for a few seconds.
Rectangle {
    id: t
    property string text: ""
    property string tone: ""
    visible: opacity > 0
    opacity: 0
    implicitWidth: Math.min(640, label.implicitWidth + 36)
    implicitHeight: 40
    radius: 20
    color: Theme.raised
    border.width: 1
    border.color: tone === "bad" ? Qt.darker(Theme.bad, 1.5) : Theme.line

    function show(text, tone) {
        if (!text) return
        t.text = text
        t.tone = tone || ""
        t.opacity = 1
        hide.restart()
    }
    Behavior on opacity { NumberAnimation { duration: 160 } }
    Timer { id: hide; interval: 4000; onTriggered: t.opacity = 0 }
    Text {
        id: label
        anchors.centerIn: parent
        width: Math.min(implicitWidth, 604)
        elide: Text.ElideRight
        text: t.text
        color: Theme.text
        font.family: Theme.ui
        font.pixelSize: Theme.body
    }
    Connections {
        target: Scenes
        function onNoticeChanged() { t.show(Scenes.notice, Scenes.noticeTone === "bad" || Scenes.noticeTone === "error" ? "bad" : "") }
    }
    Connections {
        target: Show
        function onNotice(text, tone) { t.show(text, tone) }
    }
    Connections {
        target: Cues
        function onNoticeChanged() { t.show(Cues.notice, "") }
    }
}
