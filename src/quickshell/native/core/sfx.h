#pragma once
// Anserin core: in-shell sound effects (see sfx.cpp).

#include <QHash>
#include <QMultiHash>
#include <QObject>
#include <QSet>
#include <QString>

#include <map>
#include <memory>
#include <unordered_map>
#include <vector>

struct pw_thread_loop;
struct pw_context;
struct pw_core;
struct SfxMixer;
class QTimer;

struct SfxClip {
    long long frames = 0;
    std::vector<float> samples;   // 48 kHz stereo, interleaved
    long long bytes() const { return (long long)(samples.size() * sizeof(float)); }
};

class SfxEngine : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(int cachedSounds READ cachedSounds NOTIFY activeChanged)
public:
    explicit SfxEngine(QObject *parent = nullptr);
    ~SfxEngine() override;

    // Plays a sound file; returns its handle, or -1 when it cannot be played. volume 0..2,
    // maxSeconds > 0 cuts it short, loop repeats it until stop().
    Q_INVOKABLE int play(const QString &path, double volume = 1.0, double maxSeconds = 0, bool loop = false);
    Q_INVOKABLE void stop(int handle);
    Q_INVOKABLE void stopAll();
    // Decodes a sound in the background so its first play starts at once.
    Q_INVOKABLE void preload(const QString &path);
    // Returns freed heap pages to the OS after heavy QML panels are unloaded.
    Q_INVOKABLE void trimMemory();

    bool active() const;
    int cachedSounds() const;

    // called from the PipeWire thread (queued) when sounds reach their end
    void voicesEnded(const std::vector<int> &ids);

signals:
    void activeChanged();
    void finished(int handle);

private:
    struct CacheEntry { std::shared_ptr<SfxClip> clip; quint64 lastUse = 0; };
    struct Pending { int id; float volume; double seconds; bool loop; };

    static QString cleanPath(const QString &path);
    bool openPipeWire();
    void closePipeWire();
    std::shared_ptr<SfxClip> cachedClip(const QString &path);
    void storeClip(const QString &path, std::shared_ptr<SfxClip> clip);
    bool startVoice(int id, std::shared_ptr<SfxClip> clip, float volume, double maxSeconds, bool loop);

    pw_thread_loop *m_loop = nullptr;
    pw_context *m_context = nullptr;
    pw_core *m_core = nullptr;
    SfxMixer *m_mixer = nullptr;
    QTimer *m_pause = nullptr;
    QTimer *m_close = nullptr;
    QSet<int> m_playing;
    std::unordered_map<QString, CacheEntry> m_cache;
    qint64 m_cacheBytes = 0;
    quint64 m_useCounter = 0;
    QSet<QString> m_decoding;
    QMultiHash<QString, Pending> m_waiting;
    QSet<int> m_pendingIds;
    int m_nextId = 1;
    bool m_debug = false;
};
