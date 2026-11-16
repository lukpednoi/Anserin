#include <QQmlExtensionPlugin>
#include <qqml.h>
#include <QPointer>
#include <QVideoFrame>
#include <QVideoSink>

class VideoFrameMirror : public QObject {
    Q_OBJECT
    Q_PROPERTY(QObject* source READ source WRITE setSource NOTIFY sourceChanged)
    Q_PROPERTY(QObject* output READ output WRITE setOutput NOTIFY outputChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    Q_PROPERTY(bool ready READ ready NOTIFY readyChanged)
public:
    using QObject::QObject;
    ~VideoFrameMirror() override { clear(); }
    QObject* source() const { return m_source; }
    QObject* output() const { return m_output; }
    bool enabled() const { return m_enabled; }
    bool ready() const { return m_ready; }
    void setSource(QObject* value) {
        if (m_source == value) return;
        m_source = qobject_cast<QVideoSink*>(value);
        reconnect();
        emit sourceChanged();
    }
    void setOutput(QObject* value) {
        if (m_output == value) return;
        clear();
        m_output = qobject_cast<QVideoSink*>(value);
        reconnect();
        emit outputChanged();
    }
    void setEnabled(bool value) {
        if (m_enabled == value) return;
        m_enabled = value;
        reconnect();
        emit enabledChanged();
    }
signals:
    void sourceChanged();
    void outputChanged();
    void enabledChanged();
    void readyChanged();
private:
    void setReady(bool value) {
        if (m_ready == value) return;
        m_ready = value;
        emit readyChanged();
    }
    void clear() {
        if (m_output) m_output->setVideoFrame(QVideoFrame());
        setReady(false);
    }
    void forward(const QVideoFrame& frame) {
        if (!m_enabled || !m_output) return;
        m_output->setVideoFrame(frame);
        setReady(frame.isValid());
    }
    void reconnect() {
        disconnect(m_frames);
        disconnect(m_destroyed);
        clear();
        if (!m_enabled || !m_source || !m_output || m_source == m_output) return;
        m_frames = connect(m_source, &QVideoSink::videoFrameChanged, this, &VideoFrameMirror::forward);
        m_destroyed = connect(m_source, &QObject::destroyed, this, [this] { clear(); emit sourceChanged(); });
        forward(m_source->videoFrame());
    }
    QPointer<QVideoSink> m_source;
    QPointer<QVideoSink> m_output;
    QMetaObject::Connection m_frames;
    QMetaObject::Connection m_destroyed;
    bool m_enabled = true;
    bool m_ready = false;
};

class AnserinVideoPlugin : public QQmlExtensionPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QQmlExtensionInterface_iid)
public:
    void registerTypes(const char* uri) override { qmlRegisterType<VideoFrameMirror>(uri, 1, 0, "VideoFrameMirror"); }
};

#include "plugin.moc"
