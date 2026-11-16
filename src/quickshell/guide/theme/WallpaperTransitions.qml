import "../../"
import "../../reusables"
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property var rootObj
    Layout.fillWidth: true
    spacing: s(12)
    function s(value) {
        return rootObj.s(value);
    }
    readonly property string selectedLayout: Config.getSetting("theme.wallpaperStyle", "original") === "grid" ? "grid" : "original"

    readonly property var saved: Wallpaper.transitionSettings()
    readonly property int effect: Math.max(0, Wallpaper.transitionIds.indexOf(saved.pool[0]))
    readonly property string effectId: Wallpaper.transitionIds[effect]
    readonly property var effectSettings: saved.effects[effectId]

    // Controls update themselves on clicks; wait for effect-dependent bindings to settle.
    onSavedChanged: Qt.callLater(syncControls)
    function syncControls() {
        effectSelector.currentIndex = effect;
        durationSelector.value = effectSettings.duration;
        direction.currentIndex = Math.max(0, direction.values.indexOf(effectSettings[direction.setting]));
    }

    function select(index) {
        let next = Wallpaper.transitionSettings();
        next.mode = "custom";
        next.pool = [Wallpaper.transitionIds[index]];
        Config.setSetting("wallpaperTransition", next);
        play();
    }

    function update(key, value) {
        let next = Wallpaper.transitionSettings();
        next.effects[effectId][key] = value;
        Config.setSetting("wallpaperTransition", next);
        play();
    }

    function play() { transitionPreview.play(); }
    objectName: "wallpaper-transitions"
    // Layout: two previews side by side (pick one)
    Text {
        text: "Layout"
        color: ThemeBackend.text
        font { family: ThemeBackend.fontFamily; pixelSize: root.s(14); bold: true }
    }
    WallpaperLayoutCards { rootObj: root.rootObj }
    Text {
        text: "Transition"
        color: ThemeBackend.text
        font { family: ThemeBackend.fontFamily; pixelSize: root.s(14); bold: true }
    }
    TransitionPreview { id: transitionPreview; rootObj: root.rootObj }

    // Wraps onto a second line in the narrower Control Center.
    Flow {
        objectName: "wallpaper-transition-controls"
        Layout.fillWidth: true
        spacing: root.s(8)

        Dropdown {
            id: effectSelector
            objectName: "wallpaper-transition-type"
            implicitWidth: root.s(180)
            implicitHeight: root.s(32)
            options: ["Fade", "Wipe", "Circle", "Swipe", "Paint"]
            currentIndex: root.effect
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface0
            hoverColor: ThemeBackend.surface1
            dropdownColor: ThemeBackend.surface0
            borderColor: ThemeBackend.surface2
            textColor: ThemeBackend.text
            activeTextColor: ThemeBackend.crust
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: root.s(11)
            onSelected: index => root.select(index)
        }

        NumberSelector {
            id: durationSelector
            objectName: "wallpaper-transition-duration"
            implicitWidth: root.s(160)
            implicitHeight: root.s(32)
            from: 100
            to: 10000
            stepSize: 100
            suffix: " ms"
            value: root.effectSettings.duration
            baseColor: ThemeBackend.surface0
            accentColor: ThemeBackend.mauve
            buttonColor: ThemeBackend.surface1
            buttonTextColor: ThemeBackend.text
            textColor: ThemeBackend.text
            subTextColor: ThemeBackend.subtext0
            borderColor: ThemeBackend.surface2
            cornerRadius: ThemeBackend.borderRadius
            fontFamily: ThemeBackend.fontFamily
            fontPixelSize: root.s(11)
            onTriggered: root.update("duration", value)
        }

        Dropdown {
            id: direction
            objectName: "wallpaper-transition-direction"
            readonly property string setting: root.effect === 1 ? "orientation" : root.effect === 2 ? "origin" : "direction"

            readonly property var values: root.effect === 1 ? ["random", "horizontal", "vertical"] : root.effect === 2 ? ["random", "center"] : ["random"].concat(Wallpaper.swipeDirections)

            // Fade and Paint have no direction
            visible: root.effect !== 0 && root.effect !== 4
            implicitWidth: root.s(200)
            implicitHeight: root.s(32)
            options: root.effect === 1 ? ["Random", "Horizontal", "Vertical"] : root.effect === 2 ? ["Random", "Center"] : ["Random", "Left", "Right", "Top", "Bottom", "Top left", "Top right", "Bottom left", "Bottom right"]
            currentIndex: Math.max(0, values.indexOf(root.effectSettings[setting]))
            accentColor: ThemeBackend.mauve
            baseColor: ThemeBackend.surface0
            hoverColor: ThemeBackend.surface1
            dropdownColor: ThemeBackend.surface0
            borderColor: ThemeBackend.surface2
            textColor: ThemeBackend.text
            activeTextColor: ThemeBackend.crust
            cornerRadius: ThemeBackend.borderRadius
            fontPixelSize: root.s(11)
            onSelected: index => {
                root.update(setting, values[index]);
            }
        }

        ClickButton {
            objectName: "wallpaper-transition-play"
            implicitHeight: root.s(32)
            buttonText: "Preview"
            accentColor: ThemeBackend.mauve
            textColor: ThemeBackend.crust
            onClicked: root.play()
        }
    }


}
