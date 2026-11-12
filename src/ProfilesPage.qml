import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

PageScroll {
    id: page
    heading: qsTr("Profiles")
    intro: qsTr("Save every setting of the card under a name and switch between them in one step. The card keeps its current settings across reboots on its own.")

    property string pendingDelete: ""

    function focusName() { nameField.forceActiveFocus(); nameField.selectAll() }

    function save() {
        const name = nameField.text.trim()
        if (!backend.isValidProfileName(name)) return
        if (backend.profileExists(name)) {
            overwriteDialog.name = name
            overwriteDialog.open()
            return
        }
        if (backend.saveProfile(name)) nameField.text = ""
    }

    Panel {
        title: qsTr("Save current settings")
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            TextField {
                id: nameField
                placeholderText: qsTr("Profile name, e.g. Games or Music")
                Layout.fillWidth: true
                maximumLength: 64
                onAccepted: page.save()
            }
            Button {
                text: qsTr("Save")
                highlighted: true
                enabled: backend.isValidProfileName(nameField.text.trim())
                onClicked: page.save()
            }
        }
    }

    Panel {
        title: qsTr("Saved profiles")
        subtitle: backend.profiles.length === 0
                  ? qsTr("Nothing saved yet.")
                  : qsTr("Stored in %1").arg(backend.profileDirectory)

        Repeater {
            model: backend.profiles
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 52
                radius: Math.min(4, theme.radius)
                color: Style.raised
                RowLayout {
                    anchors { fill: parent; leftMargin: 16; rightMargin: 8 }
                    spacing: 8
                    Label {
                        text: modelData
                        color: Style.text
                        font.pixelSize: 15
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Button {
                        text: qsTr("Apply")
                        highlighted: true
                        onClicked: backend.applyProfile(modelData)
                    }
                    Button {
                        text: qsTr("Overwrite")
                        flat: true
                        onClicked: { overwriteDialog.name = modelData; overwriteDialog.open() }
                    }
                    Button {
                        text: qsTr("Delete")
                        flat: true
                        Material.foreground: Style.danger
                        onClicked: { page.pendingDelete = modelData; deleteDialog.open() }
                    }
                }
            }
        }
    }

    Panel {
        title: qsTr("From the terminal")
        subtitle: qsTr("The same profiles work without the window, for scripts and key bindings.")
        Label {
            text: "blasterx profile apply <name>\nblasterx set \"Output Select\" headphone\nblasterx list"
            color: Style.text
            font.family: "monospace"
            font.pixelSize: 13
            textFormat: Text.PlainText
        }
    }

    Dialog {
        id: overwriteDialog
        property string name: ""
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: qsTr("Replace %1?").arg(name)
        Label {
            text: qsTr("The saved settings are replaced with the card's current ones.")
            wrapMode: Text.WordWrap
            width: 360
        }
        standardButtons: Dialog.Cancel | Dialog.Save
        onAccepted: if (backend.saveProfile(name)) nameField.text = ""
    }

    Dialog {
        id: deleteDialog
        parent: Overlay.overlay
        anchors.centerIn: parent
        modal: true
        title: qsTr("Delete %1?").arg(page.pendingDelete)
        Label {
            text: qsTr("The profile file is removed. The card's current settings stay as they are.")
            wrapMode: Text.WordWrap
            width: 360
        }
        standardButtons: Dialog.Cancel | Dialog.Ok
        onAccepted: backend.deleteProfile(page.pendingDelete)
    }

    Item { implicitHeight: 12 }
}
