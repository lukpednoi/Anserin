// anserin-wallpaper index SRC CACHE RUN: the wallpaper list, as scripts/wallpaper/indexer.py made it (same
// files, lock and JSON, so either can run), plus a small thumbnail per picture for the lists and a better
// poster for videos whose first second is one flat colour.
//
//   CACHE/dirs/<hash>/index.json     the index (items sorted by file name), also CACHE/current_index.json
//   CACHE/dirs/<hash>/posters/       one frame per video (ffmpeg), 960 px wide
//   CACHE/dirs/<hash>/thumbs/        one JPEG per picture, at most 960 px wide (new: thumbPath / thumbUrl)
//   RUN/indexer_<hash>.lock / .dirty only one indexer per folder; a second run marks it dirty and prints the old index
//
// Each picture is decoded once, already scaled down (JPEG decodes at 1/2..1/8 size), for both its thumbnail
// and its colour. Unchanged files keep what the index already has.
#include <QCoreApplication>
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImage>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QMap>
#include <QMutex>
#include <QProcess>
#include <QSaveFile>
#include <QSet>
#include <QThreadPool>
#include <QUrl>

#include <algorithm>
#include <cmath>
#include <cstdio>
#include <fcntl.h>
#include <map>
#include <sys/file.h>
#include <unistd.h>

