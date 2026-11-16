#!/usr/bin/env bash

EDIT_MODE=false
FULL_MODE=false
RECORD_MODE=false
SCAN_QR_MODE=false
GEOMETRY=""
DESK_VOL="1.0"
DESK_MUTE="false"
MIC_VOL="1.0"
MIC_MUTE="false"
MIC_DEVICE=""
MIC_NS="true"
VIDEO_BACKEND="gpu-screen-recorder"
TARGET_MON=""
FORCE_MODE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --edit) EDIT_MODE=true; shift ;;
        --full) FULL_MODE=true; shift ;;
        --record) RECORD_MODE=true; shift ;;
        --scan-qr) SCAN_QR_MODE=true; shift ;;
        --geometry) GEOMETRY="$2"; shift 2 ;;
        --desk-vol) DESK_VOL="$2"; shift 2 ;;
        --desk-mute) DESK_MUTE="$2"; shift 2 ;;
        --mic-vol) MIC_VOL="$2"; shift 2 ;;
        --mic-mute) MIC_MUTE="$2"; shift 2 ;;
        --mic-dev) MIC_DEVICE="$2"; shift 2 ;;
        --mic-ns) MIC_NS="$2"; shift 2 ;;
        --backend) VIDEO_BACKEND="$2"; shift 2 ;;
        --monitor) TARGET_MON="$2"; shift 2 ;;
        --mode) FORCE_MODE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# A volume of 0 means that source is left out of the recording.
vol_is_zero() { [ -n "$1" ] && awk -v v="$1" 'BEGIN { exit !(v + 0 <= 0) }'; }
vol_is_zero "$DESK_VOL" && DESK_MUTE="true"
vol_is_zero "$MIC_VOL" && MIC_MUTE="true"

# Points MIC_REC_SOURCE at the mic to record: with MIC_NS, a WebRTC noise-suppressed copy that lives only
# while recording (its module joins REC_MODS, unloaded when the recording stops); otherwise the mic itself.
REC_MODS=()
use_mic_source() {
    MIC_REC_SOURCE="$1"
    [ "$MIC_NS" = "true" ] && [ "$1" != "default_input" ] || return 0
    local name="qs_rec_ns_$$" sink id
    sink=$(pactl get-default-sink 2>/dev/null)
    id=$(pactl load-module module-echo-cancel aec_method=webrtc source_master="$1" ${sink:+sink_master="$sink"} \
        source_name="$name" sink_name="${name}_sink" use_master_format=1 \
        'aec_args="webrtc.noise_suppression=true webrtc.high_pass_filter=true webrtc.gain_control=false"' \
        'source_properties="priority.session=0"' 'sink_properties="priority.session=0"' 2>/dev/null)
    [ -n "$id" ] || return 0
    REC_MODS+=("$id")
    MIC_REC_SOURCE="$name"
}

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/caching.sh"
source "$SCRIPT_DIR/i18n.sh"
qs_ensure_cache "screenshot"
qs_ensure_cache "recording"

CACHE_DIR="$QS_CACHE_RECORDING"
source "$SCRIPT_DIR/config.sh"
# the folder chosen in Settings (General → Screenshot folder); Pictures/Screenshots when unset
SAVE_DIR="$(get_setting "screenshotDir" "")"
[ -z "$SAVE_DIR" ] && SAVE_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
# the file manager chosen in Control → General (general.fileManager), as singletons/system/FileManager.qml opens it
open_folder() {
    local fm
    fm="$(get_setting "general" '{}' | jq -r '.fileManager // empty' 2>/dev/null)"
    case "$fm" in dolphin|ski) command -v "$fm" >/dev/null 2>&1 || fm="" ;; *) fm="" ;; esac
    [ -z "$fm" ] && for b in dolphin ski; do command -v "$b" >/dev/null 2>&1 && { fm="$b"; break; }; done
    "${fm:-xdg-open}" "$1"
}
RECORD_DIR="${XDG_VIDEOS_DIR:-$HOME/Videos}/Recordings"
mkdir -p "$SAVE_DIR" "$RECORD_DIR"

