import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

ApplicationWindow {
    id: win
    width: 1180
    height: 820
    minimumWidth: 860
    minimumHeight: 560
    visible: true
    title: "BlasterX"
    color: Style.window

    Material.theme: Material.Dark
    Material.accent: theme.accent
    Material.roundedScale: theme.radius
    Material.background: Style.panel

    property int page: 0
    property bool helpVisible: false
    readonly property var pages: [
        { title: qsTr("Output"), glyph: "◉" },
        { title: qsTr("Equalizer"), glyph: "≋" },
        { title: qsTr("Acoustic Engine"), glyph: "✦" },
        { title: qsTr("Microphone"), glyph: "●" },
        { title: qsTr("Profiles"), glyph: "▤" },
        { title: qsTr("All controls"), glyph: "⋯" }
    ]

    readonly property string engine: "Enable OutFX Playback Switch"
    readonly property string master: "Master Playback Volume"
    readonly property string masterSwitch: "Master Playback Switch"
    readonly property string output: "Output Select"

    function nudgeVolume(step) {
        const meta = backend.info[master]
        if (meta) backend.set(master, (backend.values[master] ?? 0) + step * Math.max(1, Math.round((meta.max - meta.min) / 20)))
    }

    Shortcut { sequence: "?"; context: Qt.ApplicationShortcut; onActivated: win.helpVisible = !win.helpVisible }
    Shortcut { sequence: "Escape"; context: Qt.ApplicationShortcut; enabled: win.helpVisible; onActivated: win.helpVisible = false }
    // Every change is applied to the card as it happens, so there is nothing
    // unsaved to ask about.
    Shortcut { sequence: "Q"; context: Qt.ApplicationShortcut; onActivated: Qt.quit() }
    Shortcut { sequence: "Space"; context: Qt.ApplicationShortcut; enabled: backend.available; onActivated: backend.toggle(win.engine) }
    Shortcut {
        sequence: "O"; context: Qt.ApplicationShortcut; enabled: backend.available
        onActivated: backend.set(win.output, (backend.values[win.output] ?? 0) === 0 ? 1 : 0)
    }
    Shortcut { sequences: ["+", "="]; context: Qt.ApplicationShortcut; onActivated: win.nudgeVolume(1) }
    Shortcut { sequence: "-"; context: Qt.ApplicationShortcut; onActivated: win.nudgeVolume(-1) }
    Shortcut { sequence: "M"; context: Qt.ApplicationShortcut; onActivated: backend.toggle(win.masterSwitch) }
    Shortcut { sequences: [StandardKey.Undo]; context: Qt.ApplicationShortcut; onActivated: backend.undo() }
    Shortcut { sequences: [StandardKey.Redo, "Ctrl+Shift+Z"]; context: Qt.ApplicationShortcut; onActivated: backend.redo() }
    Shortcut {
        sequences: [StandardKey.Save]; context: Qt.ApplicationShortcut; enabled: backend.available
        onActivated: { win.page = 4; profilesPage.focusName() }
    }
    Repeater {
        model: win.pages.length
        Item {
            Shortcut { sequence: String(index + 1); context: Qt.ApplicationShortcut; onActivated: win.page = index }
        }
    }

    Connections {
        target: backend
        function onMessage(text, error) {
            toast.text = text
            toast.error = error
            toast.shown = true
            toastTimer.restart()
        }
    }

    // Right-to-left languages mirror the window; the Translator sets the
    // application's layout direction.
    Item {
        anchors.fill: parent
        LayoutMirroring.enabled: Qt.application.layoutDirection === Qt.RightToLeft
        LayoutMirroring.childrenInherit: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0
            visible: backend.available

            // The card at a glance: what it is, where the sound goes, the
            // engine, and the master level.
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 72
                color: Style.panel
                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: Style.line }

                RowLayout {
                    anchors { fill: parent; leftMargin: 20; rightMargin: 24 }
                    spacing: 20

                    Rectangle {
                        width: 40; height: 40
                        radius: Math.min(10, theme.radius)
                        color: theme.accent
                        Label {
                            anchors.centerIn: parent
                            text: "X"
                            color: theme.accentForeground
                            font.pixelSize: 22
                            font.weight: Font.Black
                        }
                    }
                    ColumnLayout {
                        spacing: 0
                        Layout.minimumWidth: 140
                        Label {
                            text: backend.deviceName
                            color: Style.text
                            font.pixelSize: 16
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        Label {
                            text: !!backend.values["Headphone Jack"] ? qsTr("Headphones connected") : qsTr("Sound Blaster control")
                            color: Style.dim
                            font.pixelSize: 12
                        }
                    }

                    Item { Layout.fillWidth: true }

                    RowLayout {
                        spacing: 6
                        visible: backend.info[win.output] !== undefined
                        ChoiceButton {
                            text: qsTr("Speakers")
                            current: (backend.values[win.output] ?? 0) === 0
                            onClicked: backend.set(win.output, 0)
                        }
                        ChoiceButton {
                            text: qsTr("Headphones")
                            current: (backend.values[win.output] ?? 0) === 1
                            onClicked: backend.set(win.output, 1)
                        }
                    }

                    RowLayout {
                        spacing: 4
                        visible: backend.info[win.engine] !== undefined
                        Label { text: qsTr("Acoustic Engine"); color: Style.dim; font.pixelSize: 13 }
                        Switch {
                            checked: !!backend.values[win.engine]
                            onToggled: backend.set(win.engine, checked)
                        }
                    }

                    RowLayout {
                        spacing: 6
                        visible: backend.info[win.master] !== undefined
                        ToolButton {
                            readonly property bool muted: backend.info[win.masterSwitch] !== undefined && !backend.values[win.masterSwitch]
                            text: muted ? "🔇" : "🔊"
                            font.pixelSize: 16
                            onClicked: backend.toggle(win.masterSwitch)
                            ToolTip.visible: hovered
                            ToolTip.text: muted ? qsTr("Unmute (M)") : qsTr("Mute (M)")
                        }
                        Slider {
                            readonly property var meta: backend.info[win.master]
                            Layout.preferredWidth: 180
                            from: meta ? meta.min : 0
                            to: meta ? meta.max : 1
                            stepSize: 1
                            value: backend.values[win.master] ?? 0
                            enabled: !!backend.values[win.masterSwitch] || backend.info[win.masterSwitch] === undefined
                            onMoved: backend.set(win.master, value)
                        }
                        Label {
                            readonly property var meta: backend.info[win.master]
                            text: meta ? Style.percent(backend.values[win.master] ?? 0, meta.min, meta.max) : ""
                            color: Style.dim
                            font.pixelSize: 13
                            font.features: { "tnum": 1 }
                            Layout.preferredWidth: 40
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                // Pages, numbered by their shortcut.
                Rectangle {
                    Layout.fillHeight: true
                    Layout.preferredWidth: 220
                    color: Style.window
                    Rectangle { anchors.right: parent.right; height: parent.height; width: 1; color: Style.line }

                    ColumnLayout {
                        anchors { fill: parent; margins: 12; topMargin: 16 }
                        spacing: 4

                        Repeater {
                            model: win.pages
                            AbstractButton {
                                id: navItem
                                readonly property bool current: win.page === index
                                Layout.fillWidth: true
                                implicitHeight: 42
                                hoverEnabled: true
                                onClicked: win.page = index
                                background: Rectangle {
                                    radius: Math.min(6, theme.radius)
                                    color: navItem.current ? Style.raised : navItem.hovered ? "#16161b" : "transparent"
                                    Rectangle {
                                        visible: navItem.current
                                        width: 3; height: 20
                                        radius: 1
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: theme.accent
                                    }
                                }
                                contentItem: RowLayout {
                                    spacing: 12
                                    Label {
                                        text: modelData.glyph
                                        color: navItem.current ? theme.accent : Style.dim
                                        font.pixelSize: 15
                                        Layout.leftMargin: 14
                                        Layout.preferredWidth: 16
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Label {
                                        text: modelData.title
                                        color: navItem.current ? Style.text : Style.dim
                                        font.pixelSize: 14
                                        font.weight: navItem.current ? Font.DemiBold : Font.Normal
                                        elide: Text.ElideRight
                                        Layout.fillWidth: true
                                    }
                                    Label {
                                        text: index + 1
                                        color: Style.faint
                                        font.pixelSize: 12
                                        font.family: "monospace"
                                        Layout.rightMargin: 10
                                    }
                                }
                            }
                        }

                        Item { Layout.fillHeight: true }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4
                            ToolButton {
                                text: "↶"
                                font.pixelSize: 18
                                enabled: backend.canUndo
                                onClicked: backend.undo()
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Undo (Ctrl+Z)")
                            }
                            ToolButton {
                                text: "↷"
                                font.pixelSize: 18
                                enabled: backend.canRedo
                                onClicked: backend.redo()
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Redo (Ctrl+Shift+Z)")
                            }
                            Item { Layout.fillWidth: true }
                            ToolButton {
                                text: "?"
                                font.pixelSize: 16
                                onClicked: win.helpVisible = true
                                ToolTip.visible: hovered
                                ToolTip.text: qsTr("Keyboard shortcuts (?)")
                            }
                        }
                    }
                }

                StackLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    currentIndex: win.page

                    OutputPage {}
                    EqualizerPage {}
                    EffectsPage {}
                    MicrophonePage {}
                    ProfilesPage { id: profilesPage }
                    AllControlsPage {}
                }
            }
        }

        // No card: say why instead of showing empty controls.
        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 520)
            visible: !backend.available
            spacing: 12
            Label {
                text: qsTr("No Sound Blaster found")
                color: Style.text
                font.pixelSize: 22
                font.weight: Font.DemiBold
                Layout.alignment: Qt.AlignHCenter
            }
            Label {
                text: backend.deviceError
                color: Style.dim
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
            Label {
                text: qsTr("BlasterX works with Creative cards on the CA0132 codec: AE-5, AE-5 Plus, AE-7, AE-9, Z, ZxR and Recon3D.")
                color: Style.faint
                font.pixelSize: 13
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }

        // What just happened, or what went wrong.
        Rectangle {
            id: toast
            property string text: ""
            property bool error: false
            property bool shown: false
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: shown ? 24 : -height
            Behavior on anchors.bottomMargin { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            width: Math.min(toastLabel.implicitWidth + 40, parent.width - 80)
            height: toastLabel.implicitHeight + 22
            radius: Math.min(8, theme.radius)
            color: Style.raised
            border.color: error ? Style.danger : theme.accent
            Label {
                id: toastLabel
                anchors.centerIn: parent
                width: parent.width - 40
                text: toast.text
                color: toast.error ? Style.danger : Style.text
                font.pixelSize: 14
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
            }
            Timer { id: toastTimer; interval: toast.error ? 6000 : 2500; onTriggered: toast.shown = false }
        }

        HelpOverlay {
            anchors.fill: parent
            visible: win.helpVisible
            onVisibleChanged: if (!visible) win.helpVisible = false
        }
    }
}
