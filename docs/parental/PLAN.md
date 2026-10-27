# Implementation plan and continuation guide

Status: architecture review draft, 2026-10-23. This task adds only these three planning
documents; no parental-control implementation exists. Read [REQUIREMENTS.md](REQUIREMENTS.md)
for behavior/decisions D1–D6 and [ARCHITECTURE.md](ARCHITECTURE.md) for layout, evidence,
security boundaries and the physical OLED checklist. Preserve root AGENTS.md/CLAUDE.md
and existing launcher/build paths. Use the existing checkout. Each milestone should be
a small independently reviewable change or a few narrowly scoped commits.

## Validation conventions

Existing commands, from repository root:

```sh
# Prepared cloud workspace only; other machines configure JDK/SDK normally:
. /workspace/.setup/env.sh
./build.sh
tools/check.sh
git diff --check
```

All four commands passed for this documentation task. Android built/signed, 192 translation
keys validated, LG/Samsung packaging and ES5 checks passed. The Java compiler reported its
existing deprecated-API note. These checks do not validate parental-control behavior.
`build.sh` clears out/; regenerate previews afterwards. Preserve local settings/signing keys.

**Every parental/ command below is a proposed acceptance command for future files. None
is runnable or verified yet.** Create the named projects/scripts at the relevant milestone
or update this document when names change. Tests must fail on absent/zero tests, preserve
exit status, use fake time and isolated data, and never contact a real TV by default.

## M1 — Repository analysis and architecture (this task)

Deliverables: these documents, additive directory tree, capability evidence matrix,
time/accounting contract, risks, hardware gate and explicit approval decisions.

Acceptance: root instructions and Android/LG/Samsung code remain unchanged; source-backed
capabilities are distinguished from physical evidence; official-documentation access gaps
are disclosed; no implementation or enforcement claims. Public docs contain no household
IPs, keys or personal data (docs/ is included in the existing Pages publication workflow).

Validation: existing commands above, relative-link checks, inspection of the three new
Markdown files and `git status --short`. No new implementation tests for documentation.

**Stop for architecture review here.** Do not proceed to M2 or send physical TV commands
without the next authorized task. D1–D6 require review; behavior decisions must be settled
before implementing their semantics and arming real enforcement.

## M2 — Monorepo foundation and development environment

Create the minimal Core/Infrastructure/Server .NET projects and test projects, independent
Vue 3/TypeScript PWA shell, version pins, npm/NuGet locks, local-data ignores and separate
parental CI. No root Node workspace or launcher dependency on .NET. Add typed status,
TimeProvider plumbing, configuration validation and secure local admin bootstrap. Keep
enforcement unarmed. Proposed tools: .NET 10 LTS and Node 24 LTS; pin exact supported
versions after testing restore/package compatibility. Verify Docker daemon permissions
and native SQLite assets on Ubuntu x64; claim arm64 support only after testing.

Acceptance: repeatable restore/build/type-check and meaningful host/auth smoke tests;
unauthenticated household access denied, deterministic clock available; upstream checks
still need only upstream tools. Document local startup and data/secret paths in README.

```sh
dotnet restore parental/Parental.sln --locked-mode
dotnet build parental/Parental.sln --no-restore
dotnet test parental/Parental.sln --no-build
npm --prefix parental/ui ci
npm --prefix parental/ui run typecheck
npm --prefix parental/ui run build
```

## M3 — webOS adapter and simulated TV integration

Implement ITvAdapter with explicit pairing, protected key-store handoff, correlated bounded
requests, state snapshots/subscriptions, toast, standby and reconnect. Build a scripted
loopback WebSocket fake. Test malformed responses, unsupported endpoints, permission
errors, revoked keys, lost acknowledgements, stale connection generations and duplicates.
Prefer pinned WSS; test certificate mismatch and prohibit silent plaintext downgrade.

Acceptance: real protocol traffic to the fake, not just mocked adapter methods; deterministic
freshness/Unknown mapping, backoff and subscription recovery. No general-purpose SSAP
proxy. Required controls must work with a minimal honest manifest, never copied LG test
identities. Default tests must not discover/pair household TVs.