REQUIRED_CMDS=("grim" "satty" "wl-copy" "pactl" "quickshell" "zbarimg" "python3")
MISSING_CMDS=()
for cmd in "${REQUIRED_CMDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        MISSING_CMDS+=("$cmd")
    fi
done

if [ "$RECORD_MODE" = true ]; then
    if ! command -v "$VIDEO_BACKEND" &> /dev/null; then
        MISSING_CMDS+=("$VIDEO_BACKEND")
    fi
fi

if [ ${#MISSING_CMDS[@]} -ne 0 ]; then
    notif_app="$(t "screenshot.notifications.system_app_name")"
    notif_title="$(t "screenshot.notifications.missing_deps_title")"
    notif_body="$(t "screenshot.notifications.missing_deps_body" "cmds=${MISSING_CMDS[*]}")"
    notify-send -u critical -a "$notif_app" "$notif_title" "$notif_body"
    exit 1
fi

if [ -f "$CACHE_DIR/rec_pid" ]; then
    REC_PID=$(cat "$CACHE_DIR/rec_pid" 2>/dev/null)
    FINAL_FILE=$(cat "$CACHE_DIR/final_file" 2>/dev/null)
    
    if mo_pid_valid "$CACHE_DIR/rec_pid"; then
        [ -f "$CACHE_DIR/processing.lock" ] && exit 0
        touch "$CACHE_DIR/processing.lock"
        
        mo_pid_signal "$CACHE_DIR/rec_pid" INT
        timeout=30
        while mo_pid_valid "$CACHE_DIR/rec_pid" && [ $timeout -gt 0 ]; do
            sleep 0.1
            timeout=$((timeout - 1))
        done
        mo_pid_signal "$CACHE_DIR/rec_pid" KILL
        
        if [ -f "$FINAL_FILE" ]; then
            (
                VIDEO_THUMB="$QS_RUN_SCREENSHOT/thumb_$$.png"
                if command -v ffmpeg &> /dev/null; then
                    ffmpeg -ss 00:00:00.500 -i "$FINAL_FILE" -vframes 1 "$VIDEO_THUMB" -y &>/dev/null
                    NOTIF_ICON="$VIDEO_THUMB"
                else
                    NOTIF_ICON=""
                fi
                notif_app="$(t "screenshot.notifications.recorder_app_name")"
                notif_action="$(t "screenshot.notifications.open_folder")"
                notif_title="$(t "screenshot.notifications.recording_saved_title")"
                notif_body="$(t "screenshot.notifications.recording_saved_body" "file=$(basename "$FINAL_FILE")" "folder=$RECORD_DIR")"
                ACTION=$(notify-send -a "$notif_app" -i "$NOTIF_ICON" -h "string:image-path:$NOTIF_ICON" -A "default=$notif_action" "$notif_title" "$notif_body")
                rm -f "$VIDEO_THUMB"
                [ "$ACTION" = "default" ] && open_folder "$RECORD_DIR"
            ) &
        else
            notif_app="$(t "screenshot.notifications.recorder_app_name")"
            notif_title="$(t "screenshot.notifications.recording_error_title")"
            notif_body="$(t "screenshot.notifications.recording_error_body")"
            notify-send -a "$notif_app" "$notif_title" "$notif_body"
        fi
        if [ -f "$CACHE_DIR/rec_modules" ]; then
            while read -r mod_id; do
                [ -n "$mod_id" ] && pactl unload-module "$mod_id" 2>/dev/null
            done < "$CACHE_DIR/rec_modules"
            rm -f "$CACHE_DIR/rec_modules"
        fi
        rm -f "$CACHE_DIR/processing.lock" "$CACHE_DIR/rec_pid" "$CACHE_DIR/final_file" "$CACHE_DIR/rec_start_epoch"
        exit 0
    else
        if [ -f "$CACHE_DIR/rec_modules" ]; then
            while read -r mod_id; do
                [ -n "$mod_id" ] && pactl unload-module "$mod_id" 2>/dev/null
            done < "$CACHE_DIR/rec_modules"
            rm -f "$CACHE_DIR/rec_modules"
        fi
        rm -f "$CACHE_DIR/processing.lock" "$CACHE_DIR/rec_pid" "$CACHE_DIR/final_file" "$CACHE_DIR/rec_start_epoch"
    fi
fi

get_active_monitor() {
    local mon=""
    if command -v hyprctl &>/dev/null; then
        mon=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null)
        if [ -z "$mon" ] || [ "$mon" = "null" ]; then
            mon=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.monitor // empty' 2>/dev/null)
        fi
    fi
    if [ -z "$mon" ] && command -v niri &>/dev/null; then
        mon=$(niri msg -j focused-output 2>/dev/null | jq -r '.name // empty' 2>/dev/null)
        if [ -z "$mon" ] || [ "$mon" = "null" ]; then
            mon=$(niri msg -j outputs 2>/dev/null | jq -r 'to_entries[]? | select(.value.is_focused == true) | .value.name // .key' 2>/dev/null)
        fi
    fi
    if [ -z "$mon" ] && command -v swaymsg &>/dev/null; then
        mon=$(swaymsg -t get_outputs 2>/dev/null | jq -r '.[] | select(.focused == true) | .name' 2>/dev/null)
    fi
    if [ -z "$mon" ] || [ "$mon" = "null" ]; then
        if [ -f "$SCRIPT_DIR/monitors_detect.sh" ]; then
            mon=$(bash "$SCRIPT_DIR/monitors_detect.sh" 2>/dev/null | head -n 1)
        fi
    fi
    echo "$mon"
}

if [ -z "$TARGET_MON" ]; then
    TARGET_MON=$(get_active_monitor)
fi

if [ "$SCAN_QR_MODE" = false ] && [ "$RECORD_MODE" = false ] && [ "$FULL_MODE" = false ] && [ -z "$GEOMETRY" ]; then
    PREFS="$QS_STATE_SCREENSHOT/audio_prefs"
    if [ -f "$PREFS" ]; then
        IFS=',' read -r QS_DESK_VOL QS_DESK_MUTE QS_MIC_VOL QS_MIC_MUTE QS_MIC_DEV < "$PREFS"
    else
        QS_DESK_VOL="1.0"; QS_DESK_MUTE="false"; QS_MIC_VOL="1.0"; QS_MIC_MUTE="false"; QS_MIC_DEV=""
    fi

    CACHE_FILE="$QS_CACHE_SCREENSHOT/geometry"
    VIDEO_CACHE_FILE="$QS_CACHE_SCREENSHOT/geometry_video"
    MODE_CACHE_FILE="$QS_CACHE_SCREENSHOT/video_mode"
    BACKEND_CACHE_FILE="$QS_CACHE_SCREENSHOT/video_backend"
    [ -f "$CACHE_FILE" ] && QS_CACHED_GEOM=$(cat "$CACHE_FILE") || QS_CACHED_GEOM=""
    [ -f "$VIDEO_CACHE_FILE" ] && QS_CACHED_VIDEO_GEOM=$(cat "$VIDEO_CACHE_FILE") || QS_CACHED_VIDEO_GEOM=""
    [ -f "$MODE_CACHE_FILE" ] && QS_CACHED_MODE=$(cat "$MODE_CACHE_FILE") || QS_CACHED_MODE="false"
    [ -f "$BACKEND_CACHE_FILE" ] && QS_CACHED_BACKEND=$(cat "$BACKEND_CACHE_FILE") || QS_CACHED_BACKEND="gpu-screen-recorder"

    # A button that names the mode opens the overlay locked to it, without the photo/video switch.
    case "$FORCE_MODE" in
        video) QS_CACHED_MODE="video-only" ;;
        photo) QS_CACHED_MODE="photo-only" ;;
    esac

    if [ "$EDIT_MODE" = true ]; then
        QS_CACHED_MODE="false"
    fi

    if [ "$QS_CACHED_MODE" = "true" ] || [ "$QS_CACHED_MODE" = "video-only" ]; then
        FREEZE_IMG=""
    else
        FREEZE_IMG="$QS_RUN_SCREENSHOT/freeze_$$.png"
        if [ -n "$TARGET_MON" ]; then
            grim -o "$TARGET_MON" -l 0 "$FREEZE_IMG" 2>/dev/null || grim -l 0 "$FREEZE_IMG"
        else
            grim -l 0 "$FREEZE_IMG"
        fi
    fi

    QS_AUDIO_PREFS="${QS_DESK_VOL},${QS_DESK_MUTE},${QS_MIC_VOL},${QS_MIC_MUTE},${QS_MIC_DEV}"

    exec quickshell ${MAIN_QML:+-p "$MAIN_QML"} ipc call screenshotOverlay toggle "$FREEZE_IMG" "$EDIT_MODE" "$QS_AUDIO_PREFS" "$QS_CACHED_GEOM" "$QS_CACHED_VIDEO_GEOM" "$QS_CACHED_MODE" "$QS_CACHED_BACKEND" "$TARGET_MON"
