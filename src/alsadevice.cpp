#include "alsadevice.h"

#include <QSocketNotifier>
#include <alsa/asoundlib.h>
#include <poll.h>

namespace {

// Creative's PCI subsystem vendor (0x1102) shows up in the HDA components
// string; the mixer name carries the product.
bool isSoundBlaster(const QString &mixer, const QString &components) {
    return mixer.contains("Sound Blaster", Qt::CaseInsensitive) || mixer.contains("CA0132")
        || components.contains("HDA:1102");
}

QString keyFor(snd_ctl_elem_id_t *id) {
    const QString name = QString::fromUtf8(snd_ctl_elem_id_get_name(id));
    const unsigned index = snd_ctl_elem_id_get_index(id);
    return index ? QString("%1 #%2").arg(name).arg(index) : name;
}

} // namespace

AlsaDevice::AlsaDevice(const QString &card, QObject *parent) : ControlDevice(parent) {
    const QString chosen = !card.isEmpty() ? card : qEnvironmentVariable("BLASTERX_CARD");
    if (open(chosen))
        watch();
}

AlsaDevice::~AlsaDevice() {
    qDeleteAll(m_notifiers);
    if (m_ctl)
        snd_ctl_close(m_ctl);
}

bool AlsaDevice::open(const QString &card) {
    snd_ctl_card_info_t *info;
    snd_ctl_card_info_alloca(&info);

    auto tryOpen = [&](const QString &device, bool requireCreative) {
        snd_ctl_t *ctl = nullptr;
        if (snd_ctl_open(&ctl, device.toUtf8().constData(), SND_CTL_NONBLOCK) < 0)
            return false;
        if (snd_ctl_card_info(ctl, info) == 0) {
            const QString mixer = QString::fromUtf8(snd_ctl_card_info_get_mixername(info));
            const QString components = QString::fromUtf8(snd_ctl_card_info_get_components(info));
            if (!requireCreative || isSoundBlaster(mixer, components)) {
                m_ctl = ctl;
                m_name = mixer.isEmpty() ? QString::fromUtf8(snd_ctl_card_info_get_name(info)) : mixer;
                if (m_name.startsWith("Creative "))
                    m_name = m_name.mid(9);
                return true;
            }
        }
        snd_ctl_close(ctl);
        return false;
    };

    if (!card.isEmpty()) {
        if (tryOpen(card, false))
            return true;
        m_error = tr("Could not open the sound card %1.").arg(card);
        return false;
    }

    int index = -1;
    while (snd_card_next(&index) == 0 && index >= 0)
        if (tryOpen(QString("hw:%1").arg(index), true))
            return true;

    m_error = tr("No Sound Blaster card was found. Check that the snd_hda_intel driver has loaded the CA0132 codec.");
    return false;
}

void AlsaDevice::watch() {
    if (snd_ctl_subscribe_events(m_ctl, 1) < 0)
        return;
    const int count = snd_ctl_poll_descriptors_count(m_ctl);
    QVector<pollfd> fds(count);
    snd_ctl_poll_descriptors(m_ctl, fds.data(), count);
    for (const auto &fd : fds) {
        auto *notifier = new QSocketNotifier(fd.fd, QSocketNotifier::Read);
        connect(notifier, &QSocketNotifier::activated, this, &AlsaDevice::drainEvents);
        m_notifiers << notifier;
    }
}

void AlsaDevice::drainEvents() {
    snd_ctl_event_t *event;
    snd_ctl_event_alloca(&event);
    bool any = false;
    while (snd_ctl_read(m_ctl, event) > 0)
        any = true;
    if (any)
        emit changed();
}

