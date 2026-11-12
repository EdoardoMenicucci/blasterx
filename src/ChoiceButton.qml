import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import "Style.js" as Style

// One segment of a choice: filled with the accent when it is the current one.
AbstractButton {
    id: root
    property bool current: false

    implicitHeight: 34
    implicitWidth: Math.max(64, label.implicitWidth + 28)
    hoverEnabled: true
    focusPolicy: Qt.TabFocus

    background: Rectangle {
        radius: Math.min(4, theme.radius)
        color: root.current ? theme.accent : root.hovered ? Style.raised : "transparent"
        border.color: root.current ? theme.accent : root.visualFocus ? theme.accent : Style.line
        opacity: root.enabled ? 1 : 0.45
    }
    contentItem: Label {
        id: label
        text: root.text
        color: root.current ? theme.accentForeground : Style.text
        font.pixelSize: 13
        font.weight: root.current ? Font.DemiBold : Font.Normal
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        opacity: root.enabled ? 1 : 0.6
    }
}
