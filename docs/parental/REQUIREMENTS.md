# Local LG parental control: requirements

Status: proposed for review; planning only. Research date: 2026-10-23.
Repository: https://github.com/fellrock/free-my-tv; inspected HEAD:
`4d739516379976e4cc256e4106f3680d6bb94da8`.
Read [ARCHITECTURE.md](ARCHITECTURE.md) for capability evidence and technical decisions,
and [PLAN.md](PLAN.md) for milestones and validation. These documents are sufficient
handoff context; parental-control implementation and its physical-TV tests have not started.
The user has installed the existing LG launcher on a physical TV; that installation does
not validate SSAP parental-control capabilities.

## Goal and scope

Add an independent parental-control subsystem to this fork without moving or rewriting
Free My TV. Run continuously on an Ubuntu Server using Docker Compose/Portainer, with
an authenticated mobile Vue PWA. The service, rather than the PWA or launcher, owns
time accounting and enforcement. Closing either UI must have no effect on enforcement.

First release: one household, one LG TV, one shared parent administrator, one policy
per device; schema uses device IDs so additional devices need no redesign. There is
no reliable identification of who is watching: all powered-on use, including HDMI,
counts. Child profiles, cross-TV household budgets, remote Internet administration,
cloud notifications, native PIN management, automatic wake-up and Android/Samsung
parental control are outside the first release. Existing launchers remain supported.

Runtime must work without Internet, cloud accounts, subscriptions, Home Assistant,
or external database. Initial dependency/image acquisition may require Internet;
provide an image export/import path for an offline server. Local HTTPS certificates
and assets must not depend on external CDNs, fonts or ACME services.

## Functional requirements

### TV interface preferences (follow-up)

The parent plans further TV environment changes to improve responsiveness; specific
changes and performance targets remain unspecified. Coordinate any later launcher
work with those changes and measure startup/navigation performance before and after.
No TV settings changes are authorized or performed by this planning update.

For the optional customized TV interface, omit cryptocurrency monitoring. The only
financial display of interest is USD/BRL foreign exchange, provisionally labelled
`1 USD = X BRL` (Brazilian reais per US dollar); confirm the quote direction before
implementation. This is fiat exchange data, not a cryptocurrency or stablecoin pair.
Treat it as a separate optional launcher enhancement, outside the parental-control
backend. Live rates require an external data source and Internet access; no provider
has been selected or validated. Show the rate timestamp and stale/unavailable state,
and keep parental enforcement fully functional without it or Internet access.
Existing upstream crypto functionality remains unchanged by this planning task.

| ID | Requirement and acceptance intent |
| --- | --- |
| F01 | Configure zero or more allowed windows per weekday in an explicit household IANA timezone. An empty day denies viewing. Support overnight windows. |
| F02 | Enforce a maximum session viewing duration and a mandatory cooldown; brief power cycling must not reset the allowance. |
| F03 | Enforce accumulated daily usage independently of session allowance. |
| F04 | Warn before the earliest applicable cutoff (window, session, daily budget or override expiry), default at 5 minutes and 1 minute. Unsupported/failed notifications must be visible and must not postpone enforcement. |
| F05 | When disallowed viewing is observed, request normal TV standby through the adapter. Never cut mains power or repeatedly force a panel-maintenance action. |
| F06 | Reconnect and reevaluate on every observed power-on, including after a shutdown, server restart or network recovery. Do not auto-wake the TV to enforce. |
| F07 | An authenticated parent can add bounded extra time or authorize a temporary exception, with explicit scope, expiry, reason and audit record. No permanent hidden bypass. |
| F08 | Show current observation, its age, connection/pairing state, active restrictions, effective remaining time, next boundary, pending shutdown and enforcement failures. |
| F09 | Show local-day history with observed and estimated usage separated, sessions, overrides, policy changes and command outcomes. Export/delete household data under parent authorization. |
| F10 | Persist accounting, cooldown progress, policy versions, warnings, command intent and overrides. Restart/reconnect cannot silently grant a new session or replay an expired override. |
| F11 | Mobile PWA supports setup, pairing, policy editing, status, history and overrides. Cached offline views show their timestamp; privileged changes require a live server. |
| F12 | Optional launcher integration displays status/warnings only; service operation and all enforcement remain independent. |

## Proposed time and accounting contract

