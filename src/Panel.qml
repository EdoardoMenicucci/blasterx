import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

// A titled card. Children stack in a column under the title.
Rectangle {
    id: root
    property string title: ""
    property string subtitle: ""
    property alias headerExtra: headerRow.data
    default property alias content: column.data
    property int padding: 20

    Layout.fillWidth: true
    implicitHeight: column.implicitHeight + padding * 2 + (header.visible ? header.implicitHeight + 14 : 0)
    color: Style.panel
    radius: theme.radius
    border.color: Style.line

    ColumnLayout {
        id: header
        visible: root.title !== ""
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.padding }
        spacing: 2
        RowLayout {
            Layout.fillWidth: true
            Label {
                text: root.title
                color: Style.text
                font.pixelSize: 16
                font.weight: Font.DemiBold
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
            RowLayout { id: headerRow }
        }
        Label {
            visible: root.subtitle !== ""
            text: root.subtitle
            color: Style.dim
            font.pixelSize: 13
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
    }

    ColumnLayout {
        id: column
        anchors {
            left: parent.left; right: parent.right
            top: header.visible ? header.bottom : parent.top
            leftMargin: root.padding; rightMargin: root.padding
            topMargin: header.visible ? 14 : root.padding
        }
        spacing: 14
    }
}
