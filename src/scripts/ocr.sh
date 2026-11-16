#!/usr/bin/env bash
# Text recognition (OCR) for the screenshot tool, adapted from Serpantinum's screenshot.sh and ocr_langs.sh.
#   ocr.sh --geometry "X,Y WxH"   read the text in that part of the screen, copy it and say so in a notification
#   ocr.sh list                   JSON: the downloadable languages, which are installed
#   ocr.sh install <code>         download a language model (tessdata_fast) into Anserin's state
#   ocr.sh remove <code>          remove a downloaded language model (English stays)
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/caching.sh"
source "$SCRIPT_DIR/i18n.sh"

OCR_DATA_DIR="$QS_STATE_DIR/tessdata"
OCR_CACHE_DIR="$QS_CACHE_DIR/ocr"
OCR_MODELS_URL="https://raw.githubusercontent.com/tesseract-ocr/tessdata_fast/main"

ocr_valid_code() { [[ "$1" =~ ^[a-z][a-z_]*$ ]]; }

# Downloaded models live in Anserin's state; while there are none, tesseract's own (system) models are used.
ocr_use_user_data() {
    compgen -G "$OCR_DATA_DIR/*.traineddata" > /dev/null || return 1
    export TESSDATA_PREFIX="$OCR_DATA_DIR"
}

ocr_download() {
    local code="$1" dst="$OCR_DATA_DIR/$1.traineddata"
    [ -s "$dst" ] && return 0
    mkdir -p "$OCR_DATA_DIR"
    curl -fSL -m 600 "$OCR_MODELS_URL/$code.traineddata" -o "$dst.part" 2>/dev/null || { rm -f "$dst.part"; return 1; }
    [ "$(stat -c %s "$dst.part")" -gt 1024 ] || { rm -f "$dst.part"; return 1; }
    mv "$dst.part" "$dst"
}

# English is always kept, so recognition still works once the user's folder takes over from the system one.
ocr_install() { ocr_valid_code "$1" || return 2; ocr_download eng || return 1; ocr_download "$1"; }
ocr_remove() { ocr_valid_code "$1" || return 2; [ "$1" = "eng" ] && return 0; rm -f "$OCR_DATA_DIR/$1.traineddata"; }

ocr_list() {
    ocr_use_user_data
    tesseract --list-langs 2>/dev/null | tail -n +2 | grep -Ev '^(osd|equ)$|_vert$' | python3 -c 'import json,sys; print(json.dumps(sorted(set(l.strip() for l in sys.stdin if l.strip()))))'
}

ocr_ui_language() {
    case "$(get_current_language)" in
        th) echo "tha" ;; ar) echo "ara" ;; az) echo "aze" ;; bg) echo "bul" ;; de) echo "deu" ;; es) echo "spa" ;;
        fa) echo "fas" ;; fr) echo "fra" ;; hi) echo "hin" ;; hy) echo "hye" ;; id) echo "ind" ;;
        it) echo "ita" ;; ja) echo "jpn" ;; ko) echo "kor" ;; nl) echo "nld" ;; pl) echo "pol" ;;
        pt) echo "por" ;; ru) echo "rus" ;; tr) echo "tur" ;; ua) echo "ukr" ;; vi) echo "vie" ;;
        zh) echo "chi_sim" ;; zh_tw) echo "chi_tra" ;;
    esac
}

ocr_candidate_languages() {
    local installed lang
    local -A seen=()
    local ordered=()
    installed="$(tesseract --list-langs 2>/dev/null | tail -n +2 | grep -Ev '^(osd|equ)$|_vert$')"
    for lang in eng "$(ocr_ui_language)" tha rus chi_sim jpn kor ara hin fas hye ukr bul deu spa fra ita por nld pol tur aze ind vie chi_tra $installed; do
        [ -n "$lang" ] && [ -z "${seen[$lang]}" ] && grep -qx "$lang" <<< "$installed" && { seen[$lang]=1; ordered+=("$lang"); }
    done
    printf '%s\n' "${ordered[@]:0:24}"
}

