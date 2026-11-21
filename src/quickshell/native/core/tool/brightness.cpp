// anserin-core brightness: the screen backlight in percent. Reads /sys/class/backlight; sets it through logind
// (org.freedesktop.login1.Session.SetBrightness, so no root and no brightnessctl). Screens without a backlight
// (external monitors, DDC) answer "none" / exit 1 so brightness.sh keeps its own DDC path.
//   brightness [get] | set PERCENT | raise | lower | backend      watch brightness
#include "common.h"

#include <cmath>
#include <cstdlib>
#include <dirent.h>
#include <string>
#include <systemd/sd-bus.h>

namespace core {
namespace {

struct Backlight { std::string name, dir; long long max = 0; };

Backlight findBacklight()
{
    Backlight best;
    if (DIR *d = opendir("/sys/class/backlight")) {
        while (dirent *e = readdir(d)) {
            if (e->d_name[0] == '.') continue;
            const std::string dir = std::string("/sys/class/backlight/") + e->d_name;
            const long long max = readLong(dir + "/max_brightness", 0);
            if (max > best.max) best = Backlight{e->d_name, dir, max};   // the finest-grained one wins
        }
        closedir(d);
    }
    return best;
}

int percentOf(const Backlight &b)
{
    long long raw = readLong(b.dir + "/actual_brightness", -1);
    if (raw < 0) raw = readLong(b.dir + "/brightness", 0);
    return int(std::lround(double(raw) * 100.0 / double(b.max)));
}

bool setRaw(const Backlight &b, long long raw)
{
    sd_bus *bus = nullptr;
    if (sd_bus_open_system(&bus) < 0) return false;
    sd_bus_error err = SD_BUS_ERROR_NULL;
    const int r = sd_bus_call_method(bus, "org.freedesktop.login1", "/org/freedesktop/login1/session/auto",
                                     "org.freedesktop.login1.Session", "SetBrightness", &err, nullptr,
                                     "ssu", "backlight", b.name.c_str(), (uint32_t)raw);
    if (r < 0) std::fprintf(stderr, "anserin-core: SetBrightness: %s\n", err.message ? err.message : "failed");
    sd_bus_error_free(&err);
    sd_bus_unref(bus);
    return r >= 0;
}

bool setPercent(const Backlight &b, double percent)
{
    percent = std::max(0.0, std::min(100.0, percent));
    long long raw = std::llround(percent * double(b.max) / 100.0);
    if (percent > 0 && raw < 1) raw = 1;
    return setRaw(b, raw);
}

std::string state(const Backlight &b)
{
    return "{\"percent\":" + std::to_string(percentOf(b)) + ",\"backend\":\"backlight\"}";
}

} // namespace

int brightnessCommand(int argc, char **argv)
{
    // argv: [brightness ...] or [watch brightness]
    const std::string first = argc ? argv[0] : "brightness";
    const Backlight b = findBacklight();
    if (first == "watch") {
        if (b.max <= 0) { emit("{\"percent\":-1,\"backend\":\"none\"}"); return 1; }
        becomeWatcher();
        std::string last = state(b);
        emit(last);
        while (true) {
            sleepMs(250);
            const std::string now = state(b);
            if (now != last) { last = now; emit(now); }
        }
    }
    const std::string action = argc > 1 ? argv[1] : "get";
    if (action == "backend") { emit(b.max > 0 ? "backlight" : "none"); return b.max > 0 ? 0 : 1; }
    if (b.max <= 0) { emit("-1"); return 1; }
    if (action == "get") { emit(std::to_string(percentOf(b))); return 0; }
    if (action == "set" && argc > 2) return setPercent(b, std::atof(argv[2])) ? 0 : 1;
    if (action == "raise" || action == "lower") {
        const int now = percentOf(b);
        const int next = std::max(1, std::min(100, now + (action == "raise" ? 5 : -5)));
        if (!setPercent(b, next)) return 1;
        emit(std::to_string(next));
        return 0;
    }
    std::fprintf(stderr, "usage: anserin-core brightness [get|set PERCENT|raise|lower|backend]\n");
    return 2;
}

} // namespace core
