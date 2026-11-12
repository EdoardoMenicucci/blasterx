import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import "Style.js" as Style

PageScroll {
    id: page
    heading: qsTr("Equalizer")
    intro: qsTr("Ten bands, ±24 dB each. Picking a preset loads its curve into the card's DSP.")

    readonly property var bands: ["31", "62", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    readonly property bool engineOn: !!backend.values["Enable OutFX Playback Switch"]
    readonly property bool on: !!backend.values["FX: Equalizer Playback Switch"]

    function resetBands() {
        const changes = {}
        for (let i = 0; i < bands.length; ++i) {
            const name = "EQ Band" + i + " Playback Volume"
            const meta = backend.info[name]
            if (meta) changes[name] = Math.round((meta.min + meta.max) / 2)
        }
        backend.setMany(changes)
    }

    EngineNotice { visible: !page.engineOn }

    Panel {
        title: qsTr("Equalizer")
        headerExtra: Switch {
            checked: page.on
            onToggled: backend.set("FX: Equalizer Playback Switch", checked)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            enabled: page.on
            SettingChoice {
                control: "FX: Equalizer Preset Switch"
                label: qsTr("Preset")
                segmentLimit: 0
                labels: [qsTr("Flat"), qsTr("Acoustic"), qsTr("Classical"), "Country", "Dance", "Jazz",
                         "New Age", "Pop", "Rock", qsTr("Vocal")]
                Layout.fillWidth: true
            }
            Button {
                text: qsTr("Reset bands")
                flat: true
                Layout.alignment: Qt.AlignBottom
                onClicked: page.resetBands()
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: 300
            enabled: page.on
            opacity: page.on ? 1 : 0.5

            // The curve through the band values, drawn behind the sliders.
            Canvas {
                id: curve
                anchors.fill: bandRow
                anchors.topMargin: 24
                anchors.bottomMargin: 24
                property var points: page.bands.map((_, i) => backend.values["EQ Band" + i + " Playback Volume"] ?? 24)
                property color stroke: theme.accent
                onPointsChanged: requestPaint()
                onStrokeChanged: requestPaint()
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d")
                    ctx.reset()
                    const n = points.length, step = width / n
                    const y = v => height - (v / 48) * height
                    ctx.strokeStyle = "#27272e"
                    ctx.lineWidth = 1
                    ctx.beginPath(); ctx.moveTo(0, height / 2); ctx.lineTo(width, height / 2); ctx.stroke()
                    ctx.strokeStyle = stroke
                    ctx.globalAlpha = 0.5
                    ctx.lineWidth = 2
                    ctx.beginPath()
                    for (let i = 0; i < n; ++i) {
                        const px = step * (i + 0.5), py = y(points[i])
                        if (i === 0) ctx.moveTo(px, py)
                        else {
                            const qx = step * (i - 0.5), qy = y(points[i - 1])
                            ctx.bezierCurveTo((qx + px) / 2, qy, (qx + px) / 2, py, px, py)
                        }
                    }
                    ctx.stroke()
                }
            }

            RowLayout {
                id: bandRow
                anchors.fill: parent
                spacing: 0
                Repeater {
                    model: page.bands.length
                    EqBand {
                        control: "EQ Band" + index + " Playback Volume"
                        frequency: page.bands[index]
                        Layout.fillHeight: true
                        Layout.preferredWidth: 1
                    }
                }
            }
        }
        Label {
            text: qsTr("Frequencies in Hz.")
            color: Style.faint
            font.pixelSize: 12
        }
    }

    Item { implicitHeight: 12 }
}
