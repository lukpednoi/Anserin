#pragma once
// anserin-core: small shared helpers (file reading, JSON output, watch loops).
#include <cstdio>
#include <string>

namespace core {

// whole small file (sysfs / procfs), trimmed of the trailing newline; empty when it cannot be read
std::string readFile(const std::string &path);
long long readLong(const std::string &path, long long fallback = -1);
// writes one JSON line and flushes, so a reader on a pipe sees it at once
void emit(const std::string &json);
std::string jsonString(const std::string &s);
// for watch commands: die with the shell (no orphaned watchers), and stop quietly when the reader goes away
void becomeWatcher();
void sleepMs(int ms);
double nowSeconds();

int sysinfoCommand(int argc, char **argv);
int monitorsCommand(int argc, char **argv);
int locksCommand(int argc, char **argv);
int brightnessCommand(int argc, char **argv);
int gammaCommand(int argc, char **argv);

} // namespace core