namespace {

constexpr int kColorVersion = 5;      // the colour rules below are indexer.py's version 5
constexpr int kPosterVersion = 2;     // 2: flat first frames replaced by a later one
constexpr int kThumbWidth = 960;   // the big carousel card is ~800 px; list tiles are smaller

QString hash16(const QString &s)
{
    return QString::fromLatin1(QCryptographicHash::hash(s.toUtf8(), QCryptographicHash::Sha256).toHex().left(16));
}

QString fileUrl(const QString &path) { return QStringLiteral("file://") + path; }

// ---------- colour (indexer.py's get_color_bucket and extract_color) ----------

QString bucketOf(int ri, int gi, int bi)
{
    const double r = ri / 255.0, g = gi / 255.0, b = bi / 255.0;
    const double mx = std::max({r, g, b}), mn = std::min({r, g, b}), d = mx - mn, v = mx;
    double h = 0;
    if (mx != mn) {
        if (mx == r) h = (g - b) / d + (g < b ? 6.0 : 0.0);
        else if (mx == g) h = (b - r) / d + 2.0;
        else h = (r - g) / d + 4.0;
        h /= 6.0;
    }
    h *= 360.0;
    if (v < 0.18) return "Black";
    if (d / mx < 0.15) {
        const double l = (mx + mn) / 2;
        if (l < 0.20) return "Black";
        return l > 0.85 ? "White" : "Gray";
    }
    if (h >= 345 || h < 15) return (mx + mn) / 2 > 0.65 ? "Pink" : "Red";
    if (h < 45) return v < 0.70 ? "Brown" : "Orange";
    if (h < 75) return "Yellow";
    if (h < 165) return "Green";
    if (h < 260) return "Blue";
    if (h < 315) return "Purple";
    if (h < 345) return "Pink";
    return "Gray";
}

QString bucketOf(const QString &hex)
{
    QString s = hex.trimmed().remove('#').left(6);
    bool ok = s.size() == 6;
    const uint v = s.toUInt(&ok, 16);
    if (!ok) return "Gray";
    return bucketOf(int(v >> 16) & 255, int(v >> 8) & 255, int(v) & 255);
}

QString colourOf(const QImage &image)
{
    if (image.isNull()) return "#808080";
    const QImage px = image.convertToFormat(QImage::Format_RGB888)
                          .scaled(64, 64, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    std::map<uint32_t, int> counts;
    for (int y = 0; y < px.height(); ++y) {
        const uchar *line = px.constScanLine(y);
        for (int x = 0; x < px.width(); ++x)
            ++counts[(uint32_t(line[3 * x]) << 16) | (uint32_t(line[3 * x + 1]) << 8) | line[3 * x + 2]];
    }
    struct Sum { double n = 0, r = 0, g = 0, b = 0; };
    QMap<QString, Sum> buckets;
    for (const auto &[rgb, n] : counts) {
        const int r = int(rgb >> 16), g = int(rgb >> 8) & 255, b = int(rgb) & 255;
        Sum &s = buckets[bucketOf(r, g, b)];
        s.n += n; s.r += double(r) * n; s.g += double(g) * n; s.b += double(b) * n;
    }
    // mostly neutral pictures stay neutral; otherwise their strongest colour group
    Sum pick;
    const double total = px.width() * px.height();
    double neutral = 0;
    for (const char *k : {"Black", "Gray", "White"}) neutral += buckets.value(k).n;
    if (neutral >= total * 0.65) {
        for (const char *k : {"Black", "Gray", "White"}) {
            const Sum s = buckets.value(k);
            pick.n += s.n; pick.r += s.r; pick.g += s.g; pick.b += s.b;
        }
    } else {
        for (const char *k : {"Black", "Gray", "White"}) buckets.remove(k);
        QString best;
        for (auto it = buckets.cbegin(); it != buckets.cend(); ++it)   // most pixels; ties: the later name
            if (best.isEmpty() || it->n > buckets[best].n || (it->n == buckets[best].n && it.key() > best)) best = it.key();
        pick = buckets.value(best);
    }
    if (pick.n <= 0) return "#808080";
    return QString::asprintf("#%02x%02x%02x", int(std::lround(pick.r / pick.n)), int(std::lround(pick.g / pick.n)),
                             int(std::lround(pick.b / pick.n)));
}

// ---------- pictures ----------

// the picture scaled to at most kThumbWidth wide, decoded at that size where the format allows it
QImage readSmall(const QString &path)
{
    QImageReader reader(path);
    reader.setAutoTransform(true);
    const QSize full = reader.size();
    if (full.isValid() && full.width() > kThumbWidth)
        reader.setScaledSize(QSize(kThumbWidth, std::max(1, int(std::lround(double(full.height()) * kThumbWidth / full.width())))));
    QImage image = reader.read();
    if (image.isNull()) {
        // a format this Qt cannot read (no image plugin): let ImageMagick make the small copy
        const QString tmp = QDir::tempPath() + "/anserin-thumb-" + hash16(path) + ".jpg";
        if (QProcess::execute("magick", {path + "[0]", "-auto-orient", "-thumbnail", QString::number(kThumbWidth) + "x>", tmp}) == 0)
            image.load(tmp);
        QFile::remove(tmp);
    }
    return image;
}

bool writeJpeg(const QImage &image, const QString &path, int quality = 86)
{
    QSaveFile f(path);
    if (!f.open(QIODevice::WriteOnly)) return false;
    QImage rgb = image.hasAlphaChannel() ? image.convertToFormat(QImage::Format_RGB888) : image;
    return rgb.save(&f, "JPEG", quality) && f.commit();
}

// ---------- video posters ----------

// true when the frame is (nearly) one flat colour: a fade-in, a title card, a black start
bool isFlat(const QImage &image)
{
    if (image.isNull()) return true;
    const QImage px = image.convertToFormat(QImage::Format_RGB888).scaled(32, 32, Qt::IgnoreAspectRatio, Qt::SmoothTransformation);
    double sum[3] = {}, sq[3] = {};
    const int n = px.width() * px.height();
    for (int y = 0; y < px.height(); ++y) {
        const uchar *line = px.constScanLine(y);
        for (int x = 0; x < px.width() * 3; ++x) { sum[x % 3] += line[x]; sq[x % 3] += double(line[x]) * line[x]; }
    }
    double spread = 0;
    for (int c = 0; c < 3; ++c) spread = std::max(spread, std::sqrt(std::max(0.0, sq[c] / n - (sum[c] / n) * (sum[c] / n))));
    return spread < 6.0;
}

bool grabFrame(const QString &video, const QString &out, const QString &seek)
{
    QProcess p;
    p.setProcessChannelMode(QProcess::ForwardedErrorChannel);
    p.setStandardErrorFile(QProcess::nullDevice());
    p.start("ffmpeg", {"-y", "-hide_banner", "-loglevel", "error", "-ss", seek, "-i", video, "-vframes", "1",
                       "-vf", "scale=960:-2:force_original_aspect_ratio=decrease", "-q:v", "2", out});
    if (!p.waitForFinished(8000)) { p.kill(); p.waitForFinished(); return false; }
    return p.exitCode() == 0 && QFileInfo(out).size() > 512;
}

// a poster from the first moment that is not one flat colour (1 s, 3 s, 8 s, 20 s), else the first that exists
bool makePoster(const QString &video, const QString &poster)
{
    const QString tmp = poster + ".tmp.jpg";
    QImage fallback;
    for (const char *seek : {"1", "0.5", "3", "8", "20"}) {
        if (!grabFrame(video, tmp, seek)) continue;
        QImage frame(tmp);
        if (!isFlat(frame)) { QFile::remove(poster); return QFile::rename(tmp, poster); }
        if (fallback.isNull()) fallback = frame;
    }
    QFile::remove(tmp);
    if (!fallback.isNull()) return writeJpeg(fallback, poster, 92);
    QImage blank(960, 540, QImage::Format_RGB888);
    blank.fill(QColor("#1e1e2e"));
    return writeJpeg(blank, poster);
}

// ---------- one entry ----------

struct Entry { QString name, path; qint64 mtime, size; bool video; };

QJsonObject process(const Entry &e, const QJsonObject &cachedIn, const QString &posterDir, const QString &thumbDir)
{
    QJsonObject cached = cachedIn;
    const bool same = !cached.isEmpty() && cached.value("mtime").toInteger() == e.mtime && cached.value("size").toInteger() == e.size;
    if (!cached.isEmpty()) { cached["filePath"] = e.path; cached["fileUrl"] = fileUrl(e.path); }   // moved into Images/Videos

    if (e.video) {
        const QString poster = posterDir + "/" + hash16(e.name) + ".jpg";
        const bool posterOk = same && QFileInfo(cached.value("posterPath").toString()).size() > 512;
        if (posterOk && cached.value("posterVersion").toInt() >= kPosterVersion) return cached;
        bool remade = false;
        if (!posterOk) remade = makePoster(e.path, poster);
        else if (isFlat(QImage(cached.value("posterPath").toString()))) remade = makePoster(e.path, poster);   // older flat poster
        QJsonObject o = posterOk && !remade ? cached : QJsonObject{
            {"fileName", e.name}, {"filePath", e.path}, {"fileUrl", fileUrl(e.path)}, {"isVideo", true},
            {"posterPath", poster}, {"posterUrl", fileUrl(poster)}, {"bucket", "Video"},
            {"mtime", e.mtime}, {"size", e.size}};
        if (remade || !posterOk) o["hex"] = colourOf(QImage(poster));
        o["posterVersion"] = kPosterVersion;
        return o;
    }

    const QString thumb = thumbDir + "/" + hash16(e.name) + ".jpg";
    if (same && QFileInfo::exists(cached.value("thumbPath").toString())) return cached;
    const QImage small = readSmall(e.path);
    const bool thumbOk = !small.isNull() && writeJpeg(small, thumb);
    if (same) {   // only the thumbnail was missing: keep the colour the index has
        if (thumbOk) { cached["thumbPath"] = thumb; cached["thumbUrl"] = fileUrl(thumb); }
        return cached;
    }
    const QString hex = colourOf(small);
    QJsonObject o{{"fileName", e.name}, {"filePath", e.path}, {"fileUrl", fileUrl(e.path)}, {"isVideo", false},
                  {"posterPath", ""}, {"posterUrl", ""}, {"hex", hex}, {"bucket", bucketOf(hex)},
                  {"mtime", e.mtime}, {"size", e.size}};
    if (thumbOk) { o["thumbPath"] = thumb; o["thumbUrl"] = fileUrl(thumb); }
    return o;
}

// ---------- the folder ----------

QJsonObject runIndexing(const QString &srcDir, const QString &perDir, const QString &indexFile, const QString &posterDir,
                        const QString &thumbDir, const QString &cacheDir)
{
    QDir().mkpath(posterDir);
    QDir().mkpath(thumbDir);

    QMap<QString, QJsonObject> cached;
    {
        QFile f(indexFile);
        if (f.open(QIODevice::ReadOnly)) {
            const QJsonObject old = QJsonDocument::fromJson(f.readAll()).object();
            const bool sameColours = old.value("colorVersion").toInt() == kColorVersion;
            for (const QJsonValue &v : old.value("items").toArray()) {
                const QJsonObject it = v.toObject();
                const QString name = it.value("fileName").toString();
                if (!name.isEmpty() && (sameColours || it.value("isVideo").toBool())) cached[name] = it;
            }
        }
    }

    static const QSet<QString> pictures{"jpg", "jpeg", "png", "webp", "gif", "bmp"};
    static const QSet<QString> videos{"mp4", "mkv", "mov", "webm"};
    // wallpapers sit in the folder itself and, sorted by kind, in its Images and Videos subfolders
    QFileInfoList found = QDir(srcDir).entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden, QDir::NoSort);
    const QFileInfoList top = found;
    for (const QFileInfo &sub : top) {
        const QString n = sub.fileName().toLower();
        if (sub.isDir() && (n == "images" || n == "videos"))
            found += QDir(sub.absoluteFilePath()).entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden, QDir::NoSort);
    }
    QList<Entry> entries;
    QSet<QString> names, reals;
    for (const QFileInfo &fi : found) {
        if (!fi.isFile()) continue;
        const QString name = fi.fileName(), ext = fi.suffix().toLower();
        if (names.contains(name) || (!pictures.contains(ext) && !videos.contains(ext))) continue;
        const QString real = fi.canonicalFilePath();
        if (real.isEmpty() || reals.contains(real)) continue;
        names.insert(name); reals.insert(real);
        entries.append({name, fi.absoluteFilePath(), fi.lastModified().toSecsSinceEpoch(), fi.size(), videos.contains(ext)});
    }

