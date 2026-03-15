#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Claude IRC Bot — Interactive Installer
# Tested on Debian 11/12 and Ubuntu 22.04/24.04
# Run as root: sudo bash install.sh
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
[[ $EUID -ne 0 ]] && error "Please run as root: sudo bash install.sh"

echo ""
echo -e "${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${BOLD}║            Claude IRC Bot — Installer                ║${RESET}"
echo -e "${BOLD}║    Powered by Anthropic Claude + Anope Services      ║${RESET}"
echo -e "${BOLD}║    Written by Claude (Anthropic) for 2600net         ║${RESET}"
echo -e "${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "Default network: ${CYAN}2600net${RESET} (irc.scuttled.net:6697 TLS)"
echo -e "Press Enter to accept any default shown in [brackets]."
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Step 1 — Network & IRC
# ─────────────────────────────────────────────────────────────────────────────
echo -e "${BOLD}── Step 1: Network & IRC settings ─────────────────────${RESET}"
echo ""

ask "IRC network name (shown in bot's self-description) [2600net]:"
read -r NET_NAME; NET_NAME="${NET_NAME:-2600net}"

ask "IRC server hostname [irc.scuttled.net]:"
read -r IRC_SERVER; IRC_SERVER="${IRC_SERVER:-irc.scuttled.net}"

ask "IRC server TLS port [6697]:"
read -r IRC_PORT; IRC_PORT="${IRC_PORT:-6697}"

ask "Bot nick [ClaudeBot]:"
read -r BOT_NICK; BOT_NICK="${BOT_NICK:-ClaudeBot}"

ask "Channels to join (comma-separated) [#ClaudeBot]:"
read -r IRC_CHANNELS; IRC_CHANNELS="${IRC_CHANNELS:-#ClaudeBot}"
# The bot will join AND register/manage all of these channels with ChanServ.
# No separate ChanServ channel list needed.

ask "Channel topic [Anthropic AI - IRC Connector by 2600net]:"
read -r CS_TOPIC
CS_TOPIC="${CS_TOPIC:-Anthropic AI - IRC Connector by 2600net}"

ask "Command trigger prefix [!claude]:"
read -r TRIGGER; TRIGGER="${TRIGGER:-!claude}"

# ─────────────────────────────────────────────────────────────────────────────
# Step 2 — NickServ
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Step 2: NickServ (Anope) ────────────────────────────${RESET}"
echo ""
warn "Leave password blank to skip NickServ (not recommended on public networks)"
echo ""

ask "NickServ password for ${BOT_NICK}:"
read -rs NS_PASS; echo ""

NS_EMAIL=""
NS_AUTO_REG="true"
if [[ -n "$NS_PASS" ]]; then
    ask "Email for nick registration (e.g. claudebot@yourdomain.com):"
    read -r NS_EMAIL

    ask "Auto-register nick if not yet registered? [Y/n]:"
    read -r AUTO_REG_NICK; AUTO_REG_NICK="${AUTO_REG_NICK:-Y}"
    [[ "${AUTO_REG_NICK,,}" == "n" ]] && NS_AUTO_REG="false" || NS_AUTO_REG="true"
fi

# ─────────────────────────────────────────────────────────────────────────────
# Step 3 — Admin / co-founder
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Step 3: Admin & ChanServ co-founder ─────────────────${RESET}"
echo ""
echo -e "This nick will be added as co-founder (level 100) on all channels"
echo -e "and will be able to use ${BOLD}!bot${RESET} admin commands."
echo ""

ask "Your IRC nick (admin / co-founder) [r0d3nt]:"
read -r ADMIN_NICK; ADMIN_NICK="${ADMIN_NICK:-r0d3nt}"

# ─────────────────────────────────────────────────────────────────────────────
# Step 4 — Anthropic API key
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Step 4: Anthropic API ───────────────────────────────${RESET}"
echo ""
echo -e "Get your API key at: ${CYAN}https://console.anthropic.com${RESET}"
echo ""

ask "Anthropic API key:"
read -rs API_KEY; echo ""

# ─────────────────────────────────────────────────────────────────────────────
# Step 5 — Linux system user
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Step 5: System user ─────────────────────────────────${RESET}"
echo ""

ask "Linux user to run the bot as [claudebot]:"
read -r SYS_USER; SYS_USER="${SYS_USER:-claudebot}"

# ─────────────────────────────────────────────────────────────────────────────
# Install — system setup
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}── Installing … ────────────────────────────────────────${RESET}"
echo ""

# System user
if id "$SYS_USER" &>/dev/null; then
    warn "User '$SYS_USER' already exists — skipping creation."
else
    useradd --system --no-create-home --shell /usr/sbin/nologin "$SYS_USER"
    success "Created system user: $SYS_USER"
fi

# Directories
mkdir -p /opt/claude-irc-bot /etc/claude-irc-bot
success "Created directories."

# Bot script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "${SCRIPT_DIR}/claude_irc_bot.py" /opt/claude-irc-bot/
chown -R "${SYS_USER}:${SYS_USER}" /opt/claude-irc-bot
chmod 750 /opt/claude-irc-bot/claude_irc_bot.py
success "Installed claude_irc_bot.py → /opt/claude-irc-bot/"

