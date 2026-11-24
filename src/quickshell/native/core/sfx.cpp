// Anserin core: sound effects played inside the shell.
//
// Every sound is decoded once with libsndfile, converted to 48 kHz stereo and kept in memory. One PipeWire
// stream (application.id "anserin-sfx", media.role "Event", as pw-play was given) stays connected and this
// code mixes the playing sounds into it, so a click starts on the next audio cycle instead of waiting for a
// new process or a new stream. When nothing plays the stream is paused (PipeWire can suspend the device),
// and after a few quiet minutes it is closed altogether.

#include "sfx.h"

#include <QCoreApplication>
#include <QFileInfo>
#include <QPointer>
#include <QThreadPool>
#include <QTimer>

#include <pipewire/pipewire.h>
#include <spa/param/audio/format-utils.h>
#include <sndfile.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <vector>
#if defined(__GLIBC__)
#include <malloc.h>
#endif

namespace {

constexpr int kRate = 48000;                              // the mix runs at 48 kHz stereo
constexpr qint64 kCacheLimitBytes = 64LL * 1024 * 1024;   // decoded audio kept in memory
constexpr double kInlineSeconds = 1.0;                    // shorter sounds decode at once, longer ones in the background
constexpr int kPauseMs = 1500;                            // pause the stream after this long without sound
constexpr int kCloseMs = 5 * 60 * 1000;                   // and close PipeWire after this long

// Windowed-sinc resampler for the one-off conversion to 48 kHz. The kernel is tabulated for 512 sub-sample
// phases, so each output sample is 32 multiply-adds per channel with no trigonometry (a 20 s sound converts in
// tens of milliseconds, on a background thread).
std::vector<float> resample(const std::vector<float> &in, int channels, int fromRate, long long &frames)
{
    if (fromRate == kRate) return in;
    constexpr int half = 16;                               // taps each side
    constexpr int phases = 512;
    const double ratio = double(kRate) / double(fromRate);
    const double cutoff = std::min(1.0, ratio);            // low-pass below the lower Nyquist
    std::vector<float> table(size_t(phases) * 2 * half);
    for (int p = 0; p < phases; ++p) {
        const double frac = double(p) / phases;            // position of the output between input samples
        double sum = 0;
        for (int t = 0; t < 2 * half; ++t) {
            const double d = double(t - half + 1) - frac;  // tap distance from the output position
            const double x = d * cutoff;
            const double sinc = std::abs(x) < 1e-9 ? 1.0 : std::sin(M_PI * x) / (M_PI * x);
            const double w = 0.5 * (1.0 + std::cos(M_PI * d / double(half)));   // Hann
            table[size_t(p) * 2 * half + size_t(t)] = float(sinc * w);
            sum += sinc * w;
        }
        for (int t = 0; t < 2 * half; ++t) table[size_t(p) * 2 * half + size_t(t)] /= float(sum);
    }
    const long long outFrames = (long long)std::floor(double(frames) * ratio);
    std::vector<float> out(size_t(outFrames) * size_t(channels));
    for (long long o = 0; o < outFrames; ++o) {
        const double center = double(o) / ratio;
        const long long base = (long long)std::floor(center);
        const int phase = std::min(phases - 1, int((center - double(base)) * phases));
        const float *k = table.data() + size_t(phase) * 2 * half;
        const long long first = base - half + 1;
        for (int c = 0; c < channels; ++c) {
            float acc = 0;
            for (int t = 0; t < 2 * half; ++t) {
                const long long i = first + t;
                if (i < 0 || i >= frames) continue;
                acc += k[t] * in[size_t(i) * size_t(channels) + size_t(c)];
            }
            out[size_t(o) * size_t(channels) + size_t(c)] = acc;
        }
    }
    frames = outFrames;
    return out;
}

// the length of a sound file in seconds, from its header only (-1 when it cannot be read)
double soundSeconds(const QString &path)
{
    SF_INFO info{};
    SNDFILE *file = sf_open(QFile::encodeName(path).constData(), SFM_READ, &info);
    if (!file) return -1;
    sf_close(file);
    return info.samplerate > 0 ? double(info.frames) / info.samplerate : -1;
}

std::shared_ptr<SfxClip> decodeFile(const QString &path)
{
    SF_INFO info{};
    SNDFILE *file = sf_open(QFile::encodeName(path).constData(), SFM_READ, &info);
    if (!file) return nullptr;
    if (info.channels < 1 || info.channels > 8 || info.samplerate < 8000 || info.frames <= 0) {
        sf_close(file);
        return nullptr;
    }
    std::vector<float> raw(size_t(info.frames) * size_t(info.channels));
    long long frames = sf_readf_float(file, raw.data(), info.frames);
    sf_close(file);
    if (frames <= 0) return nullptr;
    raw.resize(size_t(frames) * size_t(info.channels));

    // to stereo: mono is copied to both sides, more channels keep their first two
    std::vector<float> stereo(size_t(frames) * 2);
    for (long long f = 0; f < frames; ++f) {
        const float *s = raw.data() + size_t(f) * size_t(info.channels);
        stereo[size_t(f) * 2] = s[0];
        stereo[size_t(f) * 2 + 1] = info.channels > 1 ? s[1] : s[0];
    }
    auto clip = std::make_shared<SfxClip>();
    clip->samples = resample(stereo, 2, info.samplerate, frames);
    clip->frames = frames;
    return clip;
}

} // namespace

