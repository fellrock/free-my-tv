# Local Windows agent handoff

The user wants to work in small parts, beginning with the existing LG TV interface.
Read the repository's `AGENTS.md` and `CLAUDE.md` first. Do not assume the parental
subsystem is implemented: the three adjacent documents are plans for a later stage.

## Current TV and installation

- The user reports that Free My TV installed and opened successfully on an LG OLED55C4PSA.
  They reported webOS version 11.2.0-3703 and software version 43.21.73; verify version
  terminology on the TV if compatibility depends on it.
- Their Windows computer can reach the Developer Mode Key Server and SSH ports. A cloud
  workspace could not reach those ports, so continue from the local Windows checkout.
- Developer Mode and Key Server were enabled. The installer saves a TV-specific SSH key
  under the user's `.ssh` directory. Preserve it, keep it out of Git, and do not request,
  print or save the TV's passphrase. If needed, let the user type it at the installer prompt.
- This confirms a launcher installation only. SSAP pairing, power-state observations,
  notifications, standby enforcement and OLED maintenance behavior remain unverified.

## Local update workflow

From the local repository root in PowerShell, first inspect local changes before pulling.
Do not overwrite the user's work. Once the requested code changes are present locally:

```powershell
.\webos\update-windows.ps1
```

The helper builds the current local code and invokes `install-windows.ps1` for the TV.
It uses `config.properties` if present; otherwise it builds with `--generic`. The generic
build selects location from the TV's time zone and contains no TMDB key. The Windows
helpers were authored in the cloud and have not themselves been tested on Windows; the
user reported success with the earlier manual installer workflow. Diagnose any helper
failure locally before retrying, and do not leak key material in diagnostics.

For a quick computer preview, run `py -3 webos/build.py --generic --preview` and open
`out\webos\index.html`. It uses sample apps; confirm the final layout and remote behavior
on the TV. Build the package again after edits before installing. An install updates and
opens the app on the TV; explain that action before doing it, per repository instructions.
Keep the existing Android, LG and Samsung builds working and run `tools/check.sh` where
its prerequisites are available; at minimum run the applicable LG build and web checks.

## User preferences and next work

- The user wants a faster TV experience but has not specified the exact changes or
  performance target. Inspect and measure before proposing or implementing optimizations.
- They do not want cryptocurrency monitoring in their customized interface. Their only
  financial interest is the USD/BRL exchange rate; confirm quote direction before adding
  it. A live rate is optional and needs a validated data source; it cannot become a
  dependency of local parental enforcement. Preserve upstream mergeability.
- Ask what TV interface change they want first; do not infer permission for unrelated
  changes. Continue with the independent parental-control service when the user directs.
  Proposed semantics D1–D6 remain for review, and real enforcement needs physical tests.

This directory is published by the existing GitHub Pages workflow. Do not add household
IP addresses, passphrases, keys, credentials or private viewing history to these documents.
