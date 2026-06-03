#!/usr/bin/env bash
# OpSkill installer
# Auto-detects AI editors and installs /mix /aceopti /aceopti-setup /acesidekick
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/abhishekanand-arch/OpSkill/main/install.sh | bash

set -euo pipefail

REPO_OWNER="abhishekanand-arch"
REPO_NAME="OpSkill"
RAW_URL="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/main"
PLUGIN_KEY="opskill@opskill"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log()  { echo -e "${GREEN}✓${NC} $1"; }
info() { echo -e "${CYAN}→${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
err()  { echo -e "${RED}✗${NC} $1"; }

INSTALLED=()
SKIPPED=()

# ─── Utilities ───────────────────────────────────────────────────────────────

fetch() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if command -v curl &>/dev/null; then
    curl -fsSL "$url" -o "$dest"
  elif command -v wget &>/dev/null; then
    wget -q "$url" -O "$dest"
  else
    err "curl or wget required. Install one and retry."
    exit 1
  fi
}

json_set_bool() {
  # json_set_bool <file> <key_path_dot_notation> true|false
  local file="$1" key="$2" val="$3"
  if command -v python3 &>/dev/null; then
    python3 - "$file" "$key" "$val" <<'PYEOF'
import json, sys
file, key, val = sys.argv[1], sys.argv[2], sys.argv[3] == "true"
with open(file) as f:
    data = json.load(f)
keys = key.split(".")
d = data
for k in keys[:-1]:
    d = d.setdefault(k, {})
d[keys[-1]] = val
with open(file, "w") as f:
    json.dump(data, f, indent=2)
PYEOF
  fi
}

# ─── Claude Code ─────────────────────────────────────────────────────────────

install_claude_code() {
  local claude_dir="$HOME/.claude"
  [[ ! -d "$claude_dir" ]] && { SKIPPED+=("Claude Code (not found)"); return 0; }

  info "Claude Code detected"

  local install_path="$claude_dir/plugins/cache/opskill/opskill/local"
  mkdir -p "$install_path/skills"

  local skills=("mix" "aceopti" "aceopti-setup" "acesidekick")
  for skill in "${skills[@]}"; do
    info "  Downloading skill: $skill"
    fetch "$RAW_URL/skills/$skill/skill.md" "$install_path/skills/$skill/skill.md"
  done
  fetch "$RAW_URL/README.md" "$install_path/README.md"

  # Deploy slash commands (shows in / autocomplete)
  local commands_dir="$install_path/commands"
  mkdir -p "$commands_dir"
  local commands=("mix" "aceopti" "aceopti-setup" "acesidekick")
  for cmd in "${commands[@]}"; do
    info "  Downloading command: $cmd"
    fetch "$RAW_URL/commands/$cmd.toml" "$commands_dir/$cmd.toml"
  done

  # Deploy SessionStart hook
  local hooks_dir="$claude_dir/hooks"
  mkdir -p "$hooks_dir"
  fetch "$RAW_URL/hooks/opskill-activate.js" "$hooks_dir/opskill-activate.js"
  chmod +x "$hooks_dir/opskill-activate.js"

  # Detect node binary
  local node_bin
  node_bin=$(command -v node 2>/dev/null || echo "node")

  # Register hook in settings.json
  if command -v python3 &>/dev/null; then
    python3 - "$claude_dir/settings.json" "$hooks_dir/opskill-activate.js" "$node_bin" <<'PYEOF'
import json, sys, os
settings_file, hook_path, node_bin = sys.argv[1], sys.argv[2], sys.argv[3]

if not os.path.exists(settings_file):
    data = {}
else:
    with open(settings_file) as f:
        data = json.load(f)

new_hook = {
    "type": "command",
    "command": f'"{node_bin}" "{hook_path}"',
    "timeout": 5,
    "statusMessage": "Loading OpSkill..."
}

session_hooks = data.setdefault("hooks", {}).setdefault("SessionStart", [])

already = any(
    h.get("type") == "command" and "opskill-activate" in h.get("command", "")
    for group in session_hooks
    for h in group.get("hooks", [])
)

if not already:
    session_hooks.append({"hooks": [new_hook]})

with open(settings_file, "w") as f:
    json.dump(data, f, indent=2)
PYEOF
  fi

  # Register in installed_plugins.json
  local plugins_json="$claude_dir/plugins/installed_plugins.json"
  if [[ ! -f "$plugins_json" ]]; then
    mkdir -p "$(dirname "$plugins_json")"
    echo '{"version":2,"plugins":{}}' > "$plugins_json"
  fi

  if command -v python3 &>/dev/null; then
    python3 - "$plugins_json" "$install_path" <<'PYEOF'
import json, sys
from datetime import datetime, timezone
file, install_path = sys.argv[1], sys.argv[2]
with open(file) as f:
    data = json.load(f)
data.setdefault("plugins", {})["opskill@opskill"] = [{
    "scope": "user",
    "installPath": install_path,
    "version": "local",
    "installedAt": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z"),
    "lastUpdated": datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
}]
with open(file, "w") as f:
    json.dump(data, f, indent=2)
PYEOF
  else
    warn "  python3 not found — skipping plugin registration. Skills downloaded to $install_path"
  fi

  # Enable in settings.json
  local settings="$claude_dir/settings.json"
  if [[ -f "$settings" ]] && command -v python3 &>/dev/null; then
    python3 - "$settings" <<'PYEOF'
import json, sys
file = sys.argv[1]
with open(file) as f:
    data = json.load(f)
data.setdefault("enabledPlugins", {})["opskill@opskill"] = True
with open(file, "w") as f:
    json.dump(data, f, indent=2)
PYEOF
  elif [[ ! -f "$settings" ]] && command -v python3 &>/dev/null; then
    python3 - "$settings" <<'PYEOF'
import json, sys
file = sys.argv[1]
data = {"enabledPlugins": {"opskill@opskill": True}}
with open(file, "w") as f:
    json.dump(data, f, indent=2)
PYEOF
  fi

  log "Claude Code — installed /mix /aceopti /aceopti-setup /acesidekick"
  INSTALLED+=("Claude Code")
}

