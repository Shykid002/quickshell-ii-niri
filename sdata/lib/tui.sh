#!/bin/bash
# TUI functions for ii-niri setup
# Uses 'gum' if available, falls back to simple menus
# This script is meant to be sourced.

# shellcheck shell=bash

###############################################################################
# Gum Detection & Fallback
###############################################################################
HAS_GUM=false
command -v gum &>/dev/null && HAS_GUM=true

###############################################################################
# Spinner / Progress
###############################################################################
tui_spin() {
    local title="$1"
    shift
    if $HAS_GUM; then
        gum spin --spinner dot --title "$title" -- "$@"
    else
        echo -n "$title... "
        "$@" >/dev/null 2>&1
        echo "done"
    fi
}

###############################################################################
# Styled Output
###############################################################################
tui_title() {
    local text="$1"
    if $HAS_GUM; then
        echo "$text" | gum style --foreground 212 --bold
    else
        echo -e "${STY_CYAN}${STY_BOLD}$text${STY_RST}"
    fi
}

tui_subtitle() {
    local text="$1"
    if $HAS_GUM; then
        echo "$text" | gum style --foreground 245 --italic
    else
        echo -e "${STY_FAINT}$text${STY_RST}"
    fi
}

tui_success() {
    local text="$1"
    if $HAS_GUM; then
        echo "✓ $text" | gum style --foreground 82
    else
        echo -e "${STY_GREEN}✓${STY_RST} $text"
    fi
}

tui_error() {
    local text="$1"
    if $HAS_GUM; then
        echo "✗ $text" | gum style --foreground 196
    else
        echo -e "${STY_RED}✗${STY_RST} $text"
    fi
}

tui_warn() {
    local text="$1"
    if $HAS_GUM; then
        echo "⚠ $text" | gum style --foreground 214
    else
        echo -e "${STY_YELLOW}⚠${STY_RST} $text"
    fi
}

tui_info() {
    local text="$1"
    if $HAS_GUM; then
        echo "→ $text" | gum style --foreground 39
    else
        echo -e "${STY_BLUE}→${STY_RST} $text"
    fi
}

###############################################################################
# Prompts
###############################################################################
tui_confirm() {
    local prompt="${1:-Continue?}"
    local default="${2:-yes}"
    
    if $HAS_GUM; then
        if [[ "$default" == "yes" ]]; then
            gum confirm --default=yes "$prompt"
        else
            gum confirm --default=no "$prompt"
        fi
    else
        local yn_hint="[Y/n]"
        [[ "$default" != "yes" ]] && yn_hint="[y/N]"
        
        read -p "$prompt $yn_hint " -n 1 -r
        echo
        if [[ "$default" == "yes" ]]; then
            [[ ! $REPLY =~ ^[Nn]$ ]]
        else
            [[ $REPLY =~ ^[Yy]$ ]]
        fi
    fi
}

tui_input() {
    local prompt="$1"
    local default="$2"
    
    if $HAS_GUM; then
        gum input --placeholder "$default" --prompt "$prompt "
    else
        read -p "$prompt [$default]: " value
        echo "${value:-$default}"
    fi
}

tui_choose() {
    local header="$1"
    shift
    local options=("$@")
    
    if $HAS_GUM; then
        gum choose --header "$header" "${options[@]}"
    else
        echo "$header"
        select choice in "${options[@]}"; do
            echo "$choice"
            break
        done
    fi
}

tui_choose_multi() {
    local header="$1"
    shift
    local options=("$@")
    
    if $HAS_GUM; then
        gum choose --no-limit --header "$header" "${options[@]}"
    else
        echo "$header (enter numbers separated by space, or 'all'):"
        local i=1
        for opt in "${options[@]}"; do
            echo "  $i) $opt"
            ((i++))
        done
        read -p "Selection: " selection
        
        if [[ "$selection" == "all" ]]; then
            printf '%s\n' "${options[@]}"
        else
            for num in $selection; do
                echo "${options[$((num-1))]}"
            done
        fi
    fi
}

###############################################################################
# Boxes & Panels
###############################################################################
tui_box() {
    local title="$1"
    local content="$2"
    local color="${3:-212}"
    
    if $HAS_GUM; then
        echo "$content" | gum style --border rounded --border-foreground "$color" --padding "0 1" --margin "0 0"
    else
        local width=60
        local border_char="─"
        local corner_tl="┌"
        local corner_tr="┐"
        local corner_bl="└"
        local corner_br="┘"
        local side="│"
        
        # Top border
        echo -e "${STY_CYAN}${corner_tl}$(printf '%*s' $((width-2)) | tr ' ' "$border_char")${corner_tr}${STY_RST}"
        
        # Content
        while IFS= read -r line; do
            printf "${STY_CYAN}${side}${STY_RST} %-$((width-4))s ${STY_CYAN}${side}${STY_RST}\n" "$line"
        done <<< "$content"
        
        # Bottom border
        echo -e "${STY_CYAN}${corner_bl}$(printf '%*s' $((width-2)) | tr ' ' "$border_char")${corner_br}${STY_RST}"
    fi
}

