#include "backend.h"

#include <QDir>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSaveFile>
#include <QStandardPaths>
#include <algorithm>

namespace {

// Dragging a slider sends a stream of writes; within this window they fold
// into one undo step.
constexpr qint64 kCoalesceMs = 800;

QVariant firstValue(const Control &c) {
    const int v = c.values.value(0);
    return c.type == Control::Boolean ? QVariant(v != 0) : QVariant(v);
}

QString typeName(Control::Type type) {
    switch (type) {
    case Control::Boolean: return "boolean";
    case Control::Enumerated: return "enum";
    default: return "integer";
    }
}

} // namespace

Backend::Backend(ControlDevice *device, const QString &profileDirectory, QObject *parent)
    : QObject(parent), m_device(device),
      m_profileDirectory(!profileDirectory.isEmpty()
                             ? profileDirectory
                             : QStandardPaths::writableLocation(QStandardPaths::GenericConfigLocation)
                                   + "/blasterx/profiles") {
    m_clock.start();
    // The card reports our own writes too, so events are folded together and
    // answered with a single read of the whole state.
    m_refresh.setSingleShot(true);
    m_refresh.setInterval(30);
    connect(&m_refresh, &QTimer::timeout, this, &Backend::refresh);
    if (m_device)
        connect(m_device, &ControlDevice::changed, &m_refresh, qOverload<>(&QTimer::start));
    refresh();
    loadProfiles();
}

QList<Control> Backend::controls() const {
    QList<Control> list;
    for (const auto &name : m_order)
        list << m_controls.value(name);
    return list;
}

void Backend::refresh() {
    if (!available())
        return;

    QHash<QString, Control> controls;
    QStringList order;
    QVariantMap values, info;
    for (const auto &c : m_device->controls()) {
        controls.insert(c.name, c);
        order << c.name;
        values.insert(c.name, firstValue(c));
        info.insert(c.name, QVariantMap{
            {"type", typeName(c.type)},
            {"min", c.min},
            {"max", c.max},
            {"count", c.count},
            {"items", c.items},
            {"writable", c.writable},
        });
    }

    m_controls = controls;
    const bool layout = order != m_order || info != m_info;
    m_order = order;
    m_info = info;
    if (layout)
        emit infoChanged();
    if (values != m_values) {
        m_values = values;
        emit valuesChanged();
    }
}

bool Backend::set(const QString &name, const QVariant &value) {
    const auto it = m_controls.constFind(name);
    if (it == m_controls.constEnd()) {
        fail(tr("The card has no control named %1.").arg(name));
        return false;
    }
    const Control &c = *it;
    if (!c.writable) {
        fail(tr("%1 is read-only.").arg(name));
        return false;
    }

    int v = c.type == Control::Boolean ? (value.toBool() ? 1 : 0) : qRound(value.toDouble());
    v = std::clamp(v, c.min, std::max(c.min, c.max));
    const QVector<int> after(c.count, v);
    if (after == c.values)
        return true;

    const QVector<int> before = c.values;
    if (!writeValues(name, after))
        return false;
    record({{name, before, after}});
    return true;
}

bool Backend::toggle(const QString &name) {
    return set(name, !m_values.value(name).toBool());
}

bool Backend::setMany(const QVariantMap &changes) {
    refresh();
    QList<Edit> edits;
    bool ok = true;
    for (auto it = changes.begin(); it != changes.end(); ++it) {
        const auto found = m_controls.constFind(it.key());
        if (found == m_controls.constEnd() || !found->writable) {
            ok = false;
            continue;
        }
        const Control c = *found;
        int v = c.type == Control::Boolean ? (it.value().toBool() ? 1 : 0) : qRound(it.value().toDouble());
        const QVector<int> after(c.count, std::clamp(v, c.min, std::max(c.min, c.max)));
        if (after == c.values)
            continue;
        if (writeValues(c.name, after))
            edits << Edit{c.name, c.values, after};
        else
            ok = false;
    }
    if (!edits.isEmpty()) {
        record(edits);
        m_undo.last().at = -kCoalesceMs;
    }
    return ok;
}