```sh
dotnet test parental/tests/Parental.WebOs.Tests
```

Hardware spike: only after parent authorization, run ARCHITECTURE's OLED checklist and
record sanitized model/firmware results. Review currently inaccessible official docs and
model maintenance manual. Standby observability is a release gate: if it cannot sustain
confirmed cooldown, revisit D2 explicitly. Do not silently treat disconnect as standby.
M4 simulator development can proceed after semantics approval; deployment cannot bypass
the hardware gate.

## M4 — Policy engine and session tracking

After D1/D2/D5 approval, implement pure policy evaluation, usage interval accounting,
session/cooldown transitions, timezone/DST handling, daily buckets, uncertainty, warning
deadlines, scoped overrides and policy changes. No I/O or system-clock reads in domain
logic. Snapshots must round-trip before connecting the database.

Acceptance: all time scenarios below pass at exact boundaries. Splitting intervals and
replaying observations cannot alter charged usage; no negative durations, duplicate
allowances or unbounded override retries. Return every blocking reason and next deadline.

```sh
dotnet test parental/tests/Parental.Core.Tests
```

## M5 — Web API, persistent storage and autonomous worker

Implement versioned SQLite migrations, atomic interval/checkpoint updates, per-device
serialization, scheduling, durable command intent/outcomes, bounded retries, API/hub
authorization and audit. Complete CSRF, rate limits, reauthentication and Data Protection
key persistence. Arming requires paired capabilities, reviewed policy and explicit parent
action. No default password/open LAN bootstrap or sensitive health/log payloads.

Acceptance: integration tests use real temporary SQLite plus fake TV; crash before/after
send/ack causes neither double charging nor command storms. Recovery cancels stale work
against fresh policy/observations. Disk-full/corruption/migration failure shows degraded
status without empty replacement budgets. Worker operates without UI/launcher clients.
Test hub Origin/auth, CSRF, target SSRF prevention, idempotent grants, write revision
conflicts and exclusive startup lock against a second instance sharing the volume.

```sh
dotnet test parental/tests/Parental.Integration.Tests
```

## M6 — Mobile PWA

Build enrollment/pairing, weekday windows, limits, status freshness, remaining allowance,
restriction reasons, warning/enforcement failures, grants, history and admin credential
management. Confirm D4/D6. Use same-origin HTTPS, cookie authentication and SignalR
resnapshot after reconnect. Cache static assets only; offline views show timestamps and
cannot queue administrative mutations. Never require background push/open UI to enforce.

Acceptance: mobile and accessible keyboard flows; expired auth requires login; logout
clears household state; stale hub messages cannot replace newer snapshots; installed
PWA works on a real phone with trusted local CA and no Internet. Test credential and
override authorization separately from successful UI rendering.

```sh
npm --prefix parental/ui run typecheck
npm --prefix parental/ui run test:unit -- --run
npm --prefix parental/ui run build
npm --prefix parental/ui run test:e2e
```

Define test:e2e to start isolated backend/fake TV/temp DB, not household data. Cover
login, policy/grant flows, offline restrictions, logout, reconnect and revision recovery.

## M7 — Docker deployment and integration tests

Add multi-stage non-root image, local HTTPS proxy, Compose/Portainer instructions,
local named volumes for DB/key ring/CA, health checks and backup/restore. No privileged
mode, host networking, Docker socket or multicast discovery requirement. Publish only
intended LAN HTTPS. Explain local hostname/certificate trust, proxy headers, volume
permissions, resource limits, stop grace period and migration rollback.

Portainer baseline: standalone Compose on a single Docker host, not Swarm. Build/tag or
load images before importing the stack; do not depend on Portainer building an arbitrary
local path. Pin release images and document export/import for offline servers. No NFS/SMB
SQLite volume or multi-replica service. Preserve secrets outside committed env files.

Acceptance: test through production TLS proxy with PWA closed, backend killed/restarted,
TV network lost, outbound Internet denied and backup restored with key ring. Test
readiness/degraded behavior and repeated on/off enforcement. Record actual Portainer
version/import results. Finish authorized physical OLED test with mains continuously
supplied; fake-TV tests alone do not establish compatibility.

