import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

PageScroll {
    id: page
    heading: qsTr("Microphone")
    intro: qsTr("Recording input and CrystalVoice, the card's voice processing.")

    readonly property bool voiceOn: !!backend.values["Enable InFX Capture Switch"]

    Panel {
        title: qsTr("Input")
        SettingChoice {
            control: "Input Source"
            label: qsTr("Source")
            labels: [qsTr("Microphone"), qsTr("Line in"), qsTr("Front microphone")]
        }
        SettingSlider { control: "Capture Volume"; muteControl: "Capture Switch"; label: qsTr("Recording level") }
        SettingChoice { control: "Mic Boost Capture Switch"; label: qsTr("Microphone boost") }
        SettingSlider {
            control: "What U Hear Capture Volume"
            muteControl: "What U Hear Capture Switch"
            label: qsTr("What U Hear")
        }
        Label {
            text: qsTr("What U Hear records whatever the card is playing, for streaming or capturing game audio.")
            color: Style.dim
            font.pixelSize: 12
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
            visible: backend.info["What U Hear Capture Volume"] !== undefined
        }
    }

    Panel {
        title: qsTr("CrystalVoice")
        subtitle: qsTr("The master switch for the voice effects below.")
        headerExtra: Switch {
            checked: page.voiceOn
            onToggled: backend.set("Enable InFX Capture Switch", checked)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 14
            opacity: page.voiceOn ? 1 : 0.55

            SettingSwitch {
                control: "FX: Voice Focus Capture Switch"
                label: qsTr("Voice Focus")
                description: qsTr("Picks up sound only from in front of the microphone.")
            }
            SettingSlider {
                control: "Wedge Angle Capture Volume"
                label: qsTr("Focus angle")
                enabled: !!backend.values["FX: Voice Focus Capture Switch"]
                format: function (v) { return Math.max(minimum, v) + "°" }
            }
            SettingSwitch {
                control: "FX: Noise Reduction Capture Switch"
                label: qsTr("Noise reduction")
                description: qsTr("Removes steady background noise like fans and hum.")
            }
            SettingSwitch {
                control: "FX: Mic SVM Capture Switch"
                label: qsTr("Smart Volume")
                description: qsTr("Keeps your voice at an even level.")
            }
            SettingSlider {
                control: "SVM Level Capture Volume"
                label: qsTr("Smart Volume level")
                enabled: !!backend.values["FX: Mic SVM Capture Switch"]
            }
            SettingChoice {
                control: "VoiceFX Capture Switch"
                label: qsTr("Voice morphing")
                labels: [qsTr("Off"), qsTr("Female to male"), qsTr("Male to female"), qsTr("Scrappy kid"),
                         qsTr("Elderly"), qsTr("Orc"), qsTr("Elf"), qsTr("Dwarf"), qsTr("Alien brute"),
                         qsTr("Robot"), qsTr("Marine"), qsTr("Emo"), qsTr("Deep voice"), qsTr("Munchkin")]
            }
        }
    }

    Item { implicitHeight: 12 }
}
