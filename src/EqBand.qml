import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

// One band of the graphic equalizer, ±24 dB around the middle of its range.
ColumnLayout {
    id: root
    property string control
    property string frequency
    readonly property var meta: backend.info[control]
    readonly property int middle: meta ? Math.round((meta.min + meta.max) / 2) : 0
    readonly property int value: backend.values[control] ?? middle
    property alias slider: slider

    spacing: 4
    Layout.fillWidth: true

    Label {
        text: Style.signedDb(root.value - root.middle)
        color: root.value === root.middle ? Style.dim : Style.text
        font.pixelSize: 12
        font.features: { "tnum": 1 }
        Layout.alignment: Qt.AlignHCenter
    }
    Slider {
        id: slider
        orientation: Qt.Vertical
        from: root.meta ? root.meta.min : 0
        to: root.meta ? root.meta.max : 48
        stepSize: 1
        value: root.value
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignHCenter
        onMoved: backend.set(root.control, value)
    }
    Label {
        text: root.frequency
        color: Style.dim
        font.pixelSize: 12
        Layout.alignment: Qt.AlignHCenter
    }
}
