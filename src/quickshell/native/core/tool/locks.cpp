// anserin-core watch locks: Caps Lock and Num Lock as {"numLock":bool,"capsLock":bool}, now and on every change.
// Read from the keyboard LEDs the kernel keeps (/sys/class/leds/*::capslock), which every compositor drives.
// With --changes (what kb_locks.sh execs) it prints only what changed, as "capslock 0|1" / "numlock 0|1" lines.
#include "common.h"

#include <dirent.h>
#include <string>
#include <vector>

namespace core {
namespace {
// the LED brightness files, found again every few seconds (keyboards come and go) instead of on every look
struct Leds {
    std::vector<std::string> caps, num;
    double foundAt = -1e9;
    void refresh()
    {
        if (nowSeconds() - foundAt < 5) return;
        foundAt = nowSeconds();
        caps.clear(); num.clear();
        if (DIR *d = opendir("/sys/class/leds")) {
            while (dirent *e = readdir(d)) {
                const std::string n = e->d_name;
                auto ends = [&](const std::string &suffix) {
                    return n.size() > suffix.size() && n.compare(n.size() - suffix.size(), std::string::npos, suffix) == 0;
                };
                if (ends("::capslock")) caps.push_back("/sys/class/leds/" + n + "/brightness");
                else if (ends("::numlock")) num.push_back("/sys/class/leds/" + n + "/brightness");
            }
            closedir(d);
        }
    }
    static bool anyOn(const std::vector<std::string> &files)
    {
        for (const auto &f : files) if (readLong(f, 0) > 0) return true;
        return false;
    }
};
std::string state(bool caps, bool num)
{
    return std::string("{\"numLock\":") + (num ? "true" : "false") + ",\"capsLock\":" + (caps ? "true" : "false") + "}";
}
} // namespace

int locksCommand(int argc, char **argv)
{
    // argv: [locks] or [watch locks [--changes]]
    const bool watch = argc >= 2;
    const bool changes = argc >= 3 && std::string(argv[2]) == "--changes";
    Leds leds;
    leds.refresh();
    bool caps = Leds::anyOn(leds.caps), num = Leds::anyOn(leds.num);
    if (!changes) emit(state(caps, num));
    if (!watch) return 0;
    becomeWatcher();
    while (true) {
        sleepMs(150);                     // two tiny sysfs reads; the LEDs give no change events
        leds.refresh();
        const bool c = Leds::anyOn(leds.caps), n = Leds::anyOn(leds.num);
        if (c == caps && n == num) continue;
        if (changes) {
            if (c != caps) emit(std::string("capslock ") + (c ? "1" : "0"));
            if (n != num) emit(std::string("numlock ") + (n ? "1" : "0"));
        } else {
            emit(state(c, n));
        }
        caps = c; num = n;
    }
}

} // namespace core