fi

if [ "$SCAN_QR_MODE" = true ]; then
    RES_FILE="$QS_RUN_SCREENSHOT/qr_result"
    export DEBUG_LOG="$QS_LOG_DIR/qr_debug.log"
    rm -f "$RES_FILE" "$DEBUG_LOG"
    
    TMP_IMG="$QS_RUN_SCREENSHOT/qr_temp_$$.png"
    grim -l 0 -g "$GEOMETRY" "$TMP_IMG"
    
    export XML_OUT=$(zbarimg --xml -q "$TMP_IMG" 2>>"$DEBUG_LOG")
    if [ -n "$XML_OUT" ]; then
        python3 << 'EOF' > "$RES_FILE"
import os, sys, logging, re
import xml.etree.ElementTree as ET
debug_log = os.environ.get("DEBUG_LOG", os.path.join(os.environ["QS_RUN_DIR"], "qs_qr_debug.log"))
logging.basicConfig(filename=debug_log, level=logging.DEBUG, format="%(asctime)s - %(levelname)s - %(message)s")
raw_xml = os.environ.get("XML_OUT", "")
if not raw_xml.strip():
    print("0,0,0,0|||ERROR: Empty output from zbarimg. See log.")
    sys.exit(0)
try:
    xml_clean = re.sub(r'\sxmlns="[^"]+"', '', raw_xml)
    xml_clean = re.sub(r"\sxmlns='[^']+'", '', xml_clean)
    tree = ET.fromstring(xml_clean)
    found_any = False
    for elem in tree.iter():
        if elem.tag.endswith('symbol'):
            found_any = True
            data_text = ''
            min_x, min_y, max_x, max_y = float('inf'), float('inf'), -float('inf'), -float('inf')
            for child in elem:
                if child.tag.endswith('data'):
                    data_text = child.text if child.text else ''
                elif child.tag.endswith('polygon'):
                    pts_str = child.get('points', '')
                    if pts_str:
                        pt_pairs = pts_str.replace('+', '').split(' ')
                        for pair in pt_pairs:
                            if ',' in pair:
                                try:
                                    x_str, y_str = pair.split(',')
                                    x, y = int(x_str), int(y_str)
                                    min_x = min(min_x, x)
                                    max_x = max(max_x, x)
                                    min_y = min(min_y, y)
                                    max_y = max(max_y, y)
                                except ValueError:
                                    pass
            if min_x == float('inf'): min_x, min_y, max_x, max_y = 0, 0, 0, 0
            w, h = max_x - min_x, max_y - min_y
            encoded = data_text.replace('\\', '\\\\').replace('\n', '\\n').replace('\r', '')
            print(f"{int(min_x)},{int(min_y)},{int(w)},{int(h)}|||{encoded}")
    if not found_any: print("0,0,0,0|||NOT_FOUND")
