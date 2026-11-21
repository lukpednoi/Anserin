#include "common.h"

#include <chrono>
#include <csignal>
#include <fstream>
#include <sstream>
#include <thread>
#include <sys/prctl.h>
#include <unistd.h>

namespace core {

std::string readFile(const std::string &path)
{
    std::ifstream f(path);
    if (!f) return {};
    std::stringstream ss;
    ss << f.rdbuf();
    std::string s = ss.str();
    while (!s.empty() && (s.back() == '\n' || s.back() == ' ')) s.pop_back();
    return s;
}

long long readLong(const std::string &path, long long fallback)
{
    const std::string s = readFile(path);
    if (s.empty()) return fallback;
    try { return std::stoll(s); } catch (...) { return fallback; }
}

void emit(const std::string &json)
{
    std::fputs(json.c_str(), stdout);
    std::fputc('\n', stdout);
    std::fflush(stdout);
}

std::string jsonString(const std::string &s)
{
    std::string out = "\"";
    for (char c : s) {
        switch (c) {
        case '"': out += "\\\""; break;
        case '\\': out += "\\\\"; break;
        case '\n': out += "\\n"; break;
        default:
            if ((unsigned char)c < 0x20) { char b[8]; std::snprintf(b, sizeof b, "\\u%04x", c); out += b; }
            else out += c;
        }
    }
    return out + "\"";
}

void becomeWatcher()
{
    prctl(PR_SET_PDEATHSIG, SIGTERM);       // the script or shell that started us went away: so do we
    if (getppid() == 1) std::exit(0);       // it already had
    std::signal(SIGPIPE, SIG_DFL);          // the reader closed the pipe: end quietly
}

void sleepMs(int ms) { std::this_thread::sleep_for(std::chrono::milliseconds(ms)); }

double nowSeconds()
{
    using namespace std::chrono;
    return duration<double>(steady_clock::now().time_since_epoch()).count();
}

} // namespace core