ocr_score_tsv() {
    python3 -c '
import sys
total = chars = good = native = 0
for i, line in enumerate(sys.stdin):
    p = line.rstrip("\n").split("\t")
    if i == 0 or len(p) < 12 or p[0] != "5" or not p[11]:
        continue
    try:
        conf = float(p[10])
    except ValueError:
        continue
    if conf < 0:
        continue
    n = len(p[11])
    total += conf * n
    chars += n
    if conf >= 70:
        good += n
    if conf >= 85:
        native += sum(1 for ch in p[11] if ord(ch) > 0x24F)
print(sys.argv[1], int(total), chars, good, native)' "$1"
}

ocr_score_language() {
    OMP_THREAD_LIMIT=1 tesseract "$1" stdout -l "$2" -c tessedit_create_tsv=1 2>/dev/null | ocr_score_tsv "$2"
}
export -f ocr_score_tsv ocr_score_language

ocr_pick_languages() {
    awk -v order="$1" '
        BEGIN {
            split("eng deu spa fra ita por nld pol tur aze ind vie", latin, " ")
            for (i in latin) grp[latin[i]] = "lat"
            split("rus ukr bul", cyr, " ")
            for (i in cyr) grp[cyr[i]] = "cyr"
            split("chi_sim chi_tra jpn kor", cjk, " ")
            for (i in cjk) grp[cjk[i]] = "cjk"
            split("ara fas", arab, " ")
            for (i in arab) grp[arab[i]] = "ara"
            kn["lat"] = 1; kn["cyr"] = 1; kn["cjk"] = 1; kn["ara"] = 1
            m = split(order, o, " ")
            for (i = 1; i <= m; i++) pri[o[i]] = i
        }
        { lang[NR] = $1; sum[NR] = $2; chars[NR] = $3; good[NR] = $4; native[NR] = $5; if ($3 > maxchars) maxchars = $3 }
        END {
            for (i = 1; i <= NR; i++) {
                if (chars[i] <= 0) continue
                v[i] = (sum[i] / chars[i]) * sqrt(chars[i] / maxchars)
                g = (lang[i] in grp) ? grp[lang[i]] : "x_" lang[i]
                gr[i] = g
                if (!(g in gv) || v[i] > gv[g]) gv[g] = v[i]
                if (good[i] > gg[g]) gg[g] = good[i]
                if (native[i] > gn[g]) gn[g] = native[i]
                if (gg[g] > maxgood) maxgood = gg[g]
                if (v[i] > top) { top = v[i]; topg = g }
            }
            for (g in gv) {
                rep = ""
                for (i = 1; i <= NR; i++) {
                    if (gr[i] == g && v[i] >= gv[g] - 1 && (rep == "" || pri[lang[i]] < pri[rep])) rep = lang[i]
                }
                if (g == topg || (g in kn && gg[g] >= 4 && gg[g] >= 0.3 * maxgood && (g == "lat" || (gn[g] >= 3 && gn[g] >= 0.2 * maxgood)))) { sel[g] = rep }
            }
            out = ""
            for (pass = 0; pass < 2; pass++) {
                while (1) {
                    bestg = ""
                    for (g in sel) {
                        if (sel[g] == "" || (pass == 0) == (g == "lat")) continue
                        if (bestg == "" || gg[g] > gg[bestg]) bestg = g
                    }
                    if (bestg == "") break
                    out = out (out == "" ? "" : "+") sel[bestg]
                    sel[bestg] = ""
                }
            }
            print out
        }'
}

ocr_run() {
    local img="$1" base="$2" lang="$3" sum chars
    local lang_arg=()
    [ -n "$lang" ] && lang_arg=(-l "$lang")
    OCR_CONF=0
    OCR_CHARS=0
    rm -f "$base.txt" "$base.tsv"
    tesseract "$img" "$base" "${lang_arg[@]}" -c tessedit_create_txt=1 -c tessedit_create_tsv=1 2>/dev/null
    [ -s "$base.tsv" ] || return
    read -r _ sum chars _ < <(ocr_score_tsv "$lang" < "$base.tsv")
    OCR_CHARS="${chars:-0}"
    [ "$OCR_CHARS" -gt 0 ] && OCR_CONF=$((sum / chars))
    rm -f "$base.tsv"
}

