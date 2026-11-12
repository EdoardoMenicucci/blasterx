import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

// One on/off control of the card, with a label and an optional explanation.
RowLayout {
    id: root
    property string control
    property string label: control
    property string description: ""
    readonly property var meta: backend.info[control]

    visible: meta !== undefined
    Layout.fillWidth: true
    spacing: 12

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 1
        Label {
            text: root.label
            color: root.enabled ? Style.text : Style.faint
            font.pixelSize: 14
            Layout.fillWidth: true
            elide: Text.ElideRight
        }
        Label {
            visible: root.description !== ""
            text: root.description
            color: Style.dim
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }
    Switch {
        checked: !!backend.values[root.control]
        enabled: root.meta !== undefined && root.meta.writable
        onToggled: backend.set(root.control, checked)
    }
}
