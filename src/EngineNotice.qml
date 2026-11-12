import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

// Shown on pages whose effects need the Acoustic Engine, while it is off.
Rectangle {
    Layout.fillWidth: true
    implicitHeight: row.implicitHeight + 24
    radius: theme.radius
    color: Style.raised
    border.color: theme.accent

    RowLayout {
        id: row
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 16 }
        Label {
            text: qsTr("The Acoustic Engine is off, so these effects are bypassed.")
            color: Style.text
            font.pixelSize: 14
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }
        Button {
            text: qsTr("Turn on")
            highlighted: true
            onClicked: backend.set("Enable OutFX Playback Switch", true)
        }
    }
}