// A playing sound. Lives in the mixer; touched only on the PipeWire thread or under its lock.
struct SfxVoice {
    int id = 0;
    std::shared_ptr<SfxClip> clip;
    float volume = 1.0f;
    bool loop = false;
    long long endFrame = 0;
    long long pos = 0;
    bool done = false;
};

struct SfxMixer {
    SfxEngine *engine = nullptr;
    pw_stream *stream = nullptr;
    spa_hook listener{};
    std::vector<SfxVoice> voices;
    std::chrono::steady_clock::time_point askedAt;   // debug: when the last play() came
    bool measure = false;
};

static void onProcess(void *data)
{
    auto *m = static_cast<SfxMixer *>(data);
    pw_buffer *b = pw_stream_dequeue_buffer(m->stream);
    if (!b) return;
    spa_buffer *buf = b->buffer;
    auto *dst = static_cast<float *>(buf->datas[0].data);
    if (!dst) return;
    const uint32_t stride = sizeof(float) * 2;
    uint32_t frames = buf->datas[0].maxsize / stride;
    if (b->requested) frames = std::min<uint32_t>(frames, uint32_t(b->requested));
    std::fill(dst, dst + size_t(frames) * 2, 0.0f);

    std::vector<int> ended;
    for (SfxVoice &v : m->voices) {
        uint32_t w = 0;
        while (w < frames) {
            if (v.pos >= v.endFrame) {
                if (v.loop && v.endFrame > 0) { v.pos = 0; continue; }
                v.done = true;
                ended.push_back(v.id);
                break;
            }
            const uint32_t n = uint32_t(std::min<long long>(frames - w, v.endFrame - v.pos));
            const float *src = v.clip->samples.data() + size_t(v.pos) * 2;
            float *out = dst + size_t(w) * 2;
            for (uint32_t i = 0; i < n * 2; ++i) out[i] += src[i] * v.volume;
            v.pos += n;
            w += n;
        }
    }
    for (uint32_t i = 0; i < frames * 2; ++i) dst[i] = std::clamp(dst[i], -1.0f, 1.0f);

    buf->datas[0].chunk->offset = 0;
    buf->datas[0].chunk->stride = int32_t(stride);
    buf->datas[0].chunk->size = frames * stride;
    pw_stream_queue_buffer(m->stream, b);

    if (m->measure) {
        m->measure = false;
        const double ms = std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now() - m->askedAt).count();
        qInfo("anserin-sfx: sound started %.1f ms after play()", ms);
    }
    if (!ended.empty()) {
        m->voices.erase(std::remove_if(m->voices.begin(), m->voices.end(), [](const SfxVoice &v) { return v.done; }),
                        m->voices.end());
        SfxEngine *engine = m->engine;
        QMetaObject::invokeMethod(engine, [engine, ended] { engine->voicesEnded(ended); }, Qt::QueuedConnection);
    }
}

static const pw_stream_events kStreamEvents = [] {
    pw_stream_events e{};
    e.version = PW_VERSION_STREAM_EVENTS;
    e.process = onProcess;
    return e;
}();

SfxEngine::SfxEngine(QObject *parent)
    : QObject(parent)
{
    pw_init(nullptr, nullptr);
    m_debug = qEnvironmentVariableIsSet("ANSERIN_SFX_DEBUG");
    m_pause = new QTimer(this);
    m_pause->setSingleShot(true);
    m_pause->setInterval(kPauseMs);
    connect(m_pause, &QTimer::timeout, this, [this] {
        if (m_mixer && m_playing.isEmpty()) {
            pw_thread_loop_lock(m_loop);
            pw_stream_set_active(m_mixer->stream, false);
            pw_thread_loop_unlock(m_loop);
            m_close->start();
        }
    });
    m_close = new QTimer(this);
    m_close->setSingleShot(true);
    m_close->setInterval(kCloseMs);
    connect(m_close, &QTimer::timeout, this, [this] {
        if (m_playing.isEmpty()) {
            closePipeWire();
            if (!m_cache.empty()) {
                m_cache.clear();
                m_cacheBytes = 0;
                emit activeChanged();
            }
            trimMemory();
        }
    });
}