# Python venv  (Ubuntu 24.04 / Debian 12+ require venv — PEP 668)
VENV="/opt/claude-irc-bot/venv"
if [[ -f "${VENV}/bin/python3" ]]; then
    warn "Virtual environment already exists at ${VENV} — skipping creation."
else
    info "Creating Python virtual environment ..."
    python3 -m venv "$VENV"
    success "Virtual environment created."
fi

info "Installing Python packages (anthropic, cryptography) ..."
"${VENV}/bin/pip" install --quiet --upgrade pip anthropic cryptography
success "Packages installed."

# Log file
touch /var/log/claude-irc-bot.log
chown "${SYS_USER}:${SYS_USER}" /var/log/claude-irc-bot.log
success "Created log file: /var/log/claude-irc-bot.log"

# ─────────────────────────────────────────────────────────────────────────────
# Encrypt the NickServ password with Fernet (symmetric AES-128-CBC + HMAC)
# Key lives at /etc/claude-irc-bot/secret.key  (chmod 600, root only)
# Config stores:  password = enc:<fernet_token>
# Bot decrypts at startup; plain text passwords also accepted for manual edits.
# ─────────────────────────────────────────────────────────────────────────────
KEY_FILE="/etc/claude-irc-bot/secret.key"
NS_PASS_STORED="$NS_PASS"   # default: plain (if no password was entered)

if [[ -n "$NS_PASS" ]]; then
    info "Encrypting NickServ password ..."

    # Generate a new key only if one doesn't already exist
    if [[ ! -f "$KEY_FILE" ]]; then
        "${VENV}/bin/python3" - <<PYEOF
from cryptography.fernet import Fernet
key = Fernet.generate_key()
with open("$KEY_FILE", "wb") as f:
    f.write(key)
PYEOF
        chmod 600 "$KEY_FILE"
        chown root:root "$KEY_FILE"
        success "Generated encryption key: $KEY_FILE"
    else
        warn "Encryption key already exists at $KEY_FILE — reusing it."
    fi

    # Encrypt the password
    NS_PASS_STORED=$("${VENV}/bin/python3" - <<PYEOF
from cryptography.fernet import Fernet
with open("$KEY_FILE", "rb") as f:
    key = f.read()
f = Fernet(key)
token = f.encrypt(b"""$NS_PASS""").decode()
print("enc:" + token)
PYEOF
    )
    success "NickServ password encrypted."
fi

# ─────────────────────────────────────────────────────────────────────────────
# Generate config.ini
# ─────────────────────────────────────────────────────────────────────────────
CONFIG_PATH="/etc/claude-irc-bot/config.ini"

cat > "$CONFIG_PATH" <<EOCONF
# Claude IRC Bot — generated by install.sh
# Owner: root:${SYS_USER}   Permissions: 640
# NickServ password is Fernet-encrypted (key: ${KEY_FILE})

[network]
name               = ${NET_NAME}
description        = IRC network at ${IRC_SERVER}:${IRC_PORT}

[irc]
server             = ${IRC_SERVER}
port               = ${IRC_PORT}
nick               = ${BOT_NICK}
ident              = claude
realname           = Claude AI Bot (Anthropic)
# The bot joins these channels on connect AND registers them with ChanServ.
# No separate managed_channels list needed — they are the same.
channels           = ${IRC_CHANNELS}
trigger            = ${TRIGGER}
respond_to_mention = true

EOCONF

if [[ -n "$NS_PASS" ]]; then
cat >> "$CONFIG_PATH" <<EOCONF
[nickserv]
# Password is Fernet-encrypted. To change it, re-run install.sh or use:
#   /opt/claude-irc-bot/venv/bin/python3 /opt/claude-irc-bot/encrypt_password.py
password           = ${NS_PASS_STORED}
email              = ${NS_EMAIL}
auto_register      = ${NS_AUTO_REG}

EOCONF
fi

cat >> "$CONFIG_PATH" <<EOCONF
[chanserv]
# managed_channels intentionally left blank — the bot manages all [irc] channels.
# Set this only if you want ChanServ management on a different set of channels.
managed_channels   =
topic              = ${CS_TOPIC}
auto_register      = true
access_list        = ${ADMIN_NICK}:100

[bot]
admins             = ${ADMIN_NICK}

[security]
user_cooldown_seconds        = 5
warn_after_violations        = 3
temp_ignore_after_violations = 6
temp_ignore_seconds          = 120
output_burst                 = 5
output_rate_seconds          = 1.2
max_concurrent_api_calls     = 4
max_input_length             = 400

[anthropic]
api_key            = ${API_KEY}
model              = claude-sonnet-4-20250514
max_tokens         = 1024
max_history_messages = 20

[topic]
ai_enabled          = true
rotate_every_hours  = 6
prefix              = ${NET_NAME}

[nickserv_profile]
url                 = https://github.com/2600net/claude-irc-bot
greet               = Hi! I am ${BOT_NICK}, a Claude AI assistant on ${NET_NAME}. Say '${BOT_NICK}: <question>' or '${TRIGGER} <question>' to chat!
hide_email          = true

