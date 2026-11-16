import QtQuick
import "../../../"
import "../../../guide/shared"
import ".."

// Idle as a board, through the Settings page's own logic (guide/shared/IdleLogic.qml): the idle system and
// keep-awake (how it starts: on a timer of so many minutes, or until switched off; used by every Keep Awake
// button), then the built-in steps (dim, lock, display off, suspend), each with only its timeout. Custom steps,
// inhibitors, warnings and commands stay in the Settings window. "Order" marks a step out of order.
BoardPage {
    id: page
    extras: [ IdleLogic { id: il; rootObj: page.rootObj } ]

    BoardCard {
        title: "Idle"; icon: "󰒲"; accent: page.accent
        BoardCell { kind: "toggle"; icon: "󰒲"; title: I18n.t("guide.idle.enabled.title", "Enable Idle System")
                    value: il.idleEnabled; onPicked: (v) => il.updateRootSetting("enabled", v) }
        BoardCell { kind: "toggle"; icon: "󰅶"; title: I18n.t("guide.idle.manual_inhibit.title", "Do Not Disturb (Keep Awake)"); hidden: !il.idleEnabled
                    value: Caffeine.enabled; onPicked: (v) => v ? Caffeine.start() : Caffeine.stop() }
        BoardCell { kind: "seg"; icon: "󰅶"; title: "Keep Awake for"; hidden: !il.idleEnabled
                    options: ["Timer", "Forever"]; values: ["timer", "forever"]
                    value: Caffeine.foreverMode ? "forever" : "timer"; onPicked: (v) => il.updateRootSetting("keepAwakeMode", v) }
        BoardCell { kind: "stepper"; icon: "󰔛"; title: "Timer"; hidden: !il.idleEnabled || Caffeine.foreverMode
                    from: 5; to: 480; step: 5; suffix: " min"
                    value: Caffeine.timerMinutes; onPicked: (v) => il.updateRootSetting("keepAwakeMinutes", Math.round(v)) }
    }

    BoardCard {
        title: "Timeout"; icon: "󰔛"; accent: page.accent
        visible: il.idleEnabled
        Repeater {
            model: il.idleEnabled ? il.actionIdsList.filter(a => !il.isCustomAction(typeof a === "string" ? a : (a ? (a.id || "") : ""))) : []
            BoardCell {
                required property var modelData
                readonly property string actId: typeof modelData === "string" ? modelData : (modelData ? (modelData.id || "") : "")
                readonly property var act: il.getActionData(actId)
                readonly property bool valid: il.isActionPipelineValid(act)
                readonly property bool on: act && act.enabled !== undefined ? act.enabled : true
                kind: "stepper"; from: 10; to: 7200; step: 10; suffix: "s"
                icon: actId === "dim" ? "󰃛" : actId === "lock" ? "󰌾" : actId === "dpms" ? "󰍹" : "󰒲"
                title: il.getActionTitle(act, actId) + (!valid && on ? "  ·  " + I18n.t("guide.idle.order_violation", "Order") : "")
                available: on
                value: il.getActionTimeout(act)
                onPicked: (v) => il.updateActionProp(actId, false, "timeout", Math.round(v))
            }
        }
    }
}
