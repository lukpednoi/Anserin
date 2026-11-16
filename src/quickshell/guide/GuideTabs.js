.pragma library

// The Settings categories, in order. Shared by the Settings window (GuidePopup)
// and the Control Center's Control tab, so both always list the same pages.
var tabs = [
        { id: "Welcome", key: "welcome", name: "Welcome", icon: "󰋜", file: "AboutTab.qml", iconOffsetX: -1 },
        { id: "General", key: "general", name: "General", icon: "󰒓", file: "general/GeneralTab.qml", iconOffsetX: 0 },
        { 
            id: "Display", 
            key: "display", 
            name: "Display", 
            icon: "󰃠", 
            file: "display/DisplayMainTab.qml", 
            iconOffsetX: 0,
            subtabs: [
                { id: "DisplayGeneral", key: "display_general", name: "General", icon: "󰃠", file: "display/DisplayMainTab.qml", iconOffsetX: 1 },
                { id: "DisplayPresets", key: "display_presets", name: "Presets", icon: "󰆓", file: "display/DisplayPresetsTab.qml" }
            ]
        },
        { id: "Theme", key: "theme", name: "Theme", icon: "󰏘", file: "theme/ThemeTab.qml", iconOffsetX: 0,
            subtabs: [
                { id: "ThemeGeneral", key: "orbit", name: "Orbit", icon: "󰏘", file: "theme/ThemeTab.qml" },
                { id: "ThemeMusic", key: "music", name: "Music", icon: "󰎈", file: "theme/MusicTab.qml" },
                { id: "ThemeStyle", key: "style", name: "Style", icon: "󰏘", file: "theme/ThemeStyleTab.qml" },
                { id: "ThemeLockscreen", key: "theme_lockscreen", name: "Lock screen", icon: "󰌾", file: "display/DisplayLockscreenTab.qml" }
            ]
        },
        { 
            id: "Bar", 
            key: "bar", 
            name: "Bar", 
            icon: "󰹑", 
            file: "bar/BarGeneralTab.qml", 
            iconOffsetX: -2,
            subtabs: [
                { id: "BarGeneral", key: "bar_general", name: "General", icon: "󰒓", file: "bar/BarGeneralTab.qml", iconOffsetX: 1 },
                { id: "BarModules", key: "bar_modules", name: "Modules", icon: "󰮯", file: "bar/BarModulesTab.qml", iconOffsetX: 0 }
            ]
        },
        { id: "Apps", key: "apps", name: "Apps", icon: "󰵆", file: "AppsTab.qml", iconOffsetX: 0 },
        { id: "Terminal", key: "terminal", name: "Terminal", icon: "󰆍", file: "TerminalTab.qml", iconOffsetX: 0 },
        { id: "Alerts", key: "alerts", name: "Alerts", icon: "󰂚", file: "AlertsTab.qml", iconOffsetX: 0 },
        { id: "Wellbeing", key: "wellbeing", name: "Wellbeing", icon: "󰄉", file: "wellbeing/DigitalWellbeingTab.qml", iconOffsetX: 0 },        
        { id: "Idle", key: "idle", name: "Idle", icon: "󰒲", file: "IdleTab.qml", iconOffsetX: 0 },
        { id: "Update", key: "update", name: "Update", icon: "󰚰", file: "UpdateTab.qml", iconOffsetX: 0 }
    ];