bool Backend::writeValues(const QString &name, const QVector<int> &values) {
    if (!available()) {
        fail(tr("The sound card is not available."));
        return false;
    }
    if (!m_device->write(name, values)) {
        fail(tr("Could not change %1: %2").arg(name, m_device->error()));
        refresh();
        return false;
    }
    auto &c = m_controls[name];
    c.values = values;
    const QVariant shown = firstValue(c);
    if (m_values.value(name) != shown) {
        m_values.insert(name, shown);
        emit valuesChanged();
    }
    m_refresh.start();
    return true;
}

void Backend::record(const QList<Edit> &edits) {
    const qint64 now = m_clock.elapsed();
    if (edits.size() == 1 && !m_undo.isEmpty()) {
        Step &top = m_undo.last();
        if (top.edits.size() == 1 && top.edits.first().name == edits.first().name && now - top.at < kCoalesceMs) {
            top.edits.first().after = edits.first().after;
            top.at = now;
            m_redo.clear();
            emit historyChanged();
            return;
        }
    }
    m_undo.append({edits, now});
    m_redo.clear();
    emit historyChanged();
}

void Backend::replay(QList<Step> &from, QList<Step> &to, bool forward) {
    if (from.isEmpty())
        return;
    Step step = from.takeLast();
    if (forward) {
        for (const auto &e : step.edits)
            writeValues(e.name, e.after);
    } else {
        for (auto e = step.edits.crbegin(); e != step.edits.crend(); ++e)
            writeValues(e->name, e->before);
    }
    // A later step must not fold into one that was undone and redone.
    step.at = -kCoalesceMs;
    to.append(step);
    emit historyChanged();
}

void Backend::undo() { replay(m_undo, m_redo, false); }
void Backend::redo() { replay(m_redo, m_undo, true); }

bool Backend::parseValue(const QString &name, const QString &text, int *out) const {
    const auto it = m_controls.constFind(name);
    if (it == m_controls.constEnd())
        return false;
    const QString t = text.trimmed();
    bool ok = false;
    int number = t.toInt(&ok);

    switch (it->type) {
    case Control::Boolean: {
        static const QStringList on{"on", "true", "yes", "1"}, off{"off", "false", "no", "0"};
        if (on.contains(t.toLower())) { *out = 1; return true; }
        if (off.contains(t.toLower())) { *out = 0; return true; }
        return false;
    }
    case Control::Enumerated:
        for (int i = 0; i < it->items.size(); ++i)
            if (it->items[i].compare(t, Qt::CaseInsensitive) == 0) { *out = i; return true; }
        // A unique prefix is enough ("head" for "Headphone").
        {
            int match = -1;
            for (int i = 0; i < it->items.size(); ++i)
                if (it->items[i].startsWith(t, Qt::CaseInsensitive))
                    match = match == -1 ? i : -2;
            if (match >= 0 && !t.isEmpty()) { *out = match; return true; }
        }
        if (ok && number >= 0 && number < it->items.size()) { *out = number; return true; }
        return false;
    case Control::Integer:
        if (ok && number >= it->min && number <= it->max) { *out = number; return true; }
        return false;
    }
    return false;
}

QJsonObject Backend::snapshot() const {
    QJsonObject controls;
    for (const auto &name : m_order) {
        const Control &c = m_controls[name];
        if (!c.writable)
            continue;
        QJsonArray values;
        for (int v : c.values)
            values << v;
        controls.insert(name, values);
    }
    return QJsonObject{{"version", 1}, {"device", deviceName()}, {"controls", controls}};
}

// Profiles are plain files, so the name has to be a safe file name.
bool Backend::isValidProfileName(const QString &name) const {
    const QString n = name.trimmed();
    return !n.isEmpty() && n.size() <= 64 && !n.startsWith('.') && !n.contains('/') && !n.contains('\\')
        && n == name;
}