except Exception as e:
    print(f"0,0,0,0|||ERROR: XML Parse failure: {e}. Check log.")
EOF
    else
        echo -e "0,0,0,0|||NOT_FOUND" > "$RES_FILE"
    fi
    rm -f "$TMP_IMG"
    exit 0
fi

time=$(date +'%Y-%m-%d-%H%M%S')
FILENAME="$SAVE_DIR/Screenshot_$time.png"
VID_FILENAME="$RECORD_DIR/Recording_$time.mp4"

if [ "$FULL_MODE" = true ] || [ -n "$GEOMETRY" ]; then
    if [ "$RECORD_MODE" = true ]; then
        if [ "$VIDEO_BACKEND" = "wf-recorder" ]; then
            WF_ARGS=(-f "$VID_FILENAME")
            if [ -n "$GEOMETRY" ]; then
                WF_ARGS+=(-g "$GEOMETRY")
            elif [ -n "$TARGET_MON" ]; then
                WF_ARGS+=(-o "$TARGET_MON")
            fi

            if [ "$DESK_MUTE" != "true" ] && [ "$MIC_MUTE" != "true" ]; then
                DESK_SINK=$(pactl get-default-sink 2>/dev/null)
                DESK_SOURCE="${DESK_SINK:+$DESK_SINK.monitor}"
                if [ -z "$DESK_SOURCE" ]; then
                    DESK_SOURCE="default_output"
                fi

                if [ -n "$MIC_DEVICE" ] && [ "$MIC_DEVICE" != "null" ]; then
                    MIC_SOURCE="$MIC_DEVICE"
                else
                    MIC_SOURCE=$(pactl get-default-source 2>/dev/null)
                fi
                if [ -z "$MIC_SOURCE" ]; then
                    MIC_SOURCE="default_input"
                fi
                use_mic_source "$MIC_SOURCE"
                MIC_SOURCE="$MIC_REC_SOURCE"

                NULL_SINK="qs_rec_mix_$$"
                M_NULL=$(pactl load-module module-null-sink sink_name="$NULL_SINK" sink_properties=device.description="$NULL_SINK" 2>/dev/null)
                if [ -n "$M_NULL" ]; then
                    REC_MODS+=("$M_NULL")
                    DESK_PA_VOL=$(awk -v v="$DESK_VOL" 'BEGIN { printf "%d", (v > 0 ? v : 1.0) * 65536 }')
                    MIC_PA_VOL=$(awk -v v="$MIC_VOL" 'BEGIN { printf "%d", (v > 0 ? v : 1.0) * 65536 }')
                    M_LOOP1=$(pactl load-module module-loopback source="$DESK_SOURCE" sink="$NULL_SINK" volume="$DESK_PA_VOL" 2>/dev/null)
                    [ -n "$M_LOOP1" ] && REC_MODS+=("$M_LOOP1")
                    M_LOOP2=$(pactl load-module module-loopback source="$MIC_SOURCE" sink="$NULL_SINK" volume="$MIC_PA_VOL" 2>/dev/null)
                    [ -n "$M_LOOP2" ] && REC_MODS+=("$M_LOOP2")
                    WF_ARGS+=(--audio="${NULL_SINK}.monitor")
                else
                    WF_ARGS+=(--audio)
                fi
            elif [ "$DESK_MUTE" != "true" ]; then
                DESK_SINK=$(pactl get-default-sink 2>/dev/null)
                if [ -n "$DESK_SINK" ]; then
                    WF_ARGS+=(--audio="${DESK_SINK}.monitor")
                else
                    WF_ARGS+=(--audio)
                fi
            elif [ "$MIC_MUTE" != "true" ]; then
                if [ -n "$MIC_DEVICE" ] && [ "$MIC_DEVICE" != "null" ]; then
                    MIC_DEV="$MIC_DEVICE"
                else
                    MIC_DEV=$(pactl get-default-source 2>/dev/null)
                fi
                if [ -n "$MIC_DEV" ]; then
                    use_mic_source "$MIC_DEV"
                    WF_ARGS+=(--audio="$MIC_REC_SOURCE")
                else
                    WF_ARGS+=(--audio)
                fi
            fi

            wf-recorder "${WF_ARGS[@]}" > /dev/null 2>&1 &
            REC_PID=$!
        else
            GSR_ARGS=(-w "${TARGET_MON:-screen}" -c "mp4" -f "60" -ac "aac")
            DESK_DEV=""
            MIC_DEV=""

            if [ "$DESK_MUTE" != "true" ]; then
                DESK_SINK=$(pactl get-default-sink 2>/dev/null)
                if [ -n "$DESK_SINK" ]; then
                    DESK_DEV="${DESK_SINK}.monitor"
                else
                    DESK_DEV="default_output"
                fi
            fi

            if [ "$MIC_MUTE" != "true" ]; then
                if [ -n "$MIC_DEVICE" ] && [ "$MIC_DEVICE" != "null" ]; then
                    MIC_DEV="$MIC_DEVICE"
                else
                    MIC_DEV=$(pactl get-default-source 2>/dev/null)
                fi
                if [ -z "$MIC_DEV" ]; then
                    MIC_DEV="default_input"
                fi
                use_mic_source "$MIC_DEV"
                MIC_DEV="$MIC_REC_SOURCE"
            fi

            if [ -n "$DESK_DEV" ] && [ -n "$MIC_DEV" ]; then
                GSR_ARGS+=(-a "${DESK_DEV}|${MIC_DEV}")
            elif [ -n "$DESK_DEV" ]; then
                GSR_ARGS+=(-a "$DESK_DEV")
            elif [ -n "$MIC_DEV" ]; then
                GSR_ARGS+=(-a "$MIC_DEV")
            fi

            gpu-screen-recorder "${GSR_ARGS[@]}" -o "$VID_FILENAME" > /dev/null 2>&1 &
            REC_PID=$!
        fi
        if [ ${#REC_MODS[@]} -gt 0 ]; then
            printf "%s\n" "${REC_MODS[@]}" > "$CACHE_DIR/rec_modules"
        fi
        date +%s > "$CACHE_DIR/rec_start_epoch"
        echo "$VID_FILENAME" > "$CACHE_DIR/final_file"
        mo_pid_write "$CACHE_DIR/rec_pid" "$REC_PID"
        notif_app="$(t "screenshot.notifications.recorder_app_name")"
        notif_title="$(t "screenshot.notifications.recording_started_title")"
        notif_body="$(t "screenshot.notifications.recording_started_body")"
        notify-send -a "$notif_app" "$notif_title" "$notif_body"
        exit 0
    fi

    TMP_SCREENSHOT="$QS_RUN_SCREENSHOT/instant_snap_$$.png"
    if [ -n "$GEOMETRY" ]; then
        grim -l 0 -g "$GEOMETRY" "$TMP_SCREENSHOT"
    elif [ -n "$TARGET_MON" ]; then
        grim -o "$TARGET_MON" -l 0 "$TMP_SCREENSHOT" 2>/dev/null || grim -l 0 "$TMP_SCREENSHOT"
    else
        grim -l 0 "$TMP_SCREENSHOT"
    fi

    if [ "$EDIT_MODE" = true ]; then
        GSK_RENDERER=gl satty --filename "$TMP_SCREENSHOT" --output-filename "$FILENAME" --init-tool brush --copy-command "wl-copy --type image/png"
    else
        cp "$TMP_SCREENSHOT" "$FILENAME"
    fi
    rm -f "$TMP_SCREENSHOT"

    if [ -s "$FILENAME" ]; then
        wl-copy --type image/png < "$FILENAME"
        (
            notif_app="$(t "screenshot.notifications.screenshot_app_name")"
            notif_action="$(t "screenshot.notifications.open_folder")"
            notif_title="$(t "screenshot.notifications.screenshot_saved_title")"
            notif_body="$(t "screenshot.notifications.screenshot_saved_body" "file=Screenshot_$time.png" "folder=$SAVE_DIR")"
            ACTION=$(notify-send -a "$notif_app" -i "$FILENAME" -h "string:image-path:$FILENAME" -A "default=$notif_action" "$notif_title" "$notif_body")
            [ "$ACTION" = "default" ] && open_folder "$SAVE_DIR"
        ) &
    fi
    exit 0
fi
