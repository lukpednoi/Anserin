// anserin-core sysinfo / watch sysinfo: CPU, memory, temperature, network and disk use as one JSON line, with
// the same keys serpantinum-core used: cpu, ramPercent, ramGb, temp, netRx, netTx (bytes/s), diskPercent,
// diskUsedGb, diskTotalGb.
#include "common.h"

#include <algorithm>
#include <cmath>
#include <cstdlib>
#include <dirent.h>
#include <fstream>
#include <sstream>
#include <string>
#include <sys/statvfs.h>
#include <vector>

namespace core {
namespace {

struct Cpu { unsigned long long idle = 0, total = 0; };
struct Net { unsigned long long rx = 0, tx = 0; };

Cpu readCpu()
{
    std::ifstream f("/proc/stat");
    std::string label;
    Cpu c;
    f >> label;
    unsigned long long v, i = 0;
    while (f >> v && i < 10) {
        c.total += v;
        if (i == 3 || i == 4) c.idle += v;   // idle + iowait
        ++i;
        if (f.peek() == '\n') break;
    }
    return c;
}

Net readNet()
{
    std::ifstream f("/proc/net/dev");
    std::string line;
    Net n;
    std::getline(f, line); std::getline(f, line);
    while (std::getline(f, line)) {
        const auto colon = line.find(':');
        if (colon == std::string::npos) continue;
        std::string name = line.substr(0, colon);
        name.erase(0, name.find_first_not_of(' '));
        if (name == "lo") continue;
        std::istringstream ss(line.substr(colon + 1));
        unsigned long long rx, x, tx;
        ss >> rx; for (int k = 0; k < 7; ++k) ss >> x; ss >> tx;
        n.rx += rx; n.tx += tx;
    }
    return n;
}

void readMem(double &percent, double &usedGb)
{
    std::ifstream f("/proc/meminfo");
    std::string key, unit;
    unsigned long long v, total = 0, avail = 0;
    while (f >> key >> v) {
        std::getline(f, unit);
        if (key == "MemTotal:") total = v;
        else if (key == "MemAvailable:") avail = v;
    }
    const double used = total > avail ? double(total - avail) : 0;
    percent = total ? std::round(used * 100.0 / double(total)) : 0;
    usedGb = std::round(used / 1024.0 / 1024.0 * 10) / 10;
}

// the CPU package temperature (coretemp / k10temp / x86_pkg_temp), else the warmest sensor; -1 when none
int readTemp()
{
    int best = -1;
    if (DIR *d = opendir("/sys/class/hwmon")) {
        while (dirent *e = readdir(d)) {
            if (e->d_name[0] == '.') continue;
            const std::string base = std::string("/sys/class/hwmon/") + e->d_name;
            const std::string name = readFile(base + "/name");
            const long long t = readLong(base + "/temp1_input");
            if (t <= 0) continue;
            if (name == "coretemp" || name == "k10temp" || name == "zenpower") { closedir(d); return int(t / 1000); }
            if (name != "nvme" && name != "BAT0") best = std::max(best, int(t / 1000));
        }
        closedir(d);
    }
    for (int i = 0; i < 32; ++i) {
        const std::string base = "/sys/class/thermal/thermal_zone" + std::to_string(i);
        const std::string type = readFile(base + "/type");
        if (type.empty()) break;
        if (type == "x86_pkg_temp") return int(readLong(base + "/temp") / 1000);
    }
    return best;
}

std::string sample(const Cpu &c0, const Cpu &c1, const Net &n0, const Net &n1, double seconds)
{
    const double dt = std::max(0.001, double(c1.total - c0.total));
    const double cpu = std::round((1.0 - double(c1.idle - c0.idle) / dt) * 100.0);
    double ramPercent, ramGb;
    readMem(ramPercent, ramGb);
    struct statvfs fs{};
    double diskTotal = 0, diskUsed = 0;
    if (statvfs("/", &fs) == 0) {
        diskTotal = double(fs.f_blocks) * fs.f_frsize / 1073741824.0;   // GiB, as before
        diskUsed = double(fs.f_blocks - fs.f_bfree) * fs.f_frsize / 1073741824.0;
    }
    char buf[512];
    std::snprintf(buf, sizeof buf,
        "{\"cpu\":%d,\"ramPercent\":%d,\"ramGb\":%.1f,\"temp\":%d,\"netRx\":%.1f,\"netTx\":%.1f,"
        "\"diskPercent\":%d,\"diskUsedGb\":%.1f,\"diskTotalGb\":%.1f}",
        int(std::max(0.0, std::min(100.0, cpu))), int(ramPercent), ramGb, readTemp(),
        double(n1.rx - n0.rx) / seconds, double(n1.tx - n0.tx) / seconds,
        diskTotal > 0 ? int(std::round(diskUsed * 100 / diskTotal)) : 0,
        std::round(diskUsed * 10) / 10, std::round(diskTotal * 10) / 10);
    return buf;
}

} // namespace

int sysinfoCommand(int argc, char **argv)
{
    // argv: [sysinfo] or [watch sysinfo [--interval S]]
    const bool watch = argc >= 1 && std::string(argv[0]) == "watch";
    double interval = 2.0;
    for (int i = 0; i < argc - 1; ++i)
        if (std::string(argv[i]) == "--interval") interval = std::max(0.25, std::atof(argv[i + 1]));
    if (watch) becomeWatcher();
    Cpu c0 = readCpu(); Net n0 = readNet(); double t0 = nowSeconds();
    sleepMs(watch ? 500 : 100);
    while (true) {
        const Cpu c1 = readCpu(); const Net n1 = readNet(); const double t1 = nowSeconds();
        emit(sample(c0, c1, n0, n1, std::max(0.05, t1 - t0)));
        if (!watch) return 0;
        c0 = c1; n0 = n1; t0 = t1;
        sleepMs(int(interval * 1000));
    }
}

} // namespace core