tui_banner() {
    if $HAS_GUM; then
        gum style \
            --foreground 212 --border-foreground 99 \
            --border double --align center \
            --width 50 --margin "1 0" --padding "1 2" \
            "ii-niri" "" "illogical-impulse on Niri"
    else
        echo -e "${STY_CYAN}${STY_BOLD}"
        cat << 'EOF'
╔══════════════════════════════════════════╗
║              ii-niri                     ║
║      illogical-impulse on Niri           ║
╚══════════════════════════════════════════╝
EOF
        echo -e "${STY_RST}"
    fi
}

###############################################################################
# Status Display
###############################################################################
tui_status_line() {
    local label="$1"
    local value="$2"
    local status="${3:-}"  # ok, warn, error, or empty
    
    local color=""
    case "$status" in
        ok)    color="${STY_GREEN}" ;;
        warn)  color="${STY_YELLOW}" ;;
        error) color="${STY_RED}" ;;
        *)     color="${STY_RST}" ;;
    esac
    
    printf "  ${STY_BOLD}%-14s${STY_RST} ${color}%s${STY_RST}\n" "$label" "$value"
}

tui_divider() {
    local char="${1:--}"
    local width="${2:-50}"
    local line=$(printf '%*s' "$width" | tr ' ' "$char")
    if $HAS_GUM; then
        echo "$line" | gum style --foreground 240
    else
        echo -e "${STY_FAINT}${line}${STY_RST}"
    fi
}

###############################################################################
# Progress Steps
###############################################################################
tui_step() {
    local current="$1"
    local total="$2"
    local description="$3"
    
    if $HAS_GUM; then
        echo "[$current/$total] $description" | gum style --foreground 212 --bold
    else
        echo -e "${STY_CYAN}${STY_BOLD}[$current/$total]${STY_RST} $description"
    fi
}

tui_progress_bar() {
    local current="$1"
    local total="$2"
    local width="${3:-40}"
    
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    
    local bar=""
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    
    echo -e "${STY_CYAN}${bar}${STY_RST} ${percent}%"
}

###############################################################################
# Tables
###############################################################################
tui_table_row() {
    local col1="$1"
    local col2="$2"
    local col1_width="${3:-20}"
    
    printf "  ${STY_FAINT}│${STY_RST} %-${col1_width}s ${STY_FAINT}│${STY_RST} %s\n" "$col1" "$col2"
}

tui_table_header() {
    local col1="$1"
    local col2="$2"
    local col1_width="${3:-20}"
    local col2_width="${4:-30}"
    
    local h_line1=$(printf '%*s' $((col1_width+2)) | tr ' ' '-')
    local h_line2=$(printf '%*s' $((col2_width)) | tr ' ' '-')
    
    echo -e "  ${STY_FAINT}+${h_line1}+${h_line2}+${STY_RST}"
    printf "  ${STY_FAINT}|${STY_RST} ${STY_BOLD}%-${col1_width}s${STY_RST} ${STY_FAINT}|${STY_RST} ${STY_BOLD}%-$((col2_width-2))s${STY_RST} ${STY_FAINT}|${STY_RST}\n" "$col1" "$col2"
    echo -e "  ${STY_FAINT}+${h_line1}+${h_line2}+${STY_RST}"
}

tui_table_row() {
    local col1="$1"
    local col2="$2"
    local col1_width="${3:-20}"
    local col2_width="${4:-30}"
    
    printf "  ${STY_FAINT}|${STY_RST} %-${col1_width}s ${STY_FAINT}|${STY_RST} %-$((col2_width-2))s ${STY_FAINT}|${STY_RST}\n" "$col1" "$col2"
}

tui_table_footer() {
    local col1_width="${1:-20}"
    local col2_width="${2:-30}"
    
    local h_line1=$(printf '%*s' $((col1_width+2)) | tr ' ' '-')
    local h_line2=$(printf '%*s' $((col2_width)) | tr ' ' '-')
    
    echo -e "  ${STY_FAINT}+${h_line1}+${h_line2}+${STY_RST}"
}
