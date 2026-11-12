import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

// One Sound Blaster effect: its switch in the header, its strength below,
// and any extra settings after that.
Panel {
    id: root
    property string switchControl
    property string levelControl: ""
    property string levelLabel: qsTr("Strength")
    property bool engineOn: true
    readonly property bool on: !!backend.values[switchControl]
    default property alias extra: extraColumn.data

    visible: backend.info[switchControl] !== undefined
    Layout.fillWidth: true
    Layout.alignment: Qt.AlignTop
    opacity: engineOn ? 1 : 0.55

    headerExtra: Switch {
        checked: root.on
        onToggled: backend.set(root.switchControl, checked)
    }

    SettingSlider {
        visible: root.levelControl !== "" && backend.info[root.levelControl] !== undefined
        control: root.levelControl
        label: root.levelLabel
        enabled: root.on
    }
    ColumnLayout {
        id: extraColumn
        Layout.fillWidth: true
        spacing: 14
        enabled: root.on
    }
}
