#pragma once

#include <QStringList>

// Commands that need no display, so scripts and agents can drive the card:
// list, get, set, and profile list/save/apply/delete. Returns the exit code.
int runCli(const QStringList &arguments);

// True when the arguments ask for a command rather than the window.
bool isCliCommand(const QStringList &arguments);
