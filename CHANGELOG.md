# Changelog

All notable changes to **Claude IRC Bot** are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [v3.2.1] — 2026-03-16

### Fixed

- **`!bot op/deop/voice/devoice` reply messages are no longer chatty.**
  Removed the `(NS:wait_identify, CS:False)` diagnostic suffix from success
  replies. The full routing path is still logged at INFO level for diagnostics.
  Replies are now simply `"OP nick done."` or `"MODE +v nick done."`.

- **Removed "IRC Connector" from default channel topic.**
  The default `[chanserv] topic` value was `"Anthropic AI - IRC Connector by 2600net"`.
  Changed to `"Claude AI Bot on 2600net"`. Existing installs with a custom
  `topic =` line in `config.ini` are unaffected.

---

## [v3.6] — 2026-03-16

### Fixed

- **`SET HIDE EMAIL` sent to NickServ on every reconnect.**
  Like the SOP/SUCCESSOR issue, `_ns_profile_done` was reset in `connect()`
  so profile setup re-ran each session.  `HIDE EMAIL` is a persistent
  NickServ account setting — it only needs to be sent once.

  Split into two flags: `_ns_profile_done` (resets on reconnect, controls
  `SET GREET` which is fine to refresh) and `_ns_hide_email_done` (persists
  for the process lifetime, `SET HIDE EMAIL ON` only sent on first
  identification after process start).

---

## [v3.5.1] — 2026-03-16

### Fixed (install.sh)

- **`secret.key` created as `root:root 600`** — the bot's service user could
  not read it, causing silent decryption failure and the bot running
  unidentified.  Key is now `root:$SYS_USER 640`, matching `config.ini`.

- **`StartLimitIntervalSec` and `StartLimitBurst` in `[Service]`** — these
  are `[Unit]` directives and were being silently ignored by systemd,
  generating a warning on every start.  Moved to `[Unit]`.

- **Default topic prompt said "IRC Connector"** — updated to "IRC Bot".

---

## [v3.5] — 2026-03-16

### Fixed

- **ChanServ access list (SOP/SUCCESSOR) applied on every reconnect.**
  The previous fix (persisting `_cs_setup_done` across reconnects) was
  reverted.  The correct fix is structural: `_cs_post_register` (which sends
  SOP/SUCCESSOR/etc.) is now only called from the fresh-REGISTER confirmation
  path.  When ChanServ INFO confirms a channel is *already* registered on
  connect or reconnect, the bot simply sets the channel state to `REGISTERED`
  and schedules topic rotation — the access list is never touched again.
  `_cs_setup_done` and `_cs_setup_lock` have been removed entirely.

- **Startup crash: `AttributeError: 'dict' object has no attribute 'lower'`**
  `config.get("bot", {}).get("admins", "")` was calling `ConfigParser.get()`
  with a dict as the second positional argument (which ConfigParser interprets
  as the `option` name, then calls `.lower()` on it).  Fixed to use standard
  section-existence guard: `config["bot"].get("admins", "") if "bot" in config`.

### Notes

- **systemd service file**: `StartLimitIntervalSec` must be in `[Unit]`, not
  `[Service]`.  Move it manually if you see the "Unknown key name" warning.
  See README for the correct service file layout.

---

## [v3.4] — 2026-03-16

### Fixed

- **`!bot access list` now relays the output to the requester.**
  Previously ChanServ sent the access list back as NOTICE messages to the
  bot, which silently discarded them, leaving the admin with only "check your
  notices" and nothing to check.  The command now registers the requester in a
  pending-request map; `_handle_chanserv_notice` detects the access list lines
  and forwards each one to the correct nick/channel until ChanServ sends the
  "End of access list" terminator.

---

## [v3.3] — 2026-03-16

### Fixed

- **NickServ identification success patterns widened.**
  The previous pattern set missed several common Anope 2.0 response variants,
  including the most common one on 2600net: `"You are now identified for <nick>."`.
  Added: `"you are now identified"`, `"identified for"`, `"now identified"`,
  `"you have identified"`, `"password correct"`.

- **Enforcement handler guards against missing password.**
  If `[nickserv] password` is absent from config, the enforcement notice handler
  now logs a clear warning instead of sending a blank `IDENTIFY` to NickServ.

### Added

- **Unhandled NickServ notice warning.**
  Any NickServ notice received while `_ns_state == WAIT_ID` that doesn't match
  a known pattern is now logged at `WARNING` level with the exact message text.
  This surfaces in `journalctl` without needing debug mode, making future
  identification failures trivially diagnosable.

---

## [v3.6] — 2026-03-16

### Fixed

- **`SET HIDE EMAIL` sent to NickServ on every reconnect.**
  Like the SOP/SUCCESSOR issue, `_ns_profile_done` was reset in `connect()`
  so profile setup re-ran each session.  `HIDE EMAIL` is a persistent
  NickServ account setting — it only needs to be sent once.

  Split into two flags: `_ns_profile_done` (resets on reconnect, controls
  `SET GREET` which is fine to refresh) and `_ns_hide_email_done` (persists
  for the process lifetime, `SET HIDE EMAIL ON` only sent on first
  identification after process start).

---

## [v3.5.1] — 2026-03-16

### Fixed (install.sh)

- **`secret.key` created as `root:root 600`** — the bot's service user could
  not read it, causing silent decryption failure and the bot running
  unidentified.  Key is now `root:$SYS_USER 640`, matching `config.ini`.

