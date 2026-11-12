import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

// A level of the card. A muteControl adds its switch beside the label and
// greys the slider while it is off.
ColumnLayout {
    id: root
    property string control
    property string label: control
    property string muteControl: ""
    property var format: function (v) { return Style.percent(v, root.minimum, root.maximum) }
    readonly property var meta: backend.info[control]
    readonly property int minimum: meta ? meta.min : 0
    readonly property int maximum: meta ? meta.max : 1
    readonly property int value: backend.values[control] ?? 0
    readonly property bool muted: muteControl !== "" && backend.info[muteControl] !== undefined
                                  && !backend.values[muteControl]

    visible: meta !== undefined
    Layout.fillWidth: true
    spacing: 0

    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Label {
            text: root.label
            color: root.enabled ? Style.text : Style.faint
            font.pixelSize: 14
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        Label {
            text: root.format(root.value)
            color: root.enabled && !root.muted ? Style.dim : Style.faint
            font.pixelSize: 13
            font.features: { "tnum": 1 }
        }
        Switch {
            visible: root.muteControl !== "" && backend.info[root.muteControl] !== undefined
            checked: !!backend.values[root.muteControl]
            onToggled: backend.set(root.muteControl, checked)
            Layout.preferredHeight: 32
        }
    }
    Slider {
        Layout.fillWidth: true
        from: root.minimum
        to: root.maximum
        stepSize: 1
        // The driver can report a value outside its own range (the wedge
        // angle starts at 10 of 20–180), so the handle is clamped for display.
        value: Math.max(root.minimum, Math.min(root.maximum, root.value))
        enabled: root.meta !== undefined && root.meta.writable && !root.muted
        onMoved: backend.set(root.control, value)
    }
}
