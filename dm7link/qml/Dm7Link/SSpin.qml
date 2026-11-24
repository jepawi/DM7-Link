import QtQuick

// A whole number with − and + beside it; typed values are committed on Enter or leaving the field.
Row {
    id: sp
    property int value
    property int from: 1
    property int to: 999
    signal changed(int v)
    spacing: 4
    opacity: enabled ? 1 : 0.45

    function commit(v) {
        var n = Math.max(from, Math.min(to, v))
        if (n !== value) sp.changed(n)
        field.text = String(n)
    }
    SButton { text: "−"; compact: true; width: 30; height: Theme.ctrl; enabled: sp.enabled && sp.value > sp.from
              onClicked: sp.commit(sp.value - 1) }
    SField {
        id: field
        width: 64
        mono: true
        enabled: sp.enabled
        horizontalAlignment: TextInput.AlignHCenter
        text: String(sp.value)
        validator: IntValidator { bottom: sp.from; top: sp.to }
        onEditingFinished: sp.commit(parseInt(text) || sp.from)
        Connections { target: sp; function onValueChanged() { field.text = String(sp.value) } }
    }
    SButton { text: "+"; compact: true; width: 30; height: Theme.ctrl; enabled: sp.enabled && sp.value < sp.to
              onClicked: sp.commit(sp.value + 1) }
}
