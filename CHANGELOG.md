# Changelog — Claude IRC Bot

All notable changes to the Claude IRC Bot are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [3.1.0] — 2026-03-15

### Added

- `!bot model` admin command — change the Claude model from IRC without SSH
  - `!bot model` — show currently active model
  - `!bot model list` — list available models with shortcuts
  - `!bot model haiku` — switch to claude-haiku-4-5-20251001 (fast, economical)
  - `!bot model sonnet` — switch to claude-sonnet-4-6
  - `!bot model opus` — switch to claude-opus-4-6
  - `!bot model <full-model-string>` — any valid Anthropic model string
  - Change takes effect immediately and is saved to config.ini
- `_save_config_value(section, key, value)` — generic config persistence helper
  used by both `!bot model` and `!bot addadmin/deladmin`
- Dynamic system prompt — model name is injected into the system prompt on every
  API call so the bot correctly answers "what model are you running?" after a
  live `!bot model` change, with no restart required

### Changed

- `_save_admins()` refactored to use `_save_config_value()` — no functional change
- System prompt stored as `_system_prompt_template` with `{model}` placeholder,
  resolved to current `self.model` on every `_reply()` call

### Fixed

- Socket timeout bug — `socket.create_connection(timeout=30)` was leaving a 30s
  timeout on the socket after the TLS handshake, causing the bot to disconnect
  exactly 30 seconds after connecting while waiting for the NickServ holdoff timer.
  Fixed by calling `tls.settimeout(None)` after the handshake.
- Double-connect on reconnect — `_read_loop` was calling `_reconnect()` which called
  `connect()`, while `run()` also called `connect()` after `_read_loop` returned,
  causing two simultaneous connection attempts. Fixed by removing `_reconnect()` from
  `_read_loop` and handling the full reconnect cycle in `run()`.
- Redundant NickServ IDENTIFY after "not registered" notice — bot was scheduling the
  190s registration timer AND sending IDENTIFY 3 seconds later. Fixed by setting
  `_ns_state = NS.WAIT_REG` immediately so `_nickserv_start` skips IDENTIFY.
- `configparser.get()` misuse — `config.get("bot", {}).get("admins", "")` was being
  parsed as `get(section="bot", option={})`, causing `AttributeError: 'dict' object
  has no attribute 'lower'`. Fixed to use `config["bot"].get("admins", "")` with
  section existence check.
- NickServ profile (`SET URL`, `SET GREET`, `SET HIDE EMAIL`) re-running on every
  re-identify (e.g. after GHOST/RECOVER). Fixed with `_ns_profile_done` session flag.
- `SET URL` removed from NickServ profile — not supported by all Anope configurations,
  caused syntax error. URL is still advertised in CTCP VERSION and FINGER responses.
- ChanServ `_cs_post_register` running multiple times per session due to race condition
  and multi-line INFO response triggering multiple calls. Fixed with `threading.Lock`
  guard and one-shot `_cs_info_pending` gate.
- QOP (non-existent Anope xOP level) replaced with SOP + `SET SUCCESSOR` for level 100
  access list entries.
- Double pipe in AI-generated topic (`2600net | topic | | hint`) — default suffix
  had a leading `|` that `_build_topic`'s `" | ".join()` was duplicating. Fixed by
  stripping leading `|` from suffix at config load time.
- `SET SUCCESSOR #channel nick` syntax error — Anope wants `SET SUCCESSOR #channel nick`
  not `SET #channel SUCCESSOR nick`.
- Topic set without ops — bot now waits for `+o` (MODE or NAMREPLY) before attempting
  to set topic or register channel with ChanServ.
- Topic overwrite — bot now respects topics set by others. Only sets topic if blank or
  if the bot itself set the last topic. Pauses rotation when admin sets a topic.
- ChanServ always attempting REGISTER without checking — now queries `CS INFO` first
  and only registers if the channel is confirmed unregistered.
- FastMCP `run()` `host`/`port` kwargs not supported — fixed by launching uvicorn
  directly via `mcp.streamable_http_app()`.

---

## [3.0.0] — 2026-03-15

### Added

Initial public release.

**Core IRC bot:**
- TLS IRC connection (port 6697) with automatic reconnect and exponential back-off
- Responds only when directly addressed: `BotNick: <question>`, `BotNick, <question>`,
  `!claude <question>`, or private message
- Per-channel and per-PM conversation history (configurable depth)
- Claude AI responses via Anthropic API (configurable model)

**Anope NickServ integration:**
- Auto-register nick on first connect (with 190s holdoff for Anope age requirement)
- Auto-identify on subsequent connects
- Ghost/recover stolen nick automatically
- Handle enforcement notices — re-identify automatically
- Email verification support — notifies admins, `!bot confirm <code>` command
- Set GREET and HIDE EMAIL in NickServ profile after identification

**Anope ChanServ integration:**
- Query `CS INFO` before attempting REGISTER (never blindly re-registers)
- Auto-register managed channels after NickServ identification
- Set SUCCESSOR for level-100 access list entries
- AOP/SOP/HOP/VOP access list applied on setup
- Topic management: set on join if blank, respect admin-set topics, resume on clear
- AI-generated rotating topic (configurable interval, falls back to static)
- `KEEPTOPIC` and `SECURE` channel settings

**CTCP (send and receive):**
- Responds to incoming VERSION, PING, TIME, FINGER requests
- Unknown CTCP types silently ignored

**Security:**
- Per-user rate limiting with escalating warn → temp-ignore consequences
- Token-bucket output queue (never floods the network)
- Bounded `ThreadPoolExecutor` (max concurrent API calls)
- Input sanitisation: CRLF injection, IRC control codes, length cap
- Prompt injection defence: hardened system prompt + XML-wrapped user messages
- Permanent ignore list with wildcard hostmask support

**Admin commands (`!bot`):**
- Nick: `status`, `ghost`, `recover`, `confirm`
- Channel: `op`, `deop`, `voice`, `devoice`, `kick`, `ban`, `unban`
- Topic: `topic <text|refresh|interval>`
- ChanServ: `register`, `setup`, `access add/del/list`, `akick add/del`
- Security: `ignore`, `unignore`, `ignorelist`, `ratelimit reset`
- Admins: `addadmin`, `deladmin`, `adminlist`

**Privacy:**
- One-time privacy notice sent to new channel joins (configurable quiet period)
- Notice explains Anthropic API data processing
- Respects 30-second quiet period after bot joins to avoid startup flood

**Infrastructure:**
- Configurable for any IRC network (not just 2600net)
- `[network]` config section for network name used in system prompt and self-description
- Fernet-encrypted NickServ password in config.ini
- Interactive `install.sh` wizard (Ubuntu 22.04+ / Debian 11+)
- `uninstall.sh` for clean removal
- Independent Python venv (PEP 668 compliant)
- systemd service with restart-on-failure
- Persistent `!bot addadmin` / `!bot deladmin` — writes back to config.ini