These defaults require approval before implementing milestone 4. Durations are elapsed
seconds; scheduling uses local civil time. Examples below assume no override.

1. **Windows:** half-open `[start, end)`. At 18:00 a 16:00–18:00 window is closed.
   Overlapping/adjacent intervals merge. A Monday 22:00–Tuesday 01:00 window belongs
   to Monday's configuration but crosses into Tuesday's budget. Equal start/end is
   rejected, rather than implicitly granting 24 hours. Validate DST gaps/ambiguities:
   a window matches local clock readings, so skipped times do not occur and repeated
   times match both occurrences; daily/session duration still uses actual elapsed time.
2. **Viewing:** count confirmed active power states regardless of content. Treat screen-off,
   audio-only and unknown firmware states as potentially viewing unless the physical
   validation establishes a safe standby classification. An open socket or ping is
   insufficient. State evidence has a configurable freshness limit (initial 15 seconds).
3. **Session:** begins on observed active use. A confirmed off interval pauses viewing
   accumulation, but only a full cooldown ends/resets the session. Example: 30-minute
   session, 10-minute cooldown; after 20 minutes on, 2 minutes off and power-on, only
   10 minutes remain. After reaching 30 minutes, another session requires 10 continuous
   minutes of confirmed non-viewing. Off/on flapping never grants a new session.
4. **Cooldown:** accrues only over fresh, positively classified non-viewing observations.
   Loss of trustworthy observation interrupts that continuity and resets incomplete
   cooldown progress. An already completed cooldown/new-session eligibility persists;
   subsequent potentially active time starts/consumes that session. A sent shutdown or
   socket closure is not proof cooldown began. This may require a conservative manual
   reconciliation on TVs whose standby cannot be observed; see the approval gate below.
5. **Unknown/offline periods:** retain the last observation with its timestamp and expose
   current state as Unknown/Unreachable, never Off by inference. From the last fresh
   evidence until fresh evidence returns, conservatively charge potential viewing to
   both session and daily budgets, including server downtime. Store these intervals as
   estimated, not observed usage. No enforcement is possible during that gap. This
   deliberately favors restrictions over availability and can exhaust a budget when
   a TV was actually off. No charging before enrollment. Authorized corrections are
   audited adjustments, never rewriting raw observations. Approve this tradeoff or
   select an explicitly documented alternative after physical standby testing.
6. **Daily reset:** split intervals at local midnight into local-date buckets using the
   configured timezone (23/24/25-hour days are possible). Reset only daily allowance;
   sessions, cooldowns and unexpired overrides carry across midnight. Do not schedule
   a midnight job as the sole reset mechanism: derive buckets on accounting/recovery.
   Default timezone cannot be inferred from this conversation; ask during household setup.
7. **Clock/restart:** use monotonic elapsed time while running, persist UTC instants and
   checkpoints at most every 5 seconds and on transitions. Recover missing spans as
   uncertain intervals with idempotent boundaries. A forward clock jump is uncertain
   time; a backward jump cannot undo usage or reopen consumed allowance. Detect material
   wall/monotonic disagreement (>5 seconds); mark degraded until reconciled, charging
   uncertainty conservatively. Timezone changes require an explicit effective instant,
   preserve old buckets and cannot erase usage already charged; no retrospective rebucketing.
8. **Effective permission:** all restrictions must allow viewing. Compute the earliest
   cutoff and return every blocking reason. A policy edit takes effect immediately
   on the next evaluation; decreasing limits may require shutdown. Preserve historical
   policy versions. Default unconfigured policy denies, but automatic enforcement remains
   unarmed until pairing and a parent-reviewed policy are complete.
9. **Extra time:** a grant names device, current session ID, local budget date, additional
   session/daily seconds and an absolute expiry; it changes neither windows nor cooldown
   unless explicitly selected. An outside-window grant needs a separate explicit flag.
   A temporary unrestricted-viewing grant suspends named restrictions until its expiry;
   it still records usage. Consumption continues through midnight; unused daily extra
   expires with its named day. No banking/stacking by request retries. On expiry or
   revocation immediately reevaluate accumulated usage. Record parent, reason and scope.
10. **Warnings:** persist threshold crossing per session/effective cutoff/version; on
    late reconnect send at most the most urgent still-relevant warning, not a burst.
    Never send an obsolete warning after a deadline. Warning acknowledgement proves
    command acceptance only, not that a child saw it.

