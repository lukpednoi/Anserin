import "../../"
import QtQuick
import Quickshell.Io

// The real login-screen theme, scaled into a card, shown as a still picture of it. Running the themes live (two cards
// at 1280×720 with their animations) cost the whole window about a quarter of its frames, so a theme is run only to
// take its picture: once it has settled the picture is saved in the runtime folder (named by the theme's own file, so
// a change of colours makes a new one) and the theme is let go. Later visits show the saved picture straight away.
Item {
    id: root

    required property string style
    property bool active: visible
    property var scene: null
    property string error: ""
    readonly property string directory: Caching.anserinDir + "/../config/sddm/themes/" + (style === "new" ? "material-you-new" : "material-you")
    property string stillPath: ""          // the saved picture for this theme as it is now

    function release() {
        if (scene) {
            scene.destroy();
            scene = null;
        }
    }

    function load() {
        if (!active || !theme.loaded || scene || still.status === Image.Ready)
            return ;

        try {
            let source = theme.text().replace("import SddmComponents 2.0", "").replace("Screen.height / 768", "root.height / 768");
            source = source.replace('userModel.lastUser || "USER"', '"User"').replace('userModel.lastUser || "User"', '"User"');
            scene = Qt.createQmlObject(source, root, "file://" + directory + "/Preview.qml");
            scene.width = 1280;
            scene.height = 720;
            error = "";
            settle.restart();
        } catch (failure) {
            error = String(failure);
            console.warn("SDDM preview: " + error);
        }
    }

    // the picture, saved, then the theme let go (it keeps running if the picture cannot be taken)
    function snap() {
        if (!scene || stillPath === "") return;
        const target = stillPath;
        root.grabToImage(result => {
            if (!result.saveToFile(target)) return;
            still.source = "";
            still.source = "file://" + target;
            root.release();
        });
    }
    Timer { id: settle; interval: 1500; onTriggered: root.snap() }

    enabled: false
    onActiveChanged: active ? load() : release()
    Component.onDestruction: release()

    Image {
        id: still
        anchors.fill: parent
        visible: !root.scene && status === Image.Ready
        cache: false
        asynchronous: true
        // no saved picture for this theme yet: run it once to take one
        onStatusChanged: if (status === Image.Error) root.load()
    }

    FileView {
        id: theme

        path: root.active ? root.directory + "/Main.qml" : ""
        onLoaded: {
            root.stillPath = Caching.getRunDir("sddm") + "/" + root.style + "-" + Qt.md5(theme.text()) + ".png";
            if (still.source.toString() !== "file://" + root.stillPath) still.source = "file://" + root.stillPath;
            else if (still.status !== Image.Ready) root.load();
        }
    }

}