QList<Control> AlsaDevice::controls() {
    QList<Control> result;
    if (!m_ctl)
        return result;

    snd_ctl_elem_list_t *list;
    snd_ctl_elem_id_t *id;
    snd_ctl_elem_info_t *info;
    snd_ctl_elem_value_t *value;
    snd_ctl_elem_list_alloca(&list);
    snd_ctl_elem_id_alloca(&id);
    snd_ctl_elem_info_alloca(&info);
    snd_ctl_elem_value_alloca(&value);

    if (snd_ctl_elem_list(m_ctl, list) < 0)
        return result;
    const unsigned total = snd_ctl_elem_list_get_count(list);
    if (snd_ctl_elem_list_alloc_space(list, total) < 0 || snd_ctl_elem_list(m_ctl, list) < 0)
        return result;

    m_numids.clear();
    for (unsigned i = 0; i < snd_ctl_elem_list_get_used(list); ++i) {
        snd_ctl_elem_list_get_id(list, i, id);
        const auto iface = snd_ctl_elem_id_get_interface(id);
        if (iface != SND_CTL_ELEM_IFACE_MIXER && iface != SND_CTL_ELEM_IFACE_CARD)
            continue;

        snd_ctl_elem_info_set_id(info, id);
        if (snd_ctl_elem_info(m_ctl, info) < 0 || !snd_ctl_elem_info_is_readable(info))
            continue;

        Control control;
        control.name = keyFor(id);
        control.writable = snd_ctl_elem_info_is_writable(info);
        control.count = int(snd_ctl_elem_info_get_count(info));

        switch (snd_ctl_elem_info_get_type(info)) {
        case SND_CTL_ELEM_TYPE_BOOLEAN:
            control.type = Control::Boolean;
            control.min = 0;
            control.max = 1;
            break;
        case SND_CTL_ELEM_TYPE_INTEGER:
            control.type = Control::Integer;
            control.min = int(snd_ctl_elem_info_get_min(info));
            control.max = int(snd_ctl_elem_info_get_max(info));
            break;
        case SND_CTL_ELEM_TYPE_ENUMERATED: {
            control.type = Control::Enumerated;
            const unsigned items = snd_ctl_elem_info_get_items(info);
            for (unsigned item = 0; item < items; ++item) {
                snd_ctl_elem_info_set_item(info, item);
                if (snd_ctl_elem_info(m_ctl, info) < 0)
                    break;
                // The driver pads some names ("16-31  Ohms"); collapse that.
                control.items << QString::fromUtf8(snd_ctl_elem_info_get_item_name(info)).simplified();
            }
            control.min = 0;
            control.max = int(control.items.size()) - 1;
            break;
        }
        default:
            continue;
        }

        snd_ctl_elem_value_set_id(value, id);
        if (snd_ctl_elem_read(m_ctl, value) < 0)
            continue;
        for (int channel = 0; channel < control.count; ++channel) {
            switch (control.type) {
            case Control::Boolean: control.values << snd_ctl_elem_value_get_boolean(value, channel); break;
            case Control::Integer: control.values << int(snd_ctl_elem_value_get_integer(value, channel)); break;
            case Control::Enumerated: control.values << int(snd_ctl_elem_value_get_enumerated(value, channel)); break;
            }
        }

        m_numids.insert(control.name, snd_ctl_elem_id_get_numid(id));
        result << control;
    }
    snd_ctl_elem_list_free_space(list);
    return result;
}

bool AlsaDevice::write(const QString &name, const QVector<int> &values) {
    if (!m_ctl || values.isEmpty()) {
        m_error = tr("The sound card is not open.");
        return false;
    }
    if (!m_numids.contains(name))
        controls();
    if (!m_numids.contains(name)) {
        m_error = tr("The card has no control named %1.").arg(name);
        return false;
    }

    snd_ctl_elem_id_t *id;
    snd_ctl_elem_info_t *info;
    snd_ctl_elem_value_t *value;
    snd_ctl_elem_id_alloca(&id);
    snd_ctl_elem_info_alloca(&info);
    snd_ctl_elem_value_alloca(&value);

    snd_ctl_elem_id_set_numid(id, m_numids.value(name));
    snd_ctl_elem_info_set_id(info, id);
    if (int err = snd_ctl_elem_info(m_ctl, info); err < 0) {
        m_error = QString::fromUtf8(snd_strerror(err));
        return false;
    }
    snd_ctl_elem_info_get_id(info, id);
    snd_ctl_elem_value_set_id(value, id);

    const auto type = snd_ctl_elem_info_get_type(info);
    const unsigned count = snd_ctl_elem_info_get_count(info);
    for (unsigned channel = 0; channel < count; ++channel) {
        // A single value sets every channel, which is how the window treats
        // stereo levels.
        const int v = values.value(int(channel), values.last());
        switch (type) {
        case SND_CTL_ELEM_TYPE_BOOLEAN: snd_ctl_elem_value_set_boolean(value, channel, v != 0); break;
        case SND_CTL_ELEM_TYPE_INTEGER: snd_ctl_elem_value_set_integer(value, channel, v); break;
        case SND_CTL_ELEM_TYPE_ENUMERATED: snd_ctl_elem_value_set_enumerated(value, channel, unsigned(v)); break;
        default:
            m_error = tr("%1 cannot be changed from here.").arg(name);
            return false;
        }
    }

    if (int err = snd_ctl_elem_write(m_ctl, value); err < 0) {
        m_error = QString::fromUtf8(snd_strerror(err));
        return false;
    }
    m_error.clear();
    return true;
}