# ─── Cursor ──────────────────────────────────────────────────────────────────

install_cursor() {
  local found=0
  [[ -d "$HOME/.cursor" ]] && found=1
  command -v cursor &>/dev/null && found=1
  [[ -d "/Applications/Cursor.app" ]] && found=1
  [[ -d "$HOME/Applications/Cursor.app" ]] && found=1

  [[ $found -eq 0 ]] && { SKIPPED+=("Cursor (not found)"); return 0; }

  info "Cursor detected"
  local rules_dir="$HOME/.cursor/rules"
  mkdir -p "$rules_dir"
  fetch "$RAW_URL/agents/cursor.mdc" "$rules_dir/opskill.mdc"
  log "Cursor — installed to ~/.cursor/rules/opskill.mdc"
  INSTALLED+=("Cursor")
}

# ─── Windsurf ────────────────────────────────────────────────────────────────

install_windsurf() {
  local found=0
  [[ -d "$HOME/.windsurf" ]] && found=1
  [[ -d "/Applications/Windsurf.app" ]] && found=1
  [[ -d "$HOME/Applications/Windsurf.app" ]] && found=1

  [[ $found -eq 0 ]] && { SKIPPED+=("Windsurf (not found)"); return 0; }

  info "Windsurf detected"
  local rules_dir="$HOME/.windsurf/rules"
  mkdir -p "$rules_dir"
  fetch "$RAW_URL/agents/rules.md" "$rules_dir/opskill.md"
  log "Windsurf — installed to ~/.windsurf/rules/opskill.md"
  INSTALLED+=("Windsurf")
}

# ─── Cline / Roo ─────────────────────────────────────────────────────────────