## Enforcement and availability contract

Proposed connected target: evaluate on events and at least every 1 second; with a
healthy paired connection, dispatch shutdown within 5 seconds of a known violation.
On observed reconnect/power-on, reevaluate before issuing any queued action. This is
a dispatch target, not a bound on physical screen shutdown or detection while offline.
Reconnect with jittered backoff 1–30 seconds and resubscribe/requery after registration.
Confirm these targets on the real TV and adjust documented limits based on evidence.

Every shutdown has distinct Requested, Accepted, ConfirmedStandby, Failed or Uncertain
outcomes. Socket loss immediately following a command leaves the outcome uncertain.
Use bounded retries (initial 3 attempts separated by at least 10 seconds), then surface
a fault and continue observation. A fresh observed active state creates a new enforcement
attempt after reevaluation, rate-limited to at most one command per 10 seconds. Persist
attempt state so restarts do not create a storm. Never auto-resend an old command before
checking current policy, override and state. Parent overrides can cancel queued commands;
a command already transmitted cannot be recalled.

No guarantee exists when the TV/server is off, pairing revoked, network disconnected,
state ambiguous or firmware denies an operation. A child can physically isolate the TV
from the server. Native parental locks, if parents configure them manually, are a
separate layer; do not claim this system is tamper-proof. A fake TV validates logic,
not LG firmware behavior. Do not use mains relays, smart plugs, screen-off commands,
private service menus or rooting as an enforcement fallback. Normal standby preserves
power for OLED maintenance; exact panel-cycle behavior requires model-specific validation.

## Security and data requirements

- Authenticate every administrative endpoint and SignalR connection. Health/liveness
  may be anonymous but must reveal no household/device data. No default password.
- Local first-run credential bootstrap via server console/one-use file, not an open LAN
  setup endpoint. Hash passwords with a maintained password hasher; throttle login and
  sensitive actions, expire/revoke sessions and require reauthentication for overrides,
  pairing, credential changes and exports. No four-digit PIN as the sole credential.
- Same-origin HTTPS, Secure/HttpOnly/SameSite cookies, CSRF protection for mutations,
  Origin checks for WebSockets, no broad CORS, no tokens in localStorage or URLs.
- Store pairing keys encrypted with an external persisted application key ring; restrict
  volume permissions. Exclude databases, backups, TLS material and keys from Git and logs.
  Host administrators remain trusted; volume encryption is not protection against root.
- Pair only after explicit parent initiation and on-TV approval. Validate private LAN
  targets and ports; no arbitrary URL/protocol proxy or general SSAP execution endpoint.
- Cache only static PWA assets. Authenticated API/history/status responses are no-store;
  clear local sensitive state on logout. Offline overrides cannot be queued and replayed.
- Default history retention: 90 days, configurable, with audit retention and deletion
  behavior documented. No titles or viewing-content collection needed for time control.
- One server instance and local-disk SQLite volume; no shared network filesystem, replicas,
  message broker, Kubernetes or distributed scheduler in the initial design.

## Decisions for explicit approval

| ID | Proposed decision | Why parent approval matters |
| --- | --- | --- |
| D1 | All use of the designated TV counts, independent of viewer/source. One shared household admin in v1. | Adult viewing also consumes the allowance unless an override is used. |
| D2 | Conservative uncertain-time charging and cooldown continuity rules above. | Can lock out an actually-off TV; standby observability may make this impractical. Physical-test gate before shipping. |
| D3 | Normal standby enforcement; reconnect is best effort with no offline guarantee. | Requires acceptance of unavoidable bypass/failure modes. |
| D4 | HTTPS with local certificate trust on parent phones; explicit opt-in for any legacy plaintext SSAP fallback. | Phone setup and LAN trust tradeoff. |
| D5 | Immediate policy enforcement and explicitly scoped, expiring overrides. | Determines whether a parent change interrupts current viewing. |
| D6 | 90-day local history retention. | Household privacy/storage preference. |

Approve these semantics before milestone 4 and real enforcement. The TV model and reported
versions are in the local-agent handoff; household timezone, connection and standby/Quick
Start+/Always Ready settings still need confirmation for the physical test. No credentials belong in review
comments, public docs or Git. Foundation and simulator work can proceed after architecture
review; uncertainty about real-TV capabilities must remain visible throughout.
