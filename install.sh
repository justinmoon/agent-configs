#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Installing agent-configs from $SCRIPT_DIR"

# Claude Code
echo "Setting up Claude Code..."
mkdir -p ~/.claude
rm -rf ~/.claude/skills 2>/dev/null || true
ln -sfn "$SCRIPT_DIR/skills" ~/.claude/skills

# Codex (per-skill to preserve .system folder)
echo "Setting up Codex..."
mkdir -p ~/.codex/skills
for skill in "$SCRIPT_DIR/skills"/*/; do
    skill_name=$(basename "$skill")
    rm -f ~/.codex/skills/"$skill_name" 2>/dev/null || true
    ln -sfn "$skill" ~/.codex/skills/"$skill_name"
done

# OpenCode
echo "Setting up OpenCode..."
mkdir -p ~/.config/opencode
rm -rf ~/.config/opencode/skill 2>/dev/null || true
ln -sfn "$SCRIPT_DIR/skills" ~/.config/opencode/skill

# OpenCode tools (optional - only if tool dir exists)
if [ -d "$SCRIPT_DIR/opencode/tool" ]; then
    rm -rf ~/.config/opencode/tool 2>/dev/null || true
    ln -sfn "$SCRIPT_DIR/opencode/tool" ~/.config/opencode/tool

    # Install tool dependencies
    if [ -f "$SCRIPT_DIR/opencode/package.json" ]; then
        echo "Installing OpenCode tool dependencies..."
        cd "$SCRIPT_DIR/opencode"
        if command -v bun &> /dev/null; then
            bun install --silent
        elif command -v npm &> /dev/null; then
            npm install --silent
        else
            echo "Warning: Neither bun nor npm found. OpenCode tools may not work."
        fi
    fi
fi

echo ""
echo "Done! Installed:"
echo "  - Skills: $(ls -1 "$SCRIPT_DIR/skills" | tr '\n' ' ')"
[ -d "$SCRIPT_DIR/opencode/tool" ] && echo "  - OpenCode tools: $(ls -1 "$SCRIPT_DIR/opencode/tool" | tr '\n' ' ')"
