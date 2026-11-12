import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

// Every control the driver exposes, by its ALSA name, for anything the
// other pages leave out.
PageScroll {
    id: page
    heading: qsTr("All controls")
    intro: qsTr("Every control of the driver under its ALSA name, the same names `blasterx set` takes.")

    TextField {
        id: filter
        placeholderText: qsTr("Filter")
        Layout.fillWidth: true
        Layout.maximumWidth: 360
    }

    Panel {
        Repeater {
            model: backend.names.filter(n => n.toLowerCase().indexOf(filter.text.toLowerCase()) >= 0
                                             && !n.includes("Phantom"))
            Loader {
                id: row
                required property string modelData
                readonly property var meta: backend.info[modelData]
                Layout.fillWidth: true
                sourceComponent: !meta ? null
                               : !meta.writable ? readOnly
                               : meta.type === "boolean" ? toggle
                               : meta.type === "enum" ? choice : level

                Component { id: toggle; SettingSwitch { control: row.modelData } }
                Component { id: choice; SettingChoice { control: row.modelData; segmentLimit: 3 } }
                Component {
                    id: level
                    SettingSlider {
                        control: row.modelData
                        format: function (v) { return v + " (" + minimum + "–" + maximum + ")" }
                    }
                }
                Component {
                    id: readOnly
                    RowLayout {
                        Label { text: row.modelData; color: Style.dim; font.pixelSize: 14; Layout.fillWidth: true }
                        Label {
                            readonly property var v: backend.values[row.modelData]
                            text: row.meta.type === "boolean" ? (v ? qsTr("on") : qsTr("off"))
                                : row.meta.type === "enum" ? row.meta.items[v] : String(v)
                            color: Style.dim
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }

    Item { implicitHeight: 12 }
}
