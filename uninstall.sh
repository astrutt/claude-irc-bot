#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Claude IRC Bot — Uninstaller
# Removes all installed components cleanly.
# Run as root: sudo bash uninstall.sh
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[*]${RESET} $*"; }
success() { echo -e "${GREEN}[✓]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[!]${RESET} $*"; }
error()   { echo -e "${RED}[✗]${RESET} $*"; exit 1; }
ask()     { echo -e "${BOLD}${CYAN}[?]${RESET} ${BOLD}$*${RESET}"; }

# ── Root check ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] && error "Please run as root: sudo bash uninstall.sh"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║          Claude IRC Bot — Uninstaller                ║${RESET}"
echo -e "${BOLD}║    This will remove the bot and all its components   ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
warn "This will remove:"
echo -e "   /opt/claude-irc-bot/          (bot files + venv)"
echo -e "   /etc/claude-irc-bot/          (config + encryption key)"
echo -e "   /etc/systemd/system/claude-irc-bot.service"
echo -e "   /var/log/claude-irc-bot.log   (optional)"
echo -e "   System user: claudebot        (optional)"
echo ""

ask "Are you sure you want to uninstall? [y/N]:"
read -r CONFIRM
[[ "${CONFIRM,,}" != "y" ]] && { echo "Aborted."; exit 0; }

echo ""

# ── Stop and disable the service ──────────────────────────────────────────────
if systemctl is-active --quiet claude-irc-bot 2>/dev/null; then
    info "Stopping claude-irc-bot service ..."
    systemctl stop claude-irc-bot
    success "Service stopped."
else
    info "Service is not running — skipping stop."
fi

if systemctl is-enabled --quiet claude-irc-bot 2>/dev/null; then
    info "Disabling claude-irc-bot service ..."
    systemctl disable claude-irc-bot
    success "Service disabled."
fi

# ── Remove systemd unit ───────────────────────────────────────────────────────
if [[ -f /etc/systemd/system/claude-irc-bot.service ]]; then
    rm -f /etc/systemd/system/claude-irc-bot.service
    systemctl daemon-reload
    success "Removed systemd service unit."
else
    info "No systemd unit found — skipping."
fi

# ── Remove bot files ──────────────────────────────────────────────────────────
if [[ -d /opt/claude-irc-bot ]]; then
    rm -rf /opt/claude-irc-bot
    success "Removed /opt/claude-irc-bot/"
else
    info "No bot directory found — skipping."
fi

# ── Remove config and encryption key ─────────────────────────────────────────
if [[ -d /etc/claude-irc-bot ]]; then
    echo ""
    warn "The config directory contains your API key and encryption key:"
    echo -e "   /etc/claude-irc-bot/config.ini"
    echo -e "   /etc/claude-irc-bot/secret.key"
    echo ""
    ask "Remove /etc/claude-irc-bot/ (config + encryption key)? [Y/n]:"
    read -r DEL_CONFIG; DEL_CONFIG="${DEL_CONFIG:-Y}"
    if [[ "${DEL_CONFIG,,}" != "n" ]]; then
        rm -rf /etc/claude-irc-bot
        success "Removed /etc/claude-irc-bot/"
    else
        warn "Keeping /etc/claude-irc-bot/ — remember to secure it manually."
    fi
else
    info "No config directory found — skipping."
fi

# ── Remove log file ───────────────────────────────────────────────────────────
if [[ -f /var/log/claude-irc-bot.log ]]; then
    echo ""
    ask "Remove log file /var/log/claude-irc-bot.log? [Y/n]:"
    read -r DEL_LOG; DEL_LOG="${DEL_LOG:-Y}"
    if [[ "${DEL_LOG,,}" != "n" ]]; then
        rm -f /var/log/claude-irc-bot.log
        success "Removed log file."
    else
        info "Keeping log file."
    fi
fi

# ── Remove system user ────────────────────────────────────────────────────────
# Detect which user the service was running as (default: claudebot)
SYS_USER="claudebot"
if id "$SYS_USER" &>/dev/null; then
    echo ""
    ask "Remove system user '${SYS_USER}'? [Y/n]:"
    read -r DEL_USER; DEL_USER="${DEL_USER:-Y}"
    if [[ "${DEL_USER,,}" != "n" ]]; then
        userdel "$SYS_USER" 2>/dev/null && success "Removed user: $SYS_USER" \
            || warn "Could not remove user $SYS_USER — may still be in use."
    else
        info "Keeping system user '$SYS_USER'."
    fi
else
    info "System user '$SYS_USER' does not exist — skipping."
fi

# ── Done ──────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║              Uninstall complete!                     ║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  To reinstall fresh: ${BOLD}sudo bash install.sh${RESET}"
echo ""