ocr_recognize() {
    local img="$1" base="$2" langs=() fast scores use ui lang threshold=88
    mapfile -t langs < <(ocr_candidate_languages)
    if [ "${#langs[@]}" -le 1 ]; then
        ocr_run "$img" "$base" "${langs[0]}"
        return
    fi

    fast="eng"
    ui="$(ocr_ui_language)"
    [ -n "$ui" ] && [ "$ui" != "eng" ] && printf '%s\n' "${langs[@]}" | grep -qx "$ui" && fast="$ui+eng"
    for lang in deu spa fra ita por nld pol tur aze ind vie; do
        [ "$lang" != "$ui" ] && printf '%s\n' "${langs[@]}" | grep -qx "$lang" && threshold=95
    done
    ocr_run "$img" "$base" "$fast"
    [ "$OCR_CHARS" -ge 3 ] && [ "$OCR_CONF" -ge "$threshold" ] && return

    scores=$(printf '%s\n' "${langs[@]}" | xargs -P "$(nproc)" -I{} bash -c 'ocr_score_language "$0" "$1"' "$img" {})
    use="$(ocr_pick_languages "${langs[*]}" <<< "$scores")"
    if [ -z "$use" ]; then
        OCR_CONF=0
        OCR_CHARS=0
        rm -f "$base.txt"
        return
    fi
    if [[ "+$use+" != *"+eng+"* ]] && printf '%s\n' "${langs[@]}" | grep -qx eng; then
        use="$use+eng"
    fi
    ocr_run "$img" "$base" "$use"
}

ocr_notify() { notify-send --app-name="Screenshot" --icon=edit-copy "$@"; }

case "$1" in
    list) ocr_list; exit $? ;;
    install) ocr_install "$2"; exit $? ;;
    remove) ocr_remove "$2"; exit $? ;;
    --geometry) GEOMETRY="$2" ;;
    *) echo "Usage: ocr.sh {--geometry \"X,Y WxH\"|list|install <code>|remove <code>}" >&2; exit 2 ;;
esac

if ! command -v tesseract >/dev/null 2>&1; then
    ocr_notify --urgency=critical -- "Text recognition needs tesseract" "Install the tesseract package to read text from screenshots."
    exit 1
fi
ocr_use_user_data
qs_ensure_cache "screenshot"
TMP_IMG="$QS_RUN_SCREENSHOT/ocr_temp_$$.png"
OCR_BASE="$QS_RUN_SCREENSHOT/ocr_out_$$"
grim -l 0 -g "$GEOMETRY" "$TMP_IMG" || exit 1
ocr_recognize "$TMP_IMG" "$OCR_BASE"
OCR_TEXT="$(cat "$OCR_BASE.txt" 2>/dev/null)"
rm -f "$TMP_IMG" "$OCR_BASE".*

# OCR_PRINT=1 prints the text instead (for checks), leaving the clipboard and notifications alone
if [ "${OCR_PRINT:-}" = 1 ]; then printf '%s\n[conf %s]\n' "$OCR_TEXT" "${OCR_CONF:-0}"; exit 0; fi
if [ -n "$(printf '%s' "$OCR_TEXT" | tr -d '[:space:]')" ]; then
    printf '%s' "$OCR_TEXT" | wl-copy
    preview=$(printf '%s' "${OCR_TEXT:0:200}" | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    if [ "${OCR_CONF:-0}" -lt 65 ]; then
        ocr_notify -- "Text copied, but it may be wrong" "Add the text's language in Settings → General → Text recognition."$'\n'"$preview"
    else
        ocr_notify -- "Text copied" "$preview"
    fi
else
    ocr_notify -- "No text found" "Nothing readable in that area. Add its language in Settings → General → Text recognition."
fi
