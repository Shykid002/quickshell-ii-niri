# Greeting for ii-niri installer
# This script is meant to be sourced.

# shellcheck shell=bash

#####################################################################################
# System Detection
#####################################################################################
detect_system() {
  # Distro detection
  if [[ -f /etc/os-release ]]; then
    source /etc/os-release
    DETECTED_DISTRO="${PRETTY_NAME:-$NAME}"
    DETECTED_DISTRO_ID="${ID}"
  else
    DETECTED_DISTRO="Unknown Linux"
    DETECTED_DISTRO_ID="unknown"
  fi

  # Shell detection
  DETECTED_SHELL=$(basename "${SHELL:-unknown}")
  
  # DE/WM detection
  if [[ -n "$NIRI_SOCKET" ]]; then
    DETECTED_DE="Niri"
  elif [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    DETECTED_DE="Hyprland"
  elif [[ -n "$SWAYSOCK" ]]; then
    DETECTED_DE="Sway"
  elif [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
    DETECTED_DE="$XDG_CURRENT_DESKTOP"
  else
    DETECTED_DE="Not running"
  fi

  # Session type
  DETECTED_SESSION="${XDG_SESSION_TYPE:-unknown}"
  
  # Check for AUR helper
  if command -v yay &>/dev/null; then
    DETECTED_AUR="yay"
  elif command -v paru &>/dev/null; then
    DETECTED_AUR="paru"
  else
    DETECTED_AUR="none (will install)"
  fi
}

detect_system

#####################################################################################
# Banner
#####################################################################################
clear
if $HAS_GUM; then
    gum style \
        --foreground 212 --border-foreground 99 \
        --border double --align center \
        --width 60 --margin "1 0" --padding "1 2" \
        "██╗██╗      ███╗   ██╗██╗██████╗ ██╗" \
        "██║██║      ████╗  ██║██║██╔══██╗██║" \
        "██║██║█████╗██╔██╗ ██║██║██████╔╝██║" \
        "██║██║╚════╝██║╚██╗██║██║██╔══██╗██║" \
        "██║██║      ██║ ╚████║██║██║  ██║██║" \
        "╚═╝╚═╝      ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═╝" \
        "" \
        "illogical-impulse on Niri"
else
    printf "${STY_CYAN}${STY_BOLD}"
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     ██╗██╗      ███╗   ██╗██╗██████╗ ██╗                     ║
║     ██║██║      ████╗  ██║██║██╔══██╗██║                     ║
║     ██║██║█████╗██╔██╗ ██║██║██████╔╝██║                     ║
║     ██║██║╚════╝██║╚██╗██║██║██╔══██╗██║                     ║
║     ██║██║      ██║ ╚████║██║██║  ██║██║                     ║
║     ╚═╝╚═╝      ╚═╝  ╚═══╝╚═╝╚═╝  ╚═╝╚═╝                     ║
║                                                              ║
║          illogical-impulse on Niri                           ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    printf "${STY_RST}\n"
fi

#####################################################################################
# System Info Display
#####################################################################################
echo ""
tui_title "System Detection"
echo ""

tui_table_header "Property" "Value" 12 35
tui_table_row "Distro" "$DETECTED_DISTRO" 12 35
tui_table_row "Shell" "$DETECTED_SHELL" 12 35
tui_table_row "Session" "$DETECTED_SESSION" 12 35
tui_table_row "Compositor" "$DETECTED_DE" 12 35
tui_table_row "AUR Helper" "$DETECTED_AUR" 12 35
tui_table_footer 12 35

echo ""

# Arch check
if [[ "$DETECTED_DISTRO_ID" != "arch" && "$DETECTED_DISTRO_ID" != "endeavouros" && "$DETECTED_DISTRO_ID" != "manjaro" && "$DETECTED_DISTRO_ID" != "garuda" && "$DETECTED_DISTRO_ID" != "cachyos" ]]; then
  tui_warn "This installer is designed for Arch-based distros."
  tui_info "Detected: $DETECTED_DISTRO"
  tui_info "You can continue, but package installation may fail."
  echo ""
fi

#####################################################################################
# Installation Plan
#####################################################################################
tui_title "Installation Plan"
echo ""

tui_success "Install packages (Niri, Quickshell, Qt6, fonts...)"
tui_success "Configure user groups and systemd services"
tui_success "Setup GTK/Qt theming (Matugen, Kvantum, Darkly)"
tui_success "Copy configs to ~/.config/ (with backups)"
tui_success "Set default wallpaper and generate theme"

echo ""
tui_subtitle "This may take a while depending on your internet speed."
tui_subtitle "Existing configs will be backed up to: $BACKUP_DIR"
echo ""

if $ask; then
  if ! tui_confirm "Ready to install?"; then
    echo "Cancelled."
    exit 0
  fi
  echo ""
fi
