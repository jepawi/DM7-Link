import QtQuick

// One part of a block's sentence: a plain word, or a chip that fills a slot when clicked.
// part = {text, style, slot, empty}; style: word | ref | var | meter | value | text | add
Item {
    id: c
    property var part: ({})
    property bool first: false
    property bool dim: false
    property int maxWidth: 520
    signal clicked()

    readonly property string style: part.style !== undefined ? part.style : "word"
    readonly property bool tappable: style !== "word"
    readonly property bool empty: part.empty === true
    readonly property string raw: part.text !== undefined ? String(part.text) : ""

    // The engine writes its keywords in capitals (SET, END IF, ON). Here they read as words.
    function wordText(t) {
        if (!/^[A-Z][A-Z —-]*$/.test(t) || t.length < 2) return t
        var low = t.toLowerCase()
        return c.first ? low.charAt(0).toUpperCase() + low.slice(1) : low
    }
    // ...and the fade curves the engine writes in capitals read as words. Only those: a chip
    // holding HPF, PEQ, DCA or GPI is the desk's own technical name and stays as it is.
    readonly property var words: ({ "LINEAR": "Linear", "LOG": "Log", "LOGARITHMIC": "Logarithmic",
                                    "EXP": "Exp", "EXPONENTIAL": "Exponential" })
    readonly property string shown: !tappable ? wordText(raw) : (words[raw] || raw)

    implicitHeight: 30
    implicitWidth: tappable ? Math.min(maxWidth, label.implicitWidth + 20) : label.implicitWidth + 2

    Rectangle {
        anchors.fill: parent
        visible: c.tappable
        radius: Theme.radius
        color: c.empty ? "transparent"
             : ma.containsMouse ? Theme.hover
             : c.style === "add" ? "transparent" : Theme.raised
        border.width: c.empty || c.style === "add" || c.style === "var" || c.style === "meter" ? 1 : 0
        border.color: c.empty ? Theme.text3
                    : c.style === "var" || c.style === "meter" ? Qt.darker(Theme.ok, 1.4)
                    : Theme.line
    }
    Text {
        id: label
        anchors.centerIn: parent
        width: c.tappable ? Math.min(implicitWidth, c.maxWidth - 20) : implicitWidth
        elide: Text.ElideMiddle
        text: c.style === "text" ? c.shown : c.shown
        color: c.dim ? Theme.text3
             : c.empty ? Theme.text3
             : c.style === "word" ? Theme.text2
             : c.style === "var" || c.style === "meter" ? Theme.ok
             : Theme.text
        font.family: Theme.ui
        font.pixelSize: Theme.body
        font.italic: c.empty
        font.weight: c.tappable && !c.empty ? Font.Medium : Font.Normal
    }
    MouseArea {
        id: ma
        anchors.fill: parent
        enabled: c.tappable
        hoverEnabled: true
        cursorShape: c.tappable ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: c.clicked()
    }
}