    QMap<QString, QJsonObject> done;
    QMutex lock;
    QThreadPool pool;
    pool.setMaxThreadCount(std::min(12, std::max(4, QThread::idealThreadCount())));
    for (const Entry &e : entries) {
        pool.start([&, e]() {
            const QJsonObject o = process(e, cached.value(e.name), posterDir, thumbDir);
            QMutexLocker l(&lock);
            done.insert(e.name, o);
        });
    }
    pool.waitForDone();

    QJsonArray items;
    for (const QJsonObject &o : done) items.append(o);   // QMap: sorted by file name
    const QJsonObject out{{"srcDir", QDir(srcDir).absolutePath()}, {"dirHash", hash16(QDir(srcDir).absolutePath())},
                          {"updatedAt", QDateTime::currentSecsSinceEpoch()}, {"colorVersion", kColorVersion}, {"items", items}};

    // thumbnails of pictures that left the folder go away with them
    QSet<QString> keep;
    for (const QJsonObject &o : done) keep.insert(QFileInfo(o.value("thumbPath").toString()).fileName());
    for (const QString &t : QDir(thumbDir).entryList({"*.jpg"}, QDir::Files))
        if (!keep.contains(t)) QFile::remove(thumbDir + "/" + t);

    auto save = [](const QString &path, const QByteArray &data) {
        QSaveFile f(path);
        if (f.open(QIODevice::WriteOnly)) { f.write(data); f.commit(); }
    };
    save(indexFile, QJsonDocument(out).toJson(QJsonDocument::Indented));
    save(cacheDir + "/current_index.json", QJsonDocument(out).toJson(QJsonDocument::Compact));
    Q_UNUSED(perDir);
    return out;
}

} // namespace

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);   // image format plugins (webp...) are found through it
    const QStringList args = app.arguments().mid(1);
    if (args.size() < 2 || args[0] != "index") {
        std::fprintf(stderr, "usage: anserin-wallpaper index SRC_DIR [CACHE_DIR] [RUN_DIR]\n");
        return 2;
    }
    QString src = args[1];
    if (src.startsWith("file://")) src = QUrl(src).toLocalFile();
    src = QDir(src).absolutePath();
    const QString cacheDir = args.size() > 2 ? args[2] : QDir::homePath() + "/.cache/anserin/wallpaper";
    const QString runDir = args.size() > 3 ? args[3] : cacheDir;
    QDir().mkpath(cacheDir);
    QDir().mkpath(runDir);

    const QString dirHash = hash16(src);
    const QString perDir = cacheDir + "/dirs/" + dirHash;
    const QString indexFile = perDir + "/index.json";
    const QString dirtyFile = runDir + "/indexer_" + dirHash + ".dirty";
    const QString lockFile = runDir + "/indexer_" + dirHash + ".lock";

    const int fd = open(QFile::encodeName(lockFile).constData(), O_WRONLY | O_CREAT | O_CLOEXEC, 0644);
    if (fd < 0 || flock(fd, LOCK_EX | LOCK_NB) != 0) {
        // another indexer works on this folder: ask it for one more pass, answer with what is there now
        QFile dirty(dirtyFile);
        if (dirty.open(QIODevice::WriteOnly)) dirty.write("1");
        QFile f(indexFile);
        if (f.open(QIODevice::ReadOnly)) { const QByteArray d = f.readAll(); std::fwrite(d.constData(), 1, size_t(d.size()), stdout); }
        return 0;
    }
    QJsonObject result;
    do {
        QFile::remove(dirtyFile);
        result = runIndexing(src, perDir, indexFile, perDir + "/posters", perDir + "/thumbs", cacheDir);
    } while (QFile::exists(dirtyFile));
    const QByteArray out = QJsonDocument(result).toJson(QJsonDocument::Compact);
    std::fwrite(out.constData(), 1, size_t(out.size()), stdout);
    close(fd);
    return 0;
}
