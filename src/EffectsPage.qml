import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

PageScroll {
    id: page
    heading: qsTr("Acoustic Engine")
    intro: qsTr("Sound Blaster's playback effects, processed on the card. Space turns the whole engine on or off.")

    readonly property bool engineOn: !!backend.values["Enable OutFX Playback Switch"]

    Panel {
        title: qsTr("Acoustic Engine")
        subtitle: qsTr("The master switch for every effect below and for the equalizer.")
        headerExtra: Switch {
            checked: page.engineOn
            onToggled: backend.set("Enable OutFX Playback Switch", checked)
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: page.width > 900 ? 2 : 1
        columnSpacing: 16
        rowSpacing: 16

        FxCard {
            title: qsTr("Surround")
            subtitle: qsTr("Virtual surround that widens stereo, on speakers and headphones.")
            switchControl: "FX: Surround Playback Switch"
            levelControl: "FX: Surround Playback Volume"
            engineOn: page.engineOn
        }
        FxCard {
            title: qsTr("Crystalizer")
            subtitle: qsTr("Restores the dynamics and detail that compressed audio loses.")
            switchControl: "FX: Crystalizer Playback Switch"
            levelControl: "FX: Crystalizer Playback Volume"
            engineOn: page.engineOn
        }
        FxCard {
            title: qsTr("Bass")
            subtitle: qsTr("Fills in the low frequencies that small speakers and headphones miss.")
            switchControl: "FX: X-Bass Playback Switch"
            levelControl: "FX: X-Bass Playback Volume"
            engineOn: page.engineOn
            SettingSlider {
                control: "FX: X-Bass Crossover Playback Volume"
                label: qsTr("Crossover")
                format: function (v) { return (v * 10) + " Hz" }
            }
        }
        FxCard {
            title: qsTr("Smart Volume")
            subtitle: qsTr("Evens out sudden jumps in loudness between and within tracks.")
            switchControl: "FX: Smart Volume Playback Switch"
            levelControl: "FX: Smart Volume Playback Volume"
            engineOn: page.engineOn
            SettingChoice {
                control: "FX: Smart Volume Setting"
                label: qsTr("Mode")
                labels: [qsTr("Normal"), qsTr("Loud"), qsTr("Night")]
            }
        }
        FxCard {
            title: qsTr("Dialog Plus")
            subtitle: qsTr("Brings voices forward in films, series and games.")
            switchControl: "FX: Dialog Plus Playback Switch"
            levelControl: "FX: Dialog Plus Playback Volume"
            engineOn: page.engineOn
        }
    }

    Item { implicitHeight: 12 }
}
