import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A page body that scrolls when the window is short. Children stack in a
// column as wide as the page, capped so lines stay readable.
ScrollView {
    id: root
    default property alias content: column.data
    property string heading: ""
    property string intro: ""
    contentWidth: availableWidth
    clip: true

    ColumnLayout {
        id: column
        width: Math.min(root.availableWidth - 56, 980)
        x: 28
        spacing: 16

        Item { implicitHeight: 12 }
        Label {
            visible: root.heading !== ""
            text: root.heading
            color: "#ececf1"
            font.pixelSize: 24
            font.weight: Font.DemiBold
        }
        Label {
            visible: root.intro !== ""
            text: root.intro
            color: "#8d8d98"
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            Layout.bottomMargin: 4
        }
    }
}
