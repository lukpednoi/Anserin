import QtQuick

// Lazy per-page router: creates ONLY the single active page asynchronously with `app` already bound,
// and unloads it immediately when switching pages or closing Control.
Item {
    id: host
    property var app: null
    property bool active: true
    property string pageId: "Welcome"

    readonly property var pageFiles: ({
        "Welcome":         "pages/WelcomePage.qml",
        "General":         "pages/GeneralPage.qml",
        "DisplayGeneral":  "pages/DisplayGeneralPage.qml",
        "DisplayPresets":  "pages/DisplayPresetsPage.qml",
        "ThemeGeneral":    "pages/ThemeGeneralPage.qml",
        "ThemePet":        "pages/ThemePetPage.qml",
        "ThemeStyle":      "pages/ThemeStylePage.qml",
        "ThemeLockscreen": "pages/ThemeLockscreenPage.qml",
        "Panel":           "pages/PanelPage.qml",
        "Apps":            "pages/AppsPage.qml",
        "Terminal":        "pages/TerminalPage.qml",
        "Alerts":          "pages/AlertsPage.qml",
        "Idle":            "pages/IdlePage.qml",
        "Update":          "pages/UpdatePage.qml"
    })
    readonly property string pageFile: pageFiles[pageId] || ""

    width: parent ? parent.width : 500
    implicitHeight: pageLoader.item ? pageLoader.item.implicitHeight : 0
    height: implicitHeight

    function syncPage() {
        if (!host.active || !host.app || host.pageFile === "") {
            pageLoader.source = "";
            return;
        }
        pageLoader.setSource(Qt.resolvedUrl(host.pageFile), { app: host.app });
    }

    onActiveChanged: syncPage()
    onAppChanged: syncPage()
    onPageFileChanged: syncPage()
    Component.onCompleted: syncPage()

    Loader {
        id: pageLoader
        width: host.width
        asynchronous: true
        onLoaded: if (item) item.width = Qt.binding(() => host.width)
    }
}