void SfxEngine::trimMemory()
{
#if defined(__GLIBC__)
    malloc_trim(0);
#endif
}

SfxEngine::~SfxEngine()
{
    m_playing.clear();
    closePipeWire();
}

bool SfxEngine::openPipeWire()
{
    if (m_mixer) return true;
    m_loop = pw_thread_loop_new("anserin-sfx", nullptr);
    if (!m_loop) return false;
    m_context = pw_context_new(pw_thread_loop_get_loop(m_loop), nullptr, 0);
    if (!m_context || pw_thread_loop_start(m_loop) < 0) { closePipeWire(); return false; }

    pw_thread_loop_lock(m_loop);
    m_core = pw_context_connect(m_context, nullptr, 0);
    if (!m_core) { pw_thread_loop_unlock(m_loop); closePipeWire(); return false; }

    pw_properties *props = pw_properties_new(
        PW_KEY_MEDIA_TYPE, "Audio",
        PW_KEY_MEDIA_CATEGORY, "Playback",
        PW_KEY_MEDIA_ROLE, "Event",
        PW_KEY_APP_ID, "anserin-sfx",
        PW_KEY_APP_NAME, "anserin-sfx",
        PW_KEY_NODE_NAME, "anserin-sfx",
        PW_KEY_NODE_LATENCY, "256/48000",
        nullptr);
    auto *m = new SfxMixer;
    m->engine = this;
    m->stream = pw_stream_new(m_core, "anserin-sfx", props);
    if (!m->stream) { delete m; pw_thread_loop_unlock(m_loop); closePipeWire(); return false; }
    pw_stream_add_listener(m->stream, &m->listener, &kStreamEvents, m);

    uint8_t buffer[1024];
    spa_pod_builder builder = SPA_POD_BUILDER_INIT(buffer, sizeof(buffer));
    spa_audio_info_raw info{};
    info.format = SPA_AUDIO_FORMAT_F32;
    info.rate = kRate;
    info.channels = 2;
    info.position[0] = SPA_AUDIO_CHANNEL_FL;
    info.position[1] = SPA_AUDIO_CHANNEL_FR;
    const spa_pod *params[1] = { spa_format_audio_raw_build(&builder, SPA_PARAM_EnumFormat, &info) };
    // not RT_PROCESS: process() then runs on the loop thread, so the thread-loop lock guards the voices
    const int res = pw_stream_connect(m->stream, PW_DIRECTION_OUTPUT, PW_ID_ANY,
        pw_stream_flags(PW_STREAM_FLAG_AUTOCONNECT | PW_STREAM_FLAG_MAP_BUFFERS), params, 1);
    if (res < 0) {
        spa_hook_remove(&m->listener);
        pw_stream_destroy(m->stream);
        delete m;
        pw_thread_loop_unlock(m_loop);
        closePipeWire();
        return false;
    }
    m_mixer = m;
    pw_thread_loop_unlock(m_loop);
    return true;
}

void SfxEngine::closePipeWire()
{
    if (m_loop) pw_thread_loop_stop(m_loop);
    if (m_mixer) {
        spa_hook_remove(&m_mixer->listener);
        pw_stream_destroy(m_mixer->stream);
        delete m_mixer;
        m_mixer = nullptr;
    }
    if (m_core) { pw_core_disconnect(m_core); m_core = nullptr; }
    if (m_context) { pw_context_destroy(m_context); m_context = nullptr; }
    if (m_loop) { pw_thread_loop_destroy(m_loop); m_loop = nullptr; }
}

std::shared_ptr<SfxClip> SfxEngine::cachedClip(const QString &path)
{
    auto it = m_cache.find(path);
    if (it == m_cache.end()) return nullptr;
    it->second.lastUse = ++m_useCounter;
    return it->second.clip;
}

void SfxEngine::storeClip(const QString &path, std::shared_ptr<SfxClip> clip)
{
    if (!clip) return;
    m_cacheBytes += clip->bytes();
    m_cache[path] = CacheEntry{clip, ++m_useCounter};
    // drop the least recently used sounds that nothing is playing until the cache fits again
    while (m_cacheBytes > kCacheLimitBytes && m_cache.size() > 1) {
        auto victim = m_cache.end();
        for (auto it = m_cache.begin(); it != m_cache.end(); ++it) {
            if (it->second.clip.use_count() > 1 || it->first == path) continue;
            if (victim == m_cache.end() || it->second.lastUse < victim->second.lastUse) victim = it;
        }
        if (victim == m_cache.end()) break;
        m_cacheBytes -= victim->second.clip->bytes();
        m_cache.erase(victim);
    }
}

