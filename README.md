# Claude IRC Bot

A Claude AI-powered IRC bot with full **Anope services** support (NickServ + ChanServ), flood protection, and a live admin command system.

Connect Claude to any IRC network. Default network: **2600net** (`irc.scuttled.net:6697` TLS).

---

## Features

- **Claude AI** responds when directly addressed — never passive-listening to channel chatter
- **TLS-only** connections (port 6697 by default)
- **NickServ**: auto-register nick, identify on connect, ghost/recover stolen nicks, handle enforcement
- **ChanServ**: register and own channels, restore topic after splits, manage access list
- **Flood protection**: per-user rate limiting with escalating consequences, output token bucket, bounded API thread pool
- **Input sanitisation**: CRLF injection blocked, IRC control codes stripped, length-capped
- **Prompt injection defence**: hardened system prompt + user messages wrapped in XML tags
- **Admin commands**: live nick/channel/security management from IRC via `!bot`
- **Permanent ignore list**: nick, hostmask, and wildcard support; runtime-editable
- Fully configurable for **any IRC network** — not just 2600net

---

## Quick install (Debian / Ubuntu)

```bash
git clone https://github.com/your-org/claude-irc-bot.git
cd claude-irc-bot
sudo bash install.sh
```

The installer walks you through all settings interactively, creates a system user, writes `/etc/claude-irc-bot/config.ini`, and installs a `systemd` service that starts on boot and restarts on crash.

No containers required. Works alongside an existing Apache setup.

---

## Manual install

### 1. System user

```bash
sudo useradd --system --no-create-home --shell /usr/sbin/nologin claudebot
```

### 2. Deploy

```bash
sudo mkdir -p /opt/claude-irc-bot /etc/claude-irc-bot
sudo cp claude_irc_bot.py /opt/claude-irc-bot/
sudo chown -R claudebot:claudebot /opt/claude-irc-bot
sudo chmod 750 /opt/claude-irc-bot/claude_irc_bot.py
```

### 3. Configure

```bash
sudo cp config.example.ini /etc/claude-irc-bot/config.ini
sudo chown root:claudebot /etc/claude-irc-bot/config.ini
sudo chmod 640 /etc/claude-irc-bot/config.ini
sudo nano /etc/claude-irc-bot/config.ini
```

Minimum required values:

| Section | Key | Description |
|---|---|---|
| `[network]` | `name` | Your IRC network name (e.g. `2600net`) |
| `[irc]` | `server` | IRC server hostname |
| `[irc]` | `nick` | Bot's IRC nick |
| `[irc]` | `channels` | Channels to join |
| `[nickserv]` | `password` | NickServ password |
| `[nickserv]` | `email` | Email for nick registration |
| `[chanserv]` | `managed_channels` | Channel(s) the bot should own |
| `[bot]` | `admins` | Your IRC nick(s) |
| `[anthropic]` | `api_key` | From console.anthropic.com |

### 4. Install dependency

```bash
sudo pip3 install anthropic
```

### 5. systemd service

```bash
sudo cp claude-irc-bot.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now claude-irc-bot
```

---

## Changing the IRC network

All network-specific settings live in `config.ini`. To run on a different network:

```ini
[network]
name        = EFnet
description = One of the oldest IRC networks

[irc]
server      = irc.efnet.org
port        = 6697
nick        = ClaudeBot
channels    = #help, #claude
```

The bot's self-description in IRC automatically uses the configured name — no code changes needed.

---

## Using the bot on IRC

The bot **only responds when directly addressed**. It ignores all other channel traffic.

| How to address the bot | Example |
|---|---|
| Nick followed by `:` | `ClaudeBot: what is BGP?` |
| Nick followed by `,` | `ClaudeBot, explain OSPF` |
| Trigger prefix | `!claude what is a VLAN?` |
| Private message | `/msg ClaudeBot hello` |

Anything else (e.g. `hey ClaudeBot!` mid-sentence) is silently ignored.

---

## Admin commands (`!bot`)

Only nicks in `[bot] admins` can use these. Works in channel or by PM.

```
!bot status                          — show connection/services state
!bot ghost / recover                 — reclaim stolen nick

!bot op/deop/voice/devoice <nick>    — channel privilege management
!bot kick <nick> [reason]
!bot ban/unban <mask>

!bot topic <text>                    — update channel topic via ChanServ
!bot register [#chan]                — register channel with ChanServ
!bot setup [#chan]                   — re-apply all ChanServ settings

!bot access add <nick> <level>       — ChanServ access list
!bot access del <nick>
!bot access list

!bot akick add/del <mask>            — permanent channel bans

!bot ignore/unignore <mask>          — bot-level permanent ignore
!bot ignorelist
!bot ratelimit reset <nick>          — clear a user's flood cooldown

!bot help                            — full command list in IRC
```

---

## NickServ behaviour

| Situation | What the bot does |
|---|---|
| First connect, nick unregistered | Auto-registers with `REGISTER <pass> <email>`, then identifies |
| Normal reconnect | Sends `IDENTIFY <pass>` immediately after welcome |
| Nick taken on connect | Switches to `ClaudeBot_`, sends `GHOST`, reclaims nick |
| Anope enforcement notice | Re-identifies automatically |
| Anope force-changes nick | Sends `RECOVER` then `RELEASE`, takes nick back |

---

## Security

| Threat | Defence |
|---|---|
| User floods the bot with commands | Per-user cooldown + warn + temp-ignore escalation |
| Coordinated multi-user flood | Bounded `ThreadPoolExecutor` (max 4 concurrent API calls) |
| Bot floods itself off the network | Token-bucket output queue; PONG/NICK/QUIT bypass it |
| CRLF injection via user input | `\r`, `\n`, `\x00` stripped before any processing |
| IRC control code spam | All mIRC formatting codes stripped |
| Prompt injection attempts | Hardened system prompt + XML-wrapped user messages |
| Known bad actors | Permanent ignore list with wildcard hostmask support |
| Non-admin using `!bot` | Silently dropped with no response |

---

## Requirements

- Python 3.10+
- `pip install anthropic`
- Linux with systemd (Debian 11+, Ubuntu 22.04+ recommended)
- IRC network with Anope services (NickServ / ChanServ)
- Anthropic API key — console.anthropic.com

No containers. No reverse proxy needed (the bot connects outbound only).

---

## Default network: 2600net

The default config points to **2600net**, a hacker/tech IRC network run by the 2600 community.

- Server: `irc.scuttled.net:6697` (TLS)
- Services: Anope (NickServ, ChanServ, OperServ, MemoServ)

To use a different network, change the `[network]` and `[irc]` sections in `config.ini`.

---

## License

MIT — see `LICENSE`.

Contributions welcome. Pull requests and issues accepted.