install_cline() {
  local vscode_ext="$HOME/.vscode/extensions"
  local found=0

  if [[ -d "$vscode_ext" ]]; then
    ls "$vscode_ext" 2>/dev/null | grep -qi "cline\|saoudrizwan\|rooveterinaryinc\|roo-cline" && found=1
  fi

  # Also check VSCodium
  local vscodium_ext="$HOME/.vscodium/extensions"
  if [[ -d "$vscodium_ext" ]]; then
    ls "$vscodium_ext" 2>/dev/null | grep -qi "cline\|roo" && found=1
  fi

  [[ $found -eq 0 ]] && { SKIPPED+=("Cline/Roo (not found)"); return 0; }

  info "Cline/Roo detected"
  fetch "$RAW_URL/agents/rules.md" "$HOME/.clinerules"
  log "Cline/Roo — installed to ~/.clinerules"
  INSTALLED+=("Cline/Roo")
}

# ─── GitHub Copilot ──────────────────────────────────────────────────────────

install_copilot() {
  local vscode_ext="$HOME/.vscode/extensions"
  local found=0

  if [[ -d "$vscode_ext" ]]; then
    ls "$vscode_ext" 2>/dev/null | grep -qi "github.copilot" && found=1
  fi

  [[ $found -eq 0 ]] && { SKIPPED+=("GitHub Copilot (not found)"); return 0; }

  info "GitHub Copilot detected"
  mkdir -p "$HOME/.github"
  fetch "$RAW_URL/agents/rules.md" "$HOME/.github/copilot-instructions.md"
  log "GitHub Copilot — installed to ~/.github/copilot-instructions.md"
  INSTALLED+=("GitHub Copilot")
}

# ─── Gemini CLI ──────────────────────────────────────────────────────────────

install_gemini() {
  local found=0
  command -v gemini &>/dev/null && found=1
  [[ -d "$HOME/.gemini" ]] && found=1

  [[ $found -eq 0 ]] && { SKIPPED+=("Gemini CLI (not found)"); return 0; }

  info "Gemini CLI detected"
  mkdir -p "$HOME/.gemini"
  fetch "$RAW_URL/agents/rules.md" "$HOME/.gemini/opskill.md"
  log "Gemini CLI — installed to ~/.gemini/opskill.md"
  INSTALLED+=("Gemini CLI")
}

# ─── Zed ─────────────────────────────────────────────────────────────────────

install_zed() {
  local found=0
  command -v zed &>/dev/null && found=1
  [[ -d "/Applications/Zed.app" ]] && found=1
  [[ -d "$HOME/.config/zed" ]] && found=1

  [[ $found -eq 0 ]] && { SKIPPED+=("Zed (not found)"); return 0; }

  info "Zed detected"
  mkdir -p "$HOME/.config/zed"
  # Zed uses prompts in assistant panel — append to assistant settings
  local rules_file="$HOME/.config/zed/opskill-rules.md"
  fetch "$RAW_URL/agents/rules.md" "$rules_file"
  log "Zed — installed to ~/.config/zed/opskill-rules.md"
  warn "  Zed: manually add content from $rules_file to your assistant system prompt in Zed settings."
  INSTALLED+=("Zed")
}

# ─── Model setup ─────────────────────────────────────────────────────────────

