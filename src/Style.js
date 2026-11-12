.pragma library

// The window's neutral palette; the accent comes from the Omarchy theme.
var window = "#0e0e10"
var panel = "#151519"
var raised = "#1e1e24"
var line = "#27272e"
var text = "#ececf1"
var dim = "#8d8d98"
var faint = "#55555f"
var danger = "#ff6b6b"

function percent(value, min, max) {
    return Math.round(100 * (value - min) / Math.max(1, max - min)) + "%"
}

function signedDb(value) {
    return (value > 0 ? "+" : value < 0 ? "−" : "") + Math.abs(value) + " dB"
}
