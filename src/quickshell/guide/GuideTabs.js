.pragma library

// The Settings categories, in order, for Control Center → Control (both its layouts).
// Pages with file "" are drawn as boards (controlcenter/board/pages); the others load their guide/ page.
var tabs = [
        { id: "Welcome", key: "welcome", name: "Welcome", icon: "󰋜", file: "", iconOffsetX: -1 },
        { id: "General", key: "general", name: "General", icon: "󰒓", file: "", iconOffsetX: 0 },
        { 
            id: "Display", 
            key: "display", 
            name: "Display", 
            icon: "󰃠", 
            file: "", 
            iconOffsetX: 0,
            subtabs: [
                { id: "DisplayGeneral", key: "display_general", name: "General", icon: "󰃠", file: "", iconOffsetX: 1 },
                { id: "DisplayPresets", key: "display_presets", name: "Presets", icon: "󰆓", file: "" }
            ]
        },
        { id: "Theme", key: "theme", name: "Theme", icon: "󰏘", file: "theme/ThemeTab.qml", iconOffsetX: 0,
            subtabs: [
                { id: "ThemeGeneral", key: "orbit", name: "Orbit", icon: "󰏘", file: "theme/ThemeTab.qml" },
                { id: "ThemePet", key: "pet", name: "Pet", icon: "\u{F03E9}", file: "" },
                { id: "ThemeStyle", key: "style", name: "Style", icon: "󰏘", file: "" },
                { id: "ThemeLockscreen", key: "theme_lockscreen", name: "Lock screen", icon: "󰌾", file: "" }
            ]
        },
        { id: "Panel", key: "panel", name: "Panel", icon: "󰕮", file: "", panelPage: true },
        { id: "Apps", key: "apps", name: "Apps", icon: "󰵆", file: "", iconOffsetX: 0 },
        { id: "Terminal", key: "terminal", name: "Terminal", icon: "󰆍", file: "", iconOffsetX: 0 },
        { id: "Alerts", key: "alerts", name: "Alerts", icon: "󰂚", file: "", iconOffsetX: 0 },
        { id: "Wellbeing", key: "wellbeing", name: "Wellbeing", icon: "󰄉", file: "wellbeing/DigitalWellbeingTab.qml", iconOffsetX: 0 },        
        { id: "Idle", key: "idle", name: "Idle", icon: "󰒲", file: "", iconOffsetX: 0 },
        { id: "Update", key: "update", name: "Update", icon: "󰚰", file: "UpdateTab.qml", iconOffsetX: 0 }
    ];
