import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

PageScroll {
    heading: qsTr("Output")
    intro: qsTr("Where the sound goes and how the amplifier drives it.")

    function hz(v) { return (v * 10) + " Hz" }

    Panel {
        title: qsTr("Destination")
        SettingChoice {
            control: "Output Select"
            label: qsTr("Output")
            labels: [qsTr("Speakers"), qsTr("Headphones")]
        }
        SettingSwitch {
            control: "HP/Speaker Auto Detect Playback Switch"
            label: qsTr("Switch automatically")
            description: qsTr("Follow the front headphone jack: plugging in moves the sound to the headphones.")
        }
    }

    Panel {
        title: qsTr("Headphones")
        visible: backend.info["AE-5: Headphone Gain"] !== undefined
        SettingChoice {
            control: "AE-5: Headphone Gain"
            label: qsTr("Amplifier gain")
            description: qsTr("Match it to your headphones' impedance. High gain on sensitive headphones adds hiss.")
            labels: [qsTr("Low") + " · 16–31 Ω", qsTr("Medium") + " · 32–149 Ω", qsTr("High") + " · 150–600 Ω"]
        }
        SettingChoice {
            control: "AE-5: Sound Filter"
            label: qsTr("DAC filter")
            description: qsTr("The ESS Sabre DAC's reconstruction filter. The differences are subtle.")
            labels: [qsTr("Slow roll-off"), qsTr("Minimum phase"), qsTr("Fast roll-off")]
        }
    }

    Panel {
        title: qsTr("Speakers")
        SettingChoice {
            control: "Surround Channel Config"
            label: qsTr("Speaker layout")
        }
        SettingSwitch {
            control: "Full-Range Front Speakers"
            label: qsTr("Full-range front speakers")
            description: qsTr("Off sends the front speakers' bass to the subwoofer.")
        }
        SettingSwitch {
            control: "Full-Range Rear Speakers"
            label: qsTr("Full-range rear speakers")
        }
        SettingSwitch {
            id: redirect
            control: "Bass Redirection"
            label: qsTr("Bass redirection")
            description: qsTr("Send the low end to the subwoofer below the crossover.")
        }
        SettingSlider {
            control: "Bass Redirection Crossover"
            label: qsTr("Crossover")
            enabled: !!backend.values["Bass Redirection"]
            format: hz
        }
    }

    Panel {
        title: qsTr("Channel levels")
        SettingSlider { control: "Front Playback Volume"; muteControl: "Front Playback Switch"; label: qsTr("Front") }
        SettingSlider { control: "Surround Playback Volume"; muteControl: "Surround Playback Switch"; label: qsTr("Surround") }
        SettingSlider { control: "Center Playback Volume"; muteControl: "Center Playback Switch"; label: qsTr("Center") }
        SettingSlider { control: "LFE Playback Volume"; muteControl: "LFE Playback Switch"; label: qsTr("Subwoofer") }
        SettingSlider { control: "PCM Playback Volume"; label: qsTr("PCM") }
    }

    Panel {
        title: qsTr("Jacks")
        subtitle: qsTr("What the card detects right now.")
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [
                    { control: "Headphone Jack", label: qsTr("Headphones") },
                    { control: "Mic Jack", label: qsTr("Microphone") },
                    { control: "Line Out Front Jack", label: qsTr("Front line out") },
                    { control: "Line Out CLFE Jack", label: qsTr("Center/sub line out") }
                ]
                Rectangle {
                    readonly property bool plugged: !!backend.values[modelData.control]
                    visible: backend.info[modelData.control] !== undefined
                    radius: Math.min(4, theme.radius)
                    color: Style.raised
                    border.color: plugged ? theme.accent : Style.line
                    implicitHeight: 34
                    implicitWidth: jackRow.implicitWidth + 24
                    RowLayout {
                        id: jackRow
                        anchors.centerIn: parent
                        spacing: 8
                        Rectangle {
                            width: 8; height: 8; radius: 4
                            color: plugged ? theme.accent : Style.faint
                        }
                        Label {
                            text: modelData.label + " · " + (plugged ? qsTr("connected") : qsTr("empty"))
                            color: plugged ? Style.text : Style.dim
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }

    Item { implicitHeight: 12 }
}