```sh
docker compose -f parental/deploy/compose.yaml config -q
docker build -f parental/deploy/Dockerfile -t free-my-tv-parental:test parental
bash parental/scripts/test-compose.sh
```

The integration script must create a unique project, fresh test volumes/credentials and
fake TV, enforce bounded readiness/behavior assertions, preserve failure logs and clean
up only its own resources. Never run destructive integration checks on household volumes.

## M8 — Optional Free My TV UI integration

Follow-up interface preference: the customized TV UI should omit crypto monitoring.
If financial data is added, scope it separately to optional USD/BRL fiat exchange
rates; confirm quote direction and choose/validate a source before implementation.
Display timestamp/staleness and tolerate no Internet without affecting enforcement.
Coordinate with the parent's planned TV performance changes once specified; measure
responsiveness rather than assuming an improvement. Do not remove upstream crypto
code or change TV settings as part of this architecture task.

After independent service acceptance, add opt-in ES5 status/countdown display to LG
launcher. Use revocable device-scoped read-only access, never parent credentials or SSAP
pairing tokens. Verify old-browser transport/Origin/certificate behavior; if unsupported,
leave it disabled rather than weakening admin security. Missing service must preserve
launcher behavior; closing/uninstalling launcher must not affect enforcement.

Acceptance: read-only token cannot mutate policy/read household history; Android/Tizen
remain intact. Validate upstream `tools/check.sh`, parental regression suites, ES5 browser
checks and authorized LG smoke test. Follow upstream translation rules for any new text.
This milestone is optional; it cannot be a prerequisite for core enforcement.

## Automated scenario matrix

| Area | Required coverage in M4/M5/M7 |
| --- | --- |
| Windows | Just before/exact start/exact end; empty days; overlap/adjacency; overnight/week rollover; invalid equal endpoints; DST gap/repeated times. |
| Session | Limit minus one second/exact limit; short off/on preserves balance; full confirmed cooldown resets; flapping; active session across midnight. |
| Cooldown | Exact completion; interruption by active/Unknown; partial restart; disconnect/sent standby never proof; completed eligibility persists without duplicate sessions. |
| Daily | Multiple sessions; earliest of window/daily/session cutoff; midnight splitting; 23/25-hour days; timezone changes cannot erase consumption. |
| Uncertainty | Drop while active and while previously off; server outage across days; screen-off/unknown raw states; no pre-enrollment usage; observed vs estimated history and audited correction. |
| Recovery | Duplicate observations; restart around checkpoints; crash before send/after send before outcome; retained warning/grant/policy; bounded retry across restarts. |
| Overrides | Exact scope/expiry/revocation; midnight; idempotent requests; concurrent policy change; usage still recorded; transmitted shutdown cannot be recalled. |
| Warnings | Earliest cutoff; shortened policy/added time; reconnect after thresholds; unsupported toast; no burst or overdue warning. |
| Enforcement | Remote/CEC power-on again; unreachable/revoked/permission-denied TV; retry limit; resubscription; no mains-control fallback. |
| Clock/store | Backward/forward jumps, drift degradation; DB locks/full disk/corruption; failed migration; DB plus key-ring backup/restore. |
| Security/PWA | Anonymous access, CSRF, hub auth/Origin, throttling, grant reauth, SSRF targets, certificate change, static-only cache, logout and stale revisions. |

## Current handoff

- M1 documents and upstream checks complete; all subsequent paths/commands are proposals.
- SSAP registration/toast/soft standby have implementation evidence. No physical TV tested.
- LG developer reference pages returned proxy 403; lifecycle/permission details and exact
  model's maintenance manual remain explicit verification tasks.
- D1–D6 await review. Household timezone/model/year/firmware/network settings are unknown.
- No TV contacted, no upstream code/instructions changed, no push/publication/deployment.
- Next authorized task should be M2, followed by M3 simulator and separately authorized
  hardware spike. Keep compatibility and offline-enforcement caveats visible.
