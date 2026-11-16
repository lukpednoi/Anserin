# Loaded only by the Kitty profile; never modifies ~/.bashrc.
[[ $- == *i* && -z ${_mo_prompt_loaded:-} ]] || return 0
_mo_prompt_loaded=1
_mo_original_ps1=$PS1

_mo_refresh_prompt() {
    local previous_status=$?
    local _mo_style=default _mo_bg0 _mo_bg1 _mo_bg2 _mo_fg _mo_line=
    local palette="${1:-$HOME/.config/anserin/terminal/prompt.env}"
    [[ -f $palette ]] && source "$palette"
    if [[ $_mo_style != hex ]]; then
        PS1=$_mo_original_ps1
        return "$previous_status"
    fi
    local reset='\[\e[0m\]' fg="\[\e[38;2;${_mo_fg}m\]"
    local line="\[\e[38;2;${_mo_line:-$_mo_bg0}m\]"
    local bg0="\[\e[48;2;${_mo_bg0}m\]" bg1="\[\e[48;2;${_mo_bg1}m\]" bg2="\[\e[48;2;${_mo_bg2}m\]"
    local cap0="\[\e[38;2;${_mo_bg0}m\]" cap1="\[\e[38;2;${_mo_bg1}m\]" cap2="\[\e[38;2;${_mo_bg2}m\]"
    # Kitty's fractional text size keeps Readline's cell widths intact (Kitty >= 0.40).
    local small='\[\e]66;n=7:d=8:v=2:h=2;\]' end='\[\a\]'
    [[ ${TERM:-} == xterm-kitty ]] || { small=''; end=''; }
    PS1="\n  ${line}╭─${cap0}${bg0}${fg}${small}  ${end}${bg1}${cap0}${fg}${small} \u ${end}${bg2}${cap1}${fg}${small}  \w ${end}${reset}${cap2}${reset}\n  ${line}╰─❯${reset} "
    return "$previous_status"
}

if [[ $(declare -p PROMPT_COMMAND 2>/dev/null) != 'declare -a '* ]]; then
    PROMPT_COMMAND=("${PROMPT_COMMAND:-:}")
fi
PROMPT_COMMAND+=(_mo_refresh_prompt)