- **`StartLimitIntervalSec` and `StartLimitBurst` in `[Service]`** — these
  are `[Unit]` directives and were being silently ignored by systemd,
  generating a warning on every start.  Moved to `[Unit]`.

- **Default topic prompt said "IRC Connector"** — updated to "IRC Bot".

---

## [v3.5] — 2026-03-16

### Fixed

- **ChanServ access list (SOP/SUCCESSOR) applied on every reconnect.**
  `_cs_post_register` (which sends SOP/SUCCESSOR) was being called whenever
  ChanServ confirmed a channel was registered — including on reconnect when
  the channel was already registered from a previous session.

  The ChanServ notice handler now has two distinct paths:
  - **INFO reply → channel already registered**: set state, schedule topic
    rotation only. Access list is not touched.
  - **REGISTER confirmed → channel freshly registered by the bot**: call
    `_cs_post_register` and apply SOP/SUCCESSOR once.

  The "already registered" safety-net path (when REGISTER is attempted on
  an already-owned channel) also takes the no-access-list path.

- **Startup crash: `AttributeError: 'dict' object has no attribute 'lower'`**
  `config.get("bot", {}).get("admins", "")` was calling `ConfigParser.get()`
  with a dict as the second positional argument. Fixed to
  `config["bot"].get("admins", "") if "bot" in config`.

### Notes

- **systemd service file**: `StartLimitIntervalSec` must be in `[Unit]`, not
  `[Service]`.  Move it manually if you see the "Unknown key name" warning.

---

## [v3.4] — 2026-03-16

### Fixed

- **`!bot access list` now relays the output to the requester.**
  Previously ChanServ sent the access list back as NOTICE messages to the
  bot, which silently discarded them, leaving the admin with only "check your
  notices" and nothing to check.  The command now registers the requester in a
  pending-request map; `_handle_chanserv_notice` detects the access list lines
  and forwards each one to the correct nick/channel until ChanServ sends the
  "End of access list" terminator.

---

## [v3.3] — 2026-03-16

### Fixed

- **Encrypted NickServ password not being decrypted on startup.**
  Two separate decryption systems existed with different key file paths
  (`secret.key` vs `.keyfile`) and different prefix conventions (`enc:` vs
  `ENC:`).  `_decrypt_password()` was also defined before the logging system
  was initialised, so any key-file errors were silently swallowed — the
  password became an empty string and the bot started unidentified with no
  explanation in the logs.

  Both systems are now consolidated: logging is initialised first, a single
  `_KEY_FILE = /etc/claude-irc-bot/secret.key` is used, `_decrypt_value()`
  accepts both `enc:` and `ENC:` prefixes (case-insensitive), and all error
  paths produce visible log output at ERROR level.  `load_config()` decrypts
  secrets before handing the config to the bot, so `__init__` just reads a
  plain string.

- **NickServ enforcement handler would attempt `IDENTIFY` with empty password.**
  If the password was missing or failed to decrypt, the enforcement notice
  handler still sent `IDENTIFY` with an empty string. It now checks for an
  empty password first and logs a clear error instead.

---

## [v3.2] — 2026-03-16

### Fixed

- **`!bot op/deop/voice/devoice` commands now actually work.**
  Previously all four commands unconditionally routed through ChanServ,
  causing them to fail silently (or return "Password authentication required")
  whenever the bot was not identified or the channel was not registered.

- **`_cs_state` key consistency.**
  Channel names were stored in `_cs_state` with their original case in some
  code paths and as RFC 1459 lowercase in others, causing `CS.REGISTERED`
  lookups to silently miss. All writes now normalise through `_irc_lower()`.

- **ChanServ "password authentication required" now triggers re-identification.**
  When ChanServ rejects a command because the bot is not identified,
  `_handle_chanserv_notice` now catches that notice and re-sends
  `NICKSERV IDENTIFY` automatically.

### Added

- **`_chan_mode(channel, modechar, nick)` helper.**
  Centralises all channel mode routing logic. Priority:
  1. Identified to NickServ **and** channel registered with ChanServ → `CS OP/DEOP/VOICE/DEVOICE`
  2. Bot has ops in the channel → direct `MODE` command
  3. Neither available → descriptive error message sent back to admin

  The admin reply now tells you which path was taken and why, making
  future debugging trivial without needing to check logs.

---

## [v3.1] — initial public release

- Claude AI responses (direct addressing and `!claude` trigger)
- Full Anope NickServ integration: auto-register, identify, ghost, recover,
  enforcement handling, email verification flow
- Full Anope ChanServ integration: auto-register channels, xOP access list,
  akick, topic management
- NickServ profile enrichment (GREET, HIDE EMAIL)
- AI-generated rotating channel topic with configurable interval
- CTCP support: VERSION, TIME, PING, FINGER, SOURCE, USERINFO, CLIENTINFO
- Per-user rate limiting with escalating warn → temp-ignore
- Token-bucket output queue (prevents bot flood)
- Bounded `ThreadPoolExecutor` for API calls
- Input sanitisation: CRLF injection, IRC control codes, length caps
- Prompt-injection defence (XML-wrapped user messages)
- Permanent ignore list with wildcard hostmask support
- Live admin command system (`!bot`) with 20+ subcommands
- Privacy notice for new channel members (configurable quiet period)
- Fernet-encrypted password support in config
- `!bot model` — live model switching, saved to config
- `!bot addadmin` / `!bot deladmin` — runtime admin management
- TLS-only connections (port 6697 default)
- systemd service with auto-restart and install/uninstall scripts
- Configurable for any IRC network; default: 2600net (`irc.scuttled.net`)