QString Backend::profilePath(const QString &name) const {
    return m_profileDirectory + "/" + name + ".json";
}

bool Backend::profileExists(const QString &name) const {
    return isValidProfileName(name) && QFile::exists(profilePath(name));
}

void Backend::loadProfiles() {
    QStringList names;
    for (const auto &file : QDir(m_profileDirectory).entryList({"*.json"}, QDir::Files, QDir::Name | QDir::IgnoreCase))
        names << file.chopped(5);
    if (names != m_profiles) {
        m_profiles = names;
        emit profilesChanged();
    }
}

bool Backend::saveProfile(const QString &name) {
    if (!isValidProfileName(name)) {
        fail(tr("“%1” cannot be used as a profile name.").arg(name));
        return false;
    }
    if (!available()) {
        fail(tr("The sound card is not available."));
        return false;
    }
    if (!QDir().mkpath(m_profileDirectory)) {
        fail(tr("Could not create %1.").arg(m_profileDirectory));
        return false;
    }
    // QSaveFile writes beside the target and renames, so a crash never leaves
    // half a profile behind.
    QSaveFile file(profilePath(name));
    if (!file.open(QIODevice::WriteOnly)
        || file.write(QJsonDocument(snapshot()).toJson()) < 0 || !file.commit()) {
        fail(tr("Could not save the profile: %1").arg(file.errorString()));
        return false;
    }
    loadProfiles();
    emit message(tr("Saved profile %1.").arg(name), false);
    return true;
}

bool Backend::applyProfile(const QString &name) {
    if (!profileExists(name)) {
        fail(tr("There is no profile named %1.").arg(name));
        return false;
    }
    QFile file(profilePath(name));
    if (!file.open(QIODevice::ReadOnly)) {
        fail(tr("Could not read the profile: %1").arg(file.errorString()));
        return false;
    }
    QJsonParseError parseError;
    const auto document = QJsonDocument::fromJson(file.readAll(), &parseError);
    if (parseError.error != QJsonParseError::NoError || !document.object().value("controls").isObject()) {
        fail(tr("The profile %1 is not valid.").arg(name));
        return false;
    }
    const QJsonObject stored = document.object().value("controls").toObject();

    // Choices first, then switches, then levels: picking an EQ preset or an
    // output resets related levels in the driver, and the profile's own
    // levels must win. The card is read again before each group, so values
    // the driver just moved are compared as they are now.
    QList<Edit> edits;
    int failures = 0;
    for (auto type : {Control::Enumerated, Control::Boolean, Control::Integer}) {
        refresh();
        for (const auto &n : QStringList(m_order)) {
            const Control c = m_controls.value(n);
            if (c.type != type || !c.writable || !stored.contains(n))
                continue;
            QVector<int> after;
            for (const auto &v : stored.value(n).toArray())
                after << std::clamp(v.toInt(), c.min, std::max(c.min, c.max));
            if (after.isEmpty())
                continue;
            after.resize(c.count, after.last());
            if (after == c.values)
                continue;
            if (writeValues(n, after))
                edits << Edit{n, c.values, after};
            else
                ++failures;
        }
    }
    if (!edits.isEmpty()) {
        record(edits);
        m_undo.last().at = -kCoalesceMs;
    }
    refresh();
    if (failures) {
        fail(tr("Applied %1, but %n controls could not be set.", "", failures).arg(name));
        return false;
    }
    emit message(tr("Applied profile %1.").arg(name), false);
    return true;
}

bool Backend::deleteProfile(const QString &name) {
    if (!profileExists(name) || !QFile::remove(profilePath(name))) {
        fail(tr("Could not delete the profile %1.").arg(name));
        return false;
    }
    loadProfiles();
    emit message(tr("Deleted profile %1.").arg(name), false);
    return true;
}

void Backend::fail(const QString &text) {
    emit message(text, true);
}
