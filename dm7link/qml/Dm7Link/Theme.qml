pragma Singleton
import QtQuick

// DM7 Link's tokens. A FOH laptop in a dark room: graphite ground (the console's own paint),
// backlit warm-white text, and ONE colour with a meaning -- amber, which is timecode and
// what is armed to fire. Green and red are states, never decoration.
QtObject {
    // ground and surfaces
    readonly property color ground:   "#1B1E23"
    readonly property color surface:  "#22262C"
    readonly property color raised:   "#2B3037"
    readonly property color hover:    "#323840"
    readonly property color line:     "#383E47"
    readonly property color lineSoft: "#2C3138"

    // text
    readonly property color text:     "#ECEAE4"
    readonly property color text2:    "#A2A8B0"
    readonly property color text3:    "#6C737C"
    readonly property color onLight:  "#1B1E23"

    // meaning
    readonly property color amber:    "#FFB23E"
    readonly property color amberDim: "#4A3A20"
    readonly property color ok:       "#5BCF8C"
    readonly property color okDim:    "#1F3A2B"
    readonly property color bad:      "#FF6156"
    readonly property color badDim:   "#45231F"

    // type
    readonly property string ui:   "Barlow"
    readonly property string cond: "Barlow Condensed"
    readonly property int small: 12
    readonly property int body:  14
    readonly property int label: 15
    readonly property int h2:    18
    readonly property int h1:    26

    // shape
    readonly property int radius: 6
    readonly property int gap: 16
    readonly property int ctrl: 34          // control height
    readonly property int row: 44           // table row height
}
