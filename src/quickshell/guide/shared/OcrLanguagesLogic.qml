import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// The languages text recognition (the screenshot tool's OCR, src/scripts/ocr.sh) can read. English comes with
// tesseract; others are downloaded on demand (tessdata_fast, into ~/.local/state/anserin/tessdata). Used by the
// Settings page (guide/general/GeneralTab.qml) and the Control Center's board (GeneralPage.qml).
Item {
    id: logic
    readonly property string script: Caching.anserinDir + "/scripts/ocr.sh"
    readonly property var languages: [
        { code: "eng", name: "English" }, { code: "tha", name: "Thai" }, { code: "jpn", name: "Japanese" },
        { code: "kor", name: "Korean" }, { code: "chi_sim", name: "Chinese (Simplified)" }, { code: "chi_tra", name: "Chinese (Traditional)" },
        { code: "vie", name: "Vietnamese" }, { code: "ind", name: "Indonesian" }, { code: "hin", name: "Hindi" },
        { code: "ara", name: "Arabic" }, { code: "rus", name: "Russian" }, { code: "deu", name: "German" },
        { code: "fra", name: "French" }, { code: "spa", name: "Spanish" }, { code: "por", name: "Portuguese" },
        { code: "ita", name: "Italian" }
    ]
    property var installed: []
    property var queue: []
    property string busyCode: ""
    property string error: ""
    readonly property bool busy: busyCode !== ""
    readonly property bool available: installed.length > 0

    function refresh() { if (!lister.running) lister.running = true; }
    // apply a whole selection: download what was added, remove what was taken away (English always stays)
    function setLanguages(codes) {
        codes = Array.prototype.slice.call(codes || []);   // a Qt list from a signal is not a JS array
        let want = codes.indexOf("eng") >= 0 ? codes.slice() : ["eng"].concat(codes);
        let jobs = [];
        for (const l of languages) {
            const has = installed.indexOf(l.code) >= 0, wanted = want.indexOf(l.code) >= 0;
            if (wanted && !has) jobs.push(["install", l.code]);
            else if (!wanted && has && l.code !== "eng") jobs.push(["remove", l.code]);
        }
        queue = queue.concat(jobs);
        next();
    }
    function next() {
        if (worker.running || queue.length === 0) return;
        const job = queue[0];
        queue = queue.slice(1);
        busyCode = job[1];
        error = "";
        worker.command = ["bash", script, job[0], job[1]];
        worker.running = true;
    }
    function nameOf(code) { const l = languages.find(x => x.code === code); return l ? l.name : code; }

    Process {
        id: lister
        command: ["bash", logic.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: { try { logic.installed = JSON.parse(text); } catch (e) { logic.installed = []; } }
        }
    }
    Process {
        id: worker
        onExited: code => {
            if (code !== 0) logic.error = "Could not download " + logic.nameOf(logic.busyCode) + ". Check the connection and try again.";
            logic.busyCode = "";
            logic.refresh();
            logic.next();
        }
    }
    Component.onCompleted: refresh()
}
