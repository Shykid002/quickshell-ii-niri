---
inclusion: always
---

# Proven Solutions

Reference of solved problems. **Check before implementing.**

## Niri / Compositor

### Window Screenshots
```fish
niri msg action screenshot-window --id <window_id> --path /tmp/preview.png
```
- Works even with overlay active (if executed BEFORE opening overlay)
- `wlr-screencopy` and `ScreencopyView` DON'T work with active overlay
- `ext-image-copy-capture-v1` NOT implemented in Niri/Smithay

**Clipboard spam fix**: Save highest cliphist ID before capture, then delete newer entries:
```fish
set -l before_id (cliphist list | head -1 | cut -f1)
# ... capture screenshots ...
# cleanup loop: cliphist list | head -1 | cliphist delete
```

**Note**: `cliphist delete` expects full line via pipe, `cliphist delete-id` doesn't exist.

### Notification spam fix
Filter in `services/Notifications.qml` by `appName === "niri"` and `summary.includes("screenshot")`

## System Tray

### Apps with libappindicator don't respond to activate
Spotify, Discord, Slack, etc. Use `TrayService.smartActivate()` which finds existing window or launches via gtk-launch.

## Settings UI

### ConfigSwitch vs ConfigSpinBox
```qml
// ConfigSwitch uses buttonIcon
ConfigSwitch {
    buttonIcon: "icon_name"
    text: Translation.tr("Label")
    checked: Config.options.bar.workspaces.myOption
    onCheckedChanged: Config.options.bar.workspaces.myOption = checked
}

// ConfigSpinBox uses icon
ConfigSpinBox {
    icon: "icon_name"
    text: Translation.tr("Label")
    value: Config.options.bar.workspaces.myValue
    onValueChanged: Config.options.bar.workspaces.myValue = value
}
```

**Critical rules:**
- `ConfigSwitch` uses `buttonIcon`, NOT `icon`
- `ConfigSpinBox` uses `icon`, NOT `buttonIcon`
- Direct Config access: `Config.options.X.Y.Z` - NO optional chaining in settings UI
- Direct assignment in handlers
- NO `setNestedValue()` in settings UI
- StyledToolTip goes INSIDE the component

### ConfigSpinBox external sync
```qml
ConfigSpinBox {
    id: mySpinBox
    value: Config.options?.someValue ?? 0
    onValueChanged: Config.setNestedValue('someValue', value)
    
    Connections {
        target: Config.options
        function onSomeValueChanged() {
            mySpinBox.value = Config.options.someValue
        }
    }
}
```

## Gaming / Input Latency

### Panels capturing input unnecessarily
```qml
// ✅ Use mask to limit input area
mask: Region { item: actualContent }

// ✅ Disable keyboard focus when not needed
WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

// ✅ Hide during GameMode
visible: someCondition && !GameMode.active
```

### GameMode auto-disables
- Shell animations (`Appearance.animationsEnabled`)
- Niri animations (via config.kdl)
- Popup notifications
- Screen corner interactions
- Overlay keyboard focus (OnDemand → None)

## Git

### NEVER use git reset --hard with uncommitted changes
```fish
# ❌ DESTROYS working directory changes
git reset --hard HEAD~1

# ✅ Undo commits keeping local changes
git revert <commit>

# ✅ Undo commits without touching working directory
git reset --soft HEAD~1  # Keeps changes staged
git reset HEAD~1         # Keeps changes unstaged
```

## Setup / Distribution

- Scripts need `+x` permissions
- Fish shell, not bash
- Files in `dots/` require updating `sdata/subcmd-install/3.files.sh`
- QML files in root are auto-detected

## Update System

### Philosophy
- User configs are THEIRS - never modify without explicit consent
- `./setup update` only syncs QML code, never touches user configs
- Migrations offered interactively after update (optional config changes)
- Automatic snapshots before updates for easy rollback
- Smart updates: only sync when there are actual changes

### Commands (v2.2+)
```bash
./setup              # Interactive TUI menu
./setup install      # Full installation (deps + config + files)
./setup update       # Check remote, pull, sync, restart shell
./setup doctor       # Diagnose and auto-fix common issues
./setup rollback     # Restore previous snapshot (time-machine style)
```

Options: `-y` (skip prompts), `-q` (quiet), `-h` (help)

### Snapshots
- Created automatically before each update
- Stored in `~/.local/state/quickshell/snapshots/`
- Include: QML code, user config, niri config, migrations state
- Max 10 snapshots kept (oldest auto-deleted)
- Rollback restores files AND checks out the git commit

### Doctor Auto-Fixes
- Missing directories
- Script permissions (+x)
- Python venv and packages (via uv)
- Version tracking file
- File manifest
- Starts shell if not running

### Version Tracking
- `VERSION` file in repo root contains current version
- `~/.config/illogical-impulse/version.json` tracks installed version + commit
- Snapshots track commit before/after for precise rollback

### Adding New Migrations
1. Create `sdata/migrations/NNN-name.sh`
2. Define: MIGRATION_ID, MIGRATION_TITLE, MIGRATION_DESCRIPTION, MIGRATION_TARGET_FILE
3. Implement: migration_check(), migration_preview(), migration_apply()
4. MIGRATION_REQUIRED=true for first-install auto-apply

### Migration File Template
```bash
MIGRATION_ID="NNN-feature-name"
MIGRATION_TITLE="Human Readable Title"
MIGRATION_DESCRIPTION="What this does and why user might want it."
MIGRATION_TARGET_FILE="~/.config/niri/config.kdl"
MIGRATION_REQUIRED=false  # true = auto-apply on first install

migration_check() {
  # Return 0 if migration should be applied
  local config="${XDG_CONFIG_HOME}/niri/config.kdl"
  [[ -f "$config" ]] && ! grep -q "feature" "$config"
}

migration_preview() {
  echo -e "${STY_GREEN}+ new line${STY_RST}"
}

migration_apply() {
  # Apply the migration
  # Return 0 on success, 1 on failure
}
```