QString SfxEngine::cleanPath(const QString &path)
{
    return path.startsWith(QLatin1String("file://")) ? path.mid(7) : path;
}

void SfxEngine::preload(const QString &rawPath)
{
    const QString path = cleanPath(rawPath);
    if (path.isEmpty() || m_cache.count(path) || m_decoding.contains(path)) return;
    m_decoding.insert(path);
    QPointer<SfxEngine> self(this);
    QThreadPool::globalInstance()->start([self, path] {
        auto clip = decodeFile(path);
        QMetaObject::invokeMethod(QCoreApplication::instance(), [self, path, clip] {
            if (!self) return;
            self->m_decoding.remove(path);
            if (clip) self->storeClip(path, clip);
            // sounds asked for while this file was decoding start now
            const auto waiting = self->m_waiting.values(path);
            self->m_waiting.remove(path);
            for (const Pending &p : waiting) {
                if (!self->m_pendingIds.remove(p.id)) continue;   // stopped meanwhile
                if (!clip || !self->startVoice(p.id, clip, p.volume, p.seconds, p.loop)) emit self->finished(p.id);
            }
        }, Qt::QueuedConnection);
    });
}

int SfxEngine::play(const QString &rawPath, double volume, double maxSeconds, bool loop)
{
    const QString path = cleanPath(rawPath);
    if (path.isEmpty()) return -1;
    const float vol = float(std::clamp(volume, 0.0, 2.0));

    std::shared_ptr<SfxClip> clip = cachedClip(path);
    if (!clip && !m_decoding.contains(path)) {
        const QFileInfo fi(path);
        if (!fi.isFile()) return -1;
        if (soundSeconds(path) <= kInlineSeconds) {
            clip = decodeFile(path);
            if (!clip) return -1;
            storeClip(path, clip);
        }
    }
    const int id = m_nextId++;
    if (clip) return startVoice(id, clip, vol, maxSeconds, loop) ? id : -1;
    // a large file: decode it in the background and start it when ready
    m_pendingIds.insert(id);
    m_waiting.insert(path, Pending{id, vol, maxSeconds, loop});
    preload(path);
    return id;
}

bool SfxEngine::startVoice(int id, std::shared_ptr<SfxClip> clip, float volume, double maxSeconds, bool loop)
{
    if (!openPipeWire()) return false;
    SfxVoice v;
    v.id = id;
    v.clip = std::move(clip);
    v.volume = volume;
    v.loop = loop;
    v.endFrame = v.clip->frames;
    if (maxSeconds > 0) v.endFrame = std::min<long long>(v.endFrame, (long long)(maxSeconds * kRate));

    pw_thread_loop_lock(m_loop);
    m_mixer->voices.push_back(std::move(v));
    if (m_debug) { m_mixer->askedAt = std::chrono::steady_clock::now(); m_mixer->measure = true; }
    pw_stream_set_active(m_mixer->stream, true);
    pw_thread_loop_unlock(m_loop);

    const bool wasActive = !m_playing.isEmpty();
    m_playing.insert(id);
    m_pause->stop();
    m_close->stop();
    if (!wasActive) emit activeChanged();
    return true;
}

void SfxEngine::voicesEnded(const std::vector<int> &ids)
{
    for (int id : ids) if (m_playing.remove(id)) emit finished(id);
    if (m_playing.isEmpty()) { m_pause->start(); emit activeChanged(); }
}

void SfxEngine::stop(int id)
{
    if (m_pendingIds.remove(id)) { emit finished(id); return; }
    if (!m_playing.contains(id)) return;
    if (m_mixer) {
        pw_thread_loop_lock(m_loop);
        auto &vs = m_mixer->voices;
        vs.erase(std::remove_if(vs.begin(), vs.end(), [id](const SfxVoice &v) { return v.id == id; }), vs.end());
        pw_thread_loop_unlock(m_loop);
    }
    voicesEnded({id});
}

void SfxEngine::stopAll()
{
    const auto pending = m_pendingIds;
    for (int id : pending) stop(id);
    const auto playing = m_playing;
    for (int id : playing) stop(id);
}

bool SfxEngine::active() const { return !m_playing.isEmpty(); }
int SfxEngine::cachedSounds() const { return int(m_cache.size()); }
