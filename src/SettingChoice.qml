import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

// A choice of the card: segments for a few options, a menu for many. The
// driver's own item names are replaced by `labels` when given, in order.
ColumnLayout {
    id: root
    property string control
    property string label: control
    property string description: ""
    property var labels: []
    property int segmentLimit: 5
    readonly property var meta: backend.info[control]
    readonly property var items: meta ? meta.items : []
    readonly property int value: backend.values[control] ?? 0
    readonly property bool writable: meta !== undefined && meta.writable

    function textFor(index) {
        return root.labels.length > index && root.labels[index] ? root.labels[index] : root.items[index]
    }

    visible: meta !== undefined
    Layout.fillWidth: true
    spacing: 6

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
    Flow {
        visible: root.items.length <= root.segmentLimit
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: root.items.length
            ChoiceButton {
                text: root.textFor(index)
                current: index === root.value
                enabled: root.writable
                onClicked: backend.set(root.control, index)
            }
        }
    }
    ComboBox {
        visible: root.items.length > root.segmentLimit
        Layout.fillWidth: true
        Layout.maximumWidth: 320
        enabled: root.writable
        model: root.items.map((_, i) => root.textFor(i))
        currentIndex: root.value
        onActivated: (index) => backend.set(root.control, index)
    }
}
