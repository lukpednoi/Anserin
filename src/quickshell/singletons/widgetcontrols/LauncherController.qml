pragma Singleton
import "../../reusables"

PopupController {
    property var bars: ({})

    function registerBar(name, window) {
        let next = Object.assign({}, bars);
        next[name] = window;
        bars = next;
    }

    function unregisterBar(name, window) {
        if (bars[name] !== window) return;
        let next = Object.assign({}, bars);
        delete next[name];
        bars = next;
    }
}