prompt_pick() {
  # prompt_pick <label> <default> [model1 model2 ...]
  local label="$1" default="$2"
  shift 2
  local models=("$@")

  echo ""
  echo -e "${CYAN}  $label${NC}"
  if [[ ${#models[@]} -gt 0 ]]; then
    local i=1
    for m in "${models[@]}"; do
      if [[ "$m" == "$default" ]]; then
        echo "    $i) $m  (recommended)"
      else
        echo "    $i) $m"
      fi
      ((i++))
    done
    echo "    Enter number or type model name [default: $default]: "
    read -r choice </dev/tty
    if [[ -z "$choice" ]]; then
      echo "$default"
    elif [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le ${#models[@]} ]]; then
      echo "${models[$((choice-1))]}"
    else
      echo "$choice"
    fi
  else
    echo "    No models detected. Type model name [default: $default]: "
    read -r choice </dev/tty
    echo "${choice:-$default}"
  fi
}

setup_models() {
  local config_file="$HOME/.claude/plugins/cache/opskill/opskill/local/models.json"

  echo ""
  echo -e "${CYAN}  ─── Model Setup (acesidekick) ───${NC}"
  echo ""

  # Check Ollama running
  local ollama_models=()
  local embed_models=()

  if curl -sf http://localhost:11434/api/tags &>/dev/null; then
    info "Ollama running — fetching installed models"
    local tags
    tags=$(curl -sf http://localhost:11434/api/tags)
    if command -v python3 &>/dev/null; then
      while IFS= read -r m; do
        if [[ "$m" == *"embed"* ]]; then
          embed_models+=("$m")
        else
          ollama_models+=("$m")
        fi
      done < <(python3 -c "
import json, sys
data = json.loads('''$tags''')
for m in data.get('models', []):
    print(m['name'])
")
    fi
  else
    warn "Ollama not running — enter model names manually (run 'ollama serve' first for detection)"
  fi

  # Pick models
  local model_heavy model_fast model_embed

  model_heavy=$(prompt_pick "Coding model (complex tasks, summaries):" "qwen2.5-coder:14b" "${ollama_models[@]}")
  model_fast=$(prompt_pick  "Fast sidekick model (stubs, docstrings, boilerplate):" "qwen2.5-coder:7b" "${ollama_models[@]}")
  model_embed=$(prompt_pick "Embedding model (vector search):" "nomic-embed-text" "${embed_models[@]}")

  # Save config
  mkdir -p "$(dirname "$config_file")"
  python3 - "$config_file" "$model_heavy" "$model_fast" "$model_embed" <<'PYEOF'
import json, sys
file, heavy, fast, embed = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
config = {
    "coding_heavy": heavy,
    "coding_fast": fast,
    "embeddings": embed
}
with open(file, "w") as f:
    json.dump(config, f, indent=2)
PYEOF

  echo ""
  log "Model config saved:"
  echo "     Coding (heavy) : $model_heavy"
  echo "     Coding (fast)  : $model_fast"
  echo "     Embeddings     : $model_embed"
}

# ─── Main ────────────────────────────────────────────────────────────────────

main() {
  echo ""
  echo -e "${CYAN}  ╔═══════════════════════════════╗${NC}"
  echo -e "${CYAN}  ║  OpSkill Installer            ║${NC}"
  echo -e "${CYAN}  ║  /mix /aceopti /acesidekick   ║${NC}"
  echo -e "${CYAN}  ╚═══════════════════════════════╝${NC}"
  echo ""

  install_claude_code
  install_cursor
  install_windsurf
  install_cline
  install_copilot
  install_gemini
  install_zed

  # Model setup — only if Claude Code was installed (needs config path)
  if [[ -d "$HOME/.claude/plugins/cache/opskill/opskill/local" ]]; then
    echo ""
    echo -e "${CYAN}  Set up default models for /acesidekick? [Y/n]: ${NC}"
    read -r do_models </dev/tty
    if [[ "${do_models:-y}" =~ ^[Yy]$ ]]; then
      setup_models
    fi
  fi

  echo ""
  echo "────────────────────────────────"

  if [[ ${#INSTALLED[@]} -gt 0 ]]; then
    echo ""
    log "Installed for:"
    for editor in "${INSTALLED[@]}"; do
      echo "     • $editor"
    done
    echo ""
    log "Skills: /mix  /aceopti  /aceopti-setup  /acesidekick"
    echo ""
    warn "Restart your editor to activate."
  fi

  if [[ ${#SKIPPED[@]} -gt 0 ]]; then
    echo ""
    info "Not detected (skipped):"
    for editor in "${SKIPPED[@]}"; do
      echo "     • $editor"
    done
  fi

  if [[ ${#INSTALLED[@]} -eq 0 ]]; then
    echo ""
    err "No supported editors detected."
    echo ""
    echo "  Supported editors:"
    echo "    Claude Code, Cursor, Windsurf, Cline, Roo, GitHub Copilot, Gemini CLI, Zed"
    echo ""
    echo "  Manual install: https://github.com/${REPO_OWNER}/${REPO_NAME}"
  fi

  echo ""
}

main