[privacy_notice]
enabled              = true
quiet_period_seconds = 90
message = Welcome, {nick}! Heads up: this channel has an AI assistant ({bot}). Messages sent to {bot} are processed by Anthropic's Claude API (a third-party service outside this IRC network). Please don't share anything private. Info: https://www.anthropic.com/privacy
EOCONF

chown "root:${SYS_USER}" "$CONFIG_PATH"
chmod 640 "$CONFIG_PATH"
success "Generated config: $CONFIG_PATH"

# ─────────────────────────────────────────────────────────────────────────────
# Helper script: re-encrypt a password without re-running the full installer
# ─────────────────────────────────────────────────────────────────────────────
cat > /opt/claude-irc-bot/encrypt_password.py <<'PYEOF'
#!/usr/bin/env python3
"""
Encrypt a plain-text password for use in config.ini.
Usage:  /opt/claude-irc-bot/venv/bin/python3 /opt/claude-irc-bot/encrypt_password.py
"""
import getpass, sys
KEY_FILE = "/etc/claude-irc-bot/secret.key"
try:
    from cryptography.fernet import Fernet
except ImportError:
    print("cryptography package not installed in venv."); sys.exit(1)
try:
    with open(KEY_FILE, "rb") as f:
        key = f.read()
except FileNotFoundError:
    print(f"Key file not found: {KEY_FILE}"); sys.exit(1)
password = getpass.getpass("Enter password to encrypt: ")
token = Fernet(key).encrypt(password.encode()).decode()
print(f"\nAdd this to config.ini under [nickserv] password:\n\n  password = enc:{token}\n")
PYEOF
chmod 750 /opt/claude-irc-bot/encrypt_password.py
chown "${SYS_USER}:${SYS_USER}" /opt/claude-irc-bot/encrypt_password.py
success "Installed encrypt_password.py helper."

# ─────────────────────────────────────────────────────────────────────────────
# systemd service
# ─────────────────────────────────────────────────────────────────────────────
SERVICE_PATH="/etc/systemd/system/claude-irc-bot.service"

cat > "$SERVICE_PATH" <<EOSVC
[Unit]
Description=Claude IRC Bot (${NET_NAME})
Documentation=https://github.com/2600net/claude-irc-bot
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${SYS_USER}
Group=${SYS_USER}
ExecStart=/opt/claude-irc-bot/venv/bin/python3 /opt/claude-irc-bot/claude_irc_bot.py --config /etc/claude-irc-bot/config.ini
WorkingDirectory=/opt/claude-irc-bot
Restart=on-failure
RestartSec=15s
StartLimitIntervalSec=300
StartLimitBurst=5
TimeoutStopSec=15
StandardOutput=journal
StandardError=journal
SyslogIdentifier=claude-irc-bot
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ProtectHome=read-only

[Install]
WantedBy=multi-user.target
EOSVC

systemctl daemon-reload
systemctl enable claude-irc-bot
success "Installed and enabled systemd service."

# ─────────────────────────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}${BOLD}║              Installation complete!                  ║${RESET}"
echo -e "${GREEN}${BOLD}╚══════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "  Network:    ${CYAN}${NET_NAME}${RESET} (${IRC_SERVER}:${IRC_PORT})"
echo -e "  Bot nick:   ${CYAN}${BOT_NICK}${RESET}"
echo -e "  Channels:   ${CYAN}${IRC_CHANNELS}${RESET}"
echo -e "  Co-founder: ${CYAN}${ADMIN_NICK}${RESET}"
echo -e "  Config:     ${CYAN}${CONFIG_PATH}${RESET}"
[[ -n "$NS_PASS" ]] && \
echo -e "  NS key:     ${CYAN}${KEY_FILE}${RESET} (chmod 600)"
echo -e "  Log:        ${CYAN}/var/log/claude-irc-bot.log${RESET}"
echo ""
echo -e "  ${BOLD}Test run (foreground):${RESET}"
echo -e "  /opt/claude-irc-bot/venv/bin/python3 /opt/claude-irc-bot/claude_irc_bot.py \\"
echo -e "      -c /etc/claude-irc-bot/config.ini"
echo ""
echo -e "  ${BOLD}Start as service:${RESET}"
echo -e "  sudo systemctl start claude-irc-bot"
echo -e "  sudo journalctl -u claude-irc-bot -f"
echo ""
echo -e "  In IRC: ${CYAN}${BOT_NICK}: <question>${RESET}  or  ${CYAN}${TRIGGER} <question>${RESET}"
echo ""
if [[ -n "$NS_PASS" && "${NS_AUTO_REG}" == "true" ]]; then
    echo -e "  ${YELLOW}Note:${RESET} Bot will auto-register its nick after 190s on first connect."
    [[ -n "$NS_EMAIL" ]] && \
    echo -e "  ${YELLOW}Note:${RESET} Check ${NS_EMAIL} for a NickServ verification email if required."
    echo -e "  ${YELLOW}Note:${RESET} If so, run from IRC: ${BOLD}!bot confirm <code>${RESET}"
    echo ""
fi
