import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// What Theme → Orbit / Original does, without its look: the theme settings, wallpaper folders and the current
// wallpaper, fonts (the list, installing one), the border radius (snapped, debounced), and the colour themes
// (system and user presets, the search, Matugen, saving and deleting custom ones). Used by the Settings page
// (ThemeTab.qml) and the Control Center's board. activateTab() is called when the page using it appears;
// fontInstalled() tells it to close its font picker.
Item {
    id: logic
    property var rootObj: null
    signal fontInstalled()
    property alias activateDebounceTimer: activateDebounceTimer
    property alias borderRadiusDebounceTimer: borderRadiusDebounceTimer
    property alias wallpaperDirScanner: wallpaperDirScanner

    property var defaultThemeSettings: {
        "fontFamily": ThemeBackend.fontFamily,
        "borderRadius": ThemeBackend.borderRadius,
        "activePreset": "Matugen",
        "matugen": true,
        "colors": {}
    }

    property var themeSettings: Config.getSetting("theme", defaultThemeSettings)

    property string currentFontFamily: themeSettings.fontFamily !== undefined ? themeSettings.fontFamily : ThemeBackend.fontFamily

    property int currentBorderRadius: themeSettings.borderRadius !== undefined ? themeSettings.borderRadius : ThemeBackend.borderRadius

    property string currentPreset: themeSettings.activePreset !== undefined ? themeSettings.activePreset : "Matugen"

    property bool useMatugen: themeSettings.matugen !== undefined ? themeSettings.matugen : true

    property string currentWallpaperDir: Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "") || Quickshell.env("WALLPAPER_DIR") || (Quickshell.env("HOME") + "/Pictures/Wallpapers")

    property var availableWallpaperDirs: []

    property var curatedFonts: ThemeBackend.bundledNames

    property var blockedFontPatterns: [".notdef", "cursor", "emoji", "symbol", "pcf"]

    property var availableFonts: []

    function loadAvailableFonts() {
        if (availableFonts.length > 0) return;
        let curated = logic.curatedFonts;
        let dedupedCurated = [];
        let seen = new Set();

        for (let i = 0; i < curated.length; i++) {
            let key = curated[i].toLowerCase().trim();
            if (!seen.has(key)) {
                seen.add(key);
                dedupedCurated.push(curated[i]);
            }
        }

        let rest = [];
        let raw = Qt.fontFamilies();
        for (let i = 0; i < raw.length; i++) {
            let name = raw[i];
            let key = name.toLowerCase().trim();

            if (seen.has(key)) continue;

            let blocked = false;
            for (let j = 0; j < logic.blockedFontPatterns.length; j++) {
                if (key.indexOf(logic.blockedFontPatterns[j]) !== -1) {
                    blocked = true;
                    break;
                }
            }
            if (blocked) continue;

            seen.add(key);
            rest.push(name);
        }
        rest.sort(function(a, b) { return a.localeCompare(b); });
        let combined = dedupedCurated.concat(rest);
        if (logic.currentFontFamily && combined.indexOf(logic.currentFontFamily) === -1) {
            combined.push(logic.currentFontFamily);
        }
        logic.availableFonts = combined;
    }

    property var systemPresets: []

    property var userPresets: []

    property string themeSearchText: ""

    property string _lastPresetsStr: ""

    property bool _needsReload: true

    property var filteredUserPresets: {
        let txt = themeSearchText.trim().toLowerCase();
        if (txt === "") return logic.userPresets;
        let res = [];
        for (let i = 0; i < logic.userPresets.length; i++) {
            let p = logic.userPresets[i];
            if (p && p.name && p.name.toLowerCase().indexOf(txt) !== -1) {
                res.push(p);
            }
        }
        return res;
    }

    property var filteredSystemPresets: {
        let txt = themeSearchText.trim().toLowerCase();
        let result = [];
        let pendingDivider = false;
        for (let i = 0; i < logic.systemPresets.length; i++) {
            let p = logic.systemPresets[i];
            if (p.isDivider) {
                pendingDivider = true;
            } else {
                if (txt === "" || (p.name && p.name.toLowerCase().indexOf(txt) !== -1)) {
                    if (pendingDivider) {
                        result.push({ isDivider: true });
                        pendingDivider = false;
                    }
                    result.push(p);
                }
            }
        }
        return result;
    }

    property var matugenColors: ({})

    property color prevMatugenBase: ThemeBackend.base

    property color prevMatugenText: ThemeBackend.text

    property color prevMatugenBlue: ThemeBackend.blue

    property color prevMatugenMauve: ThemeBackend.mauve

    property color prevMatugenPeach: ThemeBackend.peach

    property color prevMatugenGreen: ThemeBackend.green

    property color prevMatugenRed: ThemeBackend.red

    property string activeScreenName: (Quickshell.screens && Quickshell.screens.length > 0 && Quickshell.screens[0].name) ? Quickshell.screens[0].name : ""

    property string currentWallpaperPath: ""

    property int wallpaperRevision: 0

    readonly property string orbitWallpaperPath: Wallpaper.getWallpaperPath(activeScreenName) || currentWallpaperPath || (Caching.getCacheDir("wallpaper") + "/current_wallpaper.png")

    property bool isWallpaperVideo: {
        let lp = currentWallpaperPath.toLowerCase();
        return lp.endsWith(".mp4") || lp.endsWith(".mkv") || lp.endsWith(".mov") || lp.endsWith(".webm") || lp.indexOf("000_") !== -1;
    }

    Timer {
        id: borderRadiusDebounceTimer
        interval: 250
        repeat: false
        onTriggered: {
            logic.updateBorderRadiusSetting();
        }
    }

    Timer {
        id: snapshotDebounceTimer
        interval: 200
        repeat: false
        onTriggered: {
            logic.wallpaperRevision++;
        }
    }

    function getSnappedRadius(rawVal) {
        let snapPoints = [0, 2, 4, 8, 10, 16, 24, 32, 48, 52, 58, 64];
        let rounded = Math.round(rawVal);
        let closest = snapPoints[0];
        let minDiff = Math.abs(rounded - snapPoints[0]);
        for (let i = 1; i < snapPoints.length; i++) {
            let diff = Math.abs(rounded - snapPoints[i]);
            if (diff < minDiff) {
                minDiff = diff;
                closest = snapPoints[i];
            }
        }
        if (minDiff <= 2) {
            return closest;
        }
        return rounded;
    }

    FileView {
        id: wpStateWatcher
        path: logic.activeScreenName !== "" ? (Caching.getCacheDir("wallpaper") + "/current_" + logic.activeScreenName) : ""
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let res = text().trim();
            if (res !== "" && res !== logic.currentWallpaperPath) {
                logic.currentWallpaperPath = res;
                logic.wallpaperRevision++;
            }
        }
    }

    FileView {
        id: wpSnapshotWatcher
        path: Caching.getCacheDir("wallpaper") + "/current_wallpaper.png"
        watchChanges: true
        onFileChanged: snapshotDebounceTimer.restart()
        onLoaded: snapshotDebounceTimer.restart()
    }

    Process {
        id: wallFetcher
        running: false
        command: {
            let screenName = logic.activeScreenName;
            let mainQmlPath = Caching.mainQml || "";
            let curDir = logic.currentWallpaperDir || "";
            let pyScript =
                "import os, subprocess, sys\n" +
                "home = os.path.expanduser('~')\n" +
                "main_qml = sys.argv[1]\n" +
                "screen = sys.argv[2]\n" +
                "cur_dir = sys.argv[3]\n" +
                "if not main_qml or not screen:\n" +
                "    print('')\n" +
                "    sys.exit(0)\n" +
                "try:\n" +
                "    p = subprocess.run(['quickshell', '-p', main_qml, 'ipc', 'call', 'wallpaper', 'getWallpaperPath', screen], capture_output=True, text=True)\n" +
                "    val = p.stdout.strip()\n" +
                "except Exception:\n" +
                "    val = ''\n" +
                "if not val:\n" +
                "    try:\n" +
                "        p = subprocess.run(['quickshell', '-p', main_qml, 'ipc', 'call', 'wallpaper', 'getWallpaper', screen], capture_output=True, text=True)\n" +
                "    except Exception:\n" +
                "        val = ''\n" +
                "if not val:\n" +
                "    print('')\n" +
                "    sys.exit(0)\n" +
                "if os.path.isabs(val) and os.path.exists(val):\n" +
                "    print(val)\n" +
                "    sys.exit(0)\n" +
                "candidates = []\n" +
                "if cur_dir and os.path.isdir(cur_dir):\n" +
                "    candidates.append(cur_dir)\n" +
                "candidates.extend([\n" +
                "    os.path.join(home, 'Pictures', 'Wallpapers'),\n" +
                "    os.path.join(home, 'Wallpapers'),\n" +
                "    os.path.join(home, 'Pictures'),\n" +
                "    os.path.join(home, 'Videos'),\n" +
                "    os.path.join(home, 'Videos', 'Wallpapers'),\n" +
                "    os.path.join(home, '.local/share/wallpapers'),\n" +
                "    '/usr/share/backgrounds',\n" +
                "    '/usr/share/wallpapers'\n" +
                "])\n" +
                "base_name = os.path.basename(val)\n" +
                "found = ''\n" +
                "for d in candidates:\n" +
                "    target = os.path.join(d, base_name)\n" +
                "    if os.path.isfile(target):\n" +
                "        found = target\n" +
                "        break\n" +
                "if not found:\n" +
                "    for root_dir in [os.path.join(home, 'Pictures'), os.path.join(home, 'Wallpapers'), '/usr/share/backgrounds']:\n" +
                "        if os.path.isdir(root_dir):\n" +
                "            for root, dirs, files in os.walk(root_dir):\n" +
                "                if base_name in files:\n" +
                "                    found = os.path.join(root, base_name)\n" +
                "                    break\n" +
                "            if found:\n" +
                "                break\n" +
                "if not found:\n" +
                "    found = os.path.join(cur_dir, val) if cur_dir else val\n" +
                "print(found)\n";
            return ["python3", "-c", pyScript, mainQmlPath, screenName, curDir];
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let res = this.text.trim();
                if (res !== "" && res !== logic.currentWallpaperPath) {
                    logic.currentWallpaperPath = res;
                    logic.wallpaperRevision++;
                }
            }
        }
    }

    Process {
        id: wallpaperDirScanner
        running: false
        command: [
            "bash", "-c",
            "python3 -c '\n" +
            "import os\n" +
            "home = os.path.expanduser(\"~\")\n" +
            "exts = {\".jpg\", \".jpeg\", \".png\", \".webp\", \".bmp\", \".mp4\", \".mkv\", \".mov\", \".webm\"}\n" +
            "dirs = set()\n" +
            "candidates = [\n" +
            "    os.path.join(home, \"Pictures\"),\n" +
            "    os.path.join(home, \"Pictures\", \"Wallpapers\"),\n" +
            "    os.path.join(home, \"Wallpapers\"),\n" +
            "    os.path.join(home, \"Videos\"),\n" +
            "    os.path.join(home, \"Videos\", \"Wallpapers\"),\n" +
            "    os.path.join(home, \".local/share/wallpapers\"),\n" +
            "    \"/usr/share/backgrounds\",\n" +
            "    \"/usr/share/wallpapers\"\n" +
            "]\n" +
            "for c in candidates:\n" +
            "    if not os.path.isdir(c):\n" +
            "        continue\n" +
            "    dirs.add(c)\n" +
            "    for root, subdirs, files in os.walk(c, followlinks=True):\n" +
            "        depth = root[len(c):].count(os.sep)\n" +
            "        if depth > 3:\n" +
            "            subdirs[:] = []\n" +
            "            continue\n" +
            "        subdirs[:] = [d for d in subdirs if not d.startswith(\".\")]\n" +
            "        if any(os.path.splitext(f)[1].lower() in exts for f in files):\n" +
            "            dirs.add(root)\n" +
            "sorted_dirs = sorted(list(dirs), key=lambda x: (x.count(os.sep), x.lower()))\n" +
            "print(\"\\n\".join(sorted_dirs))\n" +
            "'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                let lines = this.text.trim().split("\n").map(s => s.trim()).filter(s => s.length > 0);
                if (logic.currentWallpaperDir && lines.indexOf(logic.currentWallpaperDir) === -1) {
                    lines.unshift(logic.currentWallpaperDir);
                }
                logic.availableWallpaperDirs = lines;
            }
        }
    }

    Timer {
        id: activateDebounceTimer
        interval: 220
        repeat: false
        onTriggered: {
            wallpaperDirScanner.running = false;
            wallpaperDirScanner.running = true;
            wallFetcher.running = false;
            wallFetcher.running = true;
            if (logic._needsReload) {
                logic._needsReload = false;
                logic.reloadThemes();
            }
        }
    }

    function activateTab() {
        logic.loadAvailableFonts();
        activateDebounceTimer.restart();
    }

    onMatugenColorsChanged: {
        prevMatugenBase = matugenColors.base || ThemeBackend.base;
        prevMatugenText = matugenColors.text || ThemeBackend.text;
        prevMatugenBlue = matugenColors.blue || ThemeBackend.blue;
        prevMatugenMauve = matugenColors.mauve || ThemeBackend.mauve;
        prevMatugenPeach = matugenColors.peach || ThemeBackend.peach;
        prevMatugenGreen = matugenColors.green || ThemeBackend.green;
        prevMatugenRed = matugenColors.red || ThemeBackend.red;
    }

    function getCardBase(m) { return m.isMatugen ? logic.prevMatugenBase : (m.colors && m.colors.base ? m.colors.base : ThemeBackend.base); }

    function getCardText(m) { return m.isMatugen ? logic.prevMatugenText : (m.colors && m.colors.text ? m.colors.text : ThemeBackend.text); }

    function getCardDots(m) {
        if (m.isMatugen) return [logic.prevMatugenBase, logic.prevMatugenBlue, logic.prevMatugenMauve, logic.prevMatugenPeach, logic.prevMatugenGreen, logic.prevMatugenRed];
        if (m.colors) return [m.colors.text || ThemeBackend.text, m.colors.blue || ThemeBackend.blue, m.colors.mauve || ThemeBackend.mauve, m.colors.peach || ThemeBackend.peach, m.colors.green || ThemeBackend.green, m.colors.red || ThemeBackend.red];
        return [];
    }

    FileView {
        id: matugenColorsWatcher
        path: (typeof Caching !== "undefined" && Caching.stateDir ? Caching.stateDir : ((Quickshell.env("HOME") ?? "") + "/.local/state/anserin")) + "/qs_matugen_colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let data = JSON.parse(text().trim());
                logic.matugenColors = data.colors || data;
            } catch(e) {}
        }
    }

    function reloadThemes() {
        themesLoader.running = false;
        themesLoader.running = true;
    }

    Process {
        id: themesLoader
        running: false
        command: {
            let assetsPath = Caching.anserinDir ? (Caching.anserinDir + "/assets/themes") : "";
            let userPath = Caching.stateDir ? (Caching.stateDir + "/themes") : (Caching.home + "/.local/state/anserin/themes");
            let cachePath = Caching.getCacheDir("themes") + "/theme_sort_cache.json";
            let scriptPath = Caching.qsDir ? (Caching.qsDir + "/guide/theme/theme_sorter.py") : "theme_sorter.py";
            return ["python3", scriptPath, assetsPath, userPath, cachePath];
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let txt = this.text.trim();
                    if (txt === "" || txt === logic._lastPresetsStr) return;
                    logic._lastPresetsStr = txt;
                    let data = JSON.parse(txt);
                    if (Array.isArray(data) && data.length > 0) {
                        let sys = [];
                        let usr = [];
                        let len = data.length;
                        for (let i = 0; i < len; i++) {
                            let item = data[i];
                            if (item.isCustom === true || item.category === "user") {
                                usr.push(item);
                            } else {
                                sys.push(item);
                            }
                        }
                        if (logic.systemPresets.length === 0) {
                            logic.systemPresets = sys;
                        }
                        logic.userPresets = usr;
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: reloadThemesTimer
        interval: 150
        repeat: false
        onTriggered: logic.reloadThemes()
    }

    function saveCustomTheme(themeObj) {
        let userPath = Caching.stateDir ? (Caching.stateDir + "/themes") : (Caching.home + "/.local/state/anserin/themes");
        let sanitizeName = themeObj.name.replace(/[^a-zA-Z0-9_\- ]/g, "").trim();
        if (sanitizeName === "") sanitizeName = "CustomTheme";
        themeObj.name = sanitizeName;
        themeObj.isCustom = true;
        themeObj.category = "user";
        let jsonStr = JSON.stringify(themeObj, null, 2);
        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
        let filePath = userPath + "/" + sanitizeName + ".json";
        let cmd = "mkdir -p \"" + escapeBash(userPath) + "\" && echo \"" + escapeBash(jsonStr) + "\" > \"" + escapeBash(filePath) + "\"";
        Quickshell.execDetached(["bash", "-c", cmd]);

        let arr = logic.userPresets.filter(t => t.name !== themeObj.name);
        arr.push(themeObj);
        logic.userPresets = arr;
    }

    function deleteCustomTheme(themeName) {
        let userPath = Caching.stateDir ? (Caching.stateDir + "/themes") : (Caching.home + "/.local/state/anserin/themes");
        let sanitizeName = themeName.replace(/[^a-zA-Z0-9_\- ]/g, "").trim();
        let filePath = userPath + "/" + sanitizeName + ".json";
        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
        let cmd = "rm -f \"" + escapeBash(filePath) + "\"";
        Quickshell.execDetached(["bash", "-c", cmd]);

        logic.userPresets = logic.userPresets.filter(t => t.name !== themeName);
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            let ts = Config.getSetting("theme", logic.defaultThemeSettings);
            logic.currentFontFamily = ts.fontFamily !== undefined ? ts.fontFamily : ThemeBackend.fontFamily;
            logic.currentBorderRadius = ts.borderRadius !== undefined ? ts.borderRadius : ThemeBackend.borderRadius;
            logic.currentPreset = ts.activePreset !== undefined ? ts.activePreset : "Matugen";
            logic.useMatugen = ts.matugen !== undefined ? ts.matugen : true;
            logic.themeSettings = ts;

            let wpDir = Config.getSetting("wallpaperDir", "") || Config.getSetting("wallpaper_dir", "");
            if (wpDir && wpDir !== "") {
                logic.currentWallpaperDir = wpDir;
            }
        }
    }

    function updateWallpaperDirSetting() {
        Config.setSetting("wallpaperDir", logic.currentWallpaperDir);
    }

    function updateFontSetting() {
        let current = Config.getSetting("theme", logic.defaultThemeSettings);
        current.fontFamily = logic.currentFontFamily;
        Config.setSetting("theme", current);
    }

    function updateBorderRadiusSetting() {
        let current = Config.getSetting("theme", logic.defaultThemeSettings);
        current.borderRadius = logic.currentBorderRadius;
        Config.setSetting("theme", current);
        if (typeof ThemeBackend !== "undefined") {
            ThemeBackend.reloadColors();
        }
    }

    function applyPreset(modelData) {
        if (!modelData) return;

        let isMatugen = modelData.isMatugen === true;
        logic.currentPreset = modelData.name;
        logic.useMatugen = isMatugen;

        let current = Config.getSetting("theme", logic.defaultThemeSettings);
        current.activePreset = modelData.name;
        current.matugen = isMatugen;
        if (!isMatugen) {
            current.colors = modelData.colors;
        }

        Config.setSetting("theme", current);

        if (isMatugen) {
            if (typeof ThemeBackend !== "undefined") {
                let applied = (typeof ThemeBackend.applyMatugenColors === "function") && ThemeBackend.applyMatugenColors();
                if (!applied && logic.matugenColors && Object.keys(logic.matugenColors).length > 0) {
                    ThemeBackend.applyColorObject(logic.matugenColors.colors || logic.matugenColors);
                }
            }

            if (logic.currentWallpaperPath && logic.currentWallpaperPath !== "") {
                if (typeof Matugen !== "undefined" && typeof Matugen.generate === "function") {
                    Matugen.generate(logic.currentWallpaperPath, current.mode, current.schemeType);
                }
            } else if (typeof ThemeBackend !== "undefined") {
                ThemeBackend.reloadColors();
            }
        } else {
            if (typeof ThemeBackend !== "undefined" && typeof ThemeBackend.applyColorObject === "function") {
                ThemeBackend.applyColorObject(modelData.colors);
            }
            if (typeof Matugen !== "undefined" && typeof Matugen.generateFromStatic === "function") {
                Matugen.generateFromStatic(modelData.colors, current.mode);
            }
        }
    }

    property var currentPreviewLoader: null

    Component {
        id: dynamicFontLoaderComp
        FontLoader {}
    }

    Timer {
        id: fontLoadDelay
        interval: 100
        property string targetPath: ""
        onTriggered: {
            if (logic.currentPreviewLoader) {
                logic.currentPreviewLoader.destroy();
                logic.currentPreviewLoader = null;
            }

            if (targetPath !== "") {
                logic.currentPreviewLoader = dynamicFontLoaderComp.createObject(logic, { source: "file://" + targetPath });
            }

            logic.fontInstalled();
        }
    }

    Process {
        id: fontInstallProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim();
                if (out !== "") {
                    let idx = out.indexOf('|');
                    if (idx !== -1) {
                        let fName = out.substring(0, idx).trim();
                        let fPath = out.substring(idx + 1).trim();

                        let mainQmlPath = Caching.mainQml;
                        if (mainQmlPath !== "") {
                            let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); }
                            Quickshell.execDetached(["bash", "-c", "quickshell -p \"" + escapeBash(mainQmlPath) + "\" ipc call fonts rescan"]);
                        }

                        logic.currentFontFamily = fName;
                        logic.updateFontSetting();

                        if (logic.availableFonts.indexOf(fName) === -1) {
                            let arr = logic.availableFonts.slice();
                            arr.push(fName);
                            logic.availableFonts = arr;
                        }

                        fontLoadDelay.targetPath = fPath;
                        fontLoadDelay.start();
                    }
                }
            }
        }
    }

    function installFont(filePath, fileName) {
        if (!filePath || filePath.trim() === "" || !fileName || fileName.trim() === "") {
            return;
        }

        let userFontsPath = Caching.stateDir ? (Caching.stateDir + "/fonts") : (Caching.home + "/.local/state/anserin/fonts");
        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };

        let script = 
            "D=\"" + escapeBash(userFontsPath) + "\"; " +
            "B=\"" + escapeBash(fileName) + "\"; " +
            "S=\"" + escapeBash(filePath) + "\"; " +
            "mkdir -p \"$D\"; " +
            "if [ ! -f \"$D/$B\" ]; then cp \"$S\" \"$D/$B\"; fi; " +
            "F=\"$D/$B\"; " +
            "FAM=$(fc-query -f \"%{family}\" \"$F\" 2>/dev/null | cut -d, -f1); " +
            "if [ -z \"$FAM\" ]; then FAM=$(basename \"$F\" | sed 's/\\.[^.]*$//'); fi; " +
            "STL=$(fc-query -f \"%{style}\" \"$F\" 2>/dev/null | cut -d, -f1); " +
            "if [ -n \"$STL\" ] && [ \"$STL\" != \"Regular\" ]; then " +
                "echo \"$FAM $STL|$F\"; " +
            "else " +
                "echo \"$FAM|$F\"; " +
            "fi;";

        fontInstallProcess.command = ["bash", "-c", script];
        fontInstallProcess.running = true;
    }
}
