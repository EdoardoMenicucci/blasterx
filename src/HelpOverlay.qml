import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

// Every shortcut, toggled with ?.
Rectangle {
    id: root
    color: "#cc0e0e10"

    readonly property var rows: [
        ["1 – 6", qsTr("Go to a page")],
        ["Space", qsTr("Turn the Acoustic Engine on or off")],
        ["O", qsTr("Switch between speakers and headphones")],
        ["+  /  −", qsTr("Master volume up or down")],
        ["M", qsTr("Mute or unmute")],
        ["Ctrl+Z", qsTr("Undo")],
        ["Ctrl+Shift+Z", qsTr("Redo")],
        ["Ctrl+S", qsTr("Save the settings as a profile")],
        ["?", qsTr("Show or hide this help")],
        ["Q", qsTr("Quit")]
    ]

    MouseArea { anchors.fill: parent; onClicked: root.visible = false }

    Panel {
        anchors.centerIn: parent
        width: 460
        title: qsTr("Keyboard shortcuts")
        GridLayout {
            columns: 2
            columnSpacing: 24
            rowSpacing: 10
            Layout.fillWidth: true
            Repeater {
                model: root.rows.length * 2
                Label {
                    readonly property var row: root.rows[Math.floor(index / 2)]
                    text: index % 2 === 0 ? row[0] : row[1]
                    color: index % 2 === 0 ? theme.accent : Style.text
                    font.pixelSize: 14
                    font.family: index % 2 === 0 ? "monospace" : Qt.application.font.family
                    Layout.fillWidth: index % 2 === 1
                }
            }
        }
    }
}
