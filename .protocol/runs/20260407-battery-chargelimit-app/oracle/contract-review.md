# Oracle Contract Review

## Verdict: hold

## Findings

- 1. **plist write after-effect mechanism is still unproven.** Local evidence shows:
  - `pmset` has a `touch` subcommand, but `man pmset` does not explain what it refreshes.
  - `/usr/bin/pmset` contains the string `touching prefs file on disk...`.
  - `powerd` contains charging-related symbols such as `ChargeCtrlPolicy`, `soclimit`, `com.apple.private.powerd.chargeCtrlQ`, and `com.apple.powerd.charging`.

  None of that proves that `pmset touch` reloads `/Library/Preferences/com.apple.powerd.charging.plist`, and none of it proves that SIGHUP or an IOKit notification is the right trigger. The contract currently bakes an unverified reload path into the service boundary. That is too early. This needs to stay an explicit experiment gate until there is evidence that a write becomes visible in `pmset -g battlimit` without logout, reboot, or manual UI interaction.

- 2. **`owner = 177` is observed, not explained, and the current contract over-interprets it.** The decoded plist policy shows `owner = 177`, but the live runtime view from `pmset -g battlimit` currently shows two effective entries, one with `chargeSocLimitOwner = 177` and another with `chargeSocLimitOwner = 0`. That means the "177 = System Settings UI identifier" claim is not established enough to hardcode as a semantic truth. At minimum:
  - the app cannot assume a single-policy world,
  - the app cannot assume `owner = 177` is the only value that matters,
  - the app should preserve observed private fields unless and until creation semantics are verified.

  The contract should treat `owner` as an opaque private field and define how existing policy state is preserved, merged, or replaced.

- 3. **The root-privilege story is underspecified and the current file scope is incomplete.** A menu bar GUI cannot rely on an ad hoc `sudo` flow. The contract needs an explicit privileged boundary:
  - unprivileged SwiftUI menu bar app,
  - privileged helper/daemon that owns the file write,
  - narrow IPC/XPC API from UI to helper,
  - validation in the helper so only supported charge-limit operations are allowed.

  Apple platform headers also matter here. `SMAppService.h` says LaunchDaemons registered this way require admin approval in System Settings, and apps containing LaunchDaemons must be notarized. It also recommends `/Applications` placement if the daemon must be available before login. `ServiceManagement.h` exposes privileged helper and system daemon modification rights. So the present contract is missing a whole subsystem in both architecture and file scope. A `LaunchAgent` alone is not enough to write a root-owned file under `/Library/Preferences/`.

- 4. **Acceptance Criteria are not sufficient yet.** The existing criteria prove only the happy path. They miss several things that are contract-level, not polish:
  - whether the change takes effect without logout/reboot,
  - whether `100%` means "explicit `soclimit = 100` policy" or "remove limit entirely",
  - preservation of unknown top-level plist keys such as `bootSessionUUID`,
  - preservation of root ownership, permissions, and atomic replacement semantics,
  - behavior when authorization is denied, helper install fails, helper approval is missing, or the OS build is unsupported,
  - behavior when System Settings changes the same value while the app is running,
  - behavior across sleep/wake, clock change, timezone change, and login restart.

  There is also a more basic contract gap: the current "Timer-based 요일별 자동 전환" is too weak by itself for a battery control app. Sleep/wake and missed deadlines must be part of the scheduler design, otherwise the chosen limit can silently drift from the intended schedule.

- 5. **There are missing technical risks.**
  - Private schema drift: this is a private plist and private archive schema, so 26.4.x or 26.5 may change behavior.
  - Archive fidelity risk: the checked local encoding script currently decodes and re-encodes semantically, but does not byte-match the live archive (`557 bytes` vs `511 bytes`). That means the contract should not assume "same fields" automatically means "same archive behavior".
  - Token semantics risk: `token` exists, but the contract does not say whether to preserve the existing token or mint a new one.
  - Concurrent write risk: System Settings and the app may race on the same file.
  - Unsupported distribution risk: App Store/sandbox is already out of scope, but notarization and helper approval are still operational constraints and should be named.
  - Recovery risk: if a write succeeds but the reload path fails, the app needs a defined degraded state rather than reporting success prematurely.

## Required Changes (hold/reject 시)

- Add a **privilege architecture section** to the contract. Minimum acceptable structure:
  - unprivileged menu bar app,
  - privileged helper/daemon for plist mutation,
  - explicit IPC boundary,
  - no direct `sudo` shelling from the GUI,
  - helper validates allowed limits and preserves file ownership/perms.

- Expand **Files In Scope** to include the privileged side:
  - helper target or daemon target,
  - XPC protocol/shared types,
  - launchd plist or `SMAppService` registration assets,
  - install/approval flow code.

- Replace the current reload wording with a **gated requirement**:
  - "the implementation must prove the minimal write-to-visible trigger",
  - verify which trigger makes `pmset -g battlimit` reflect the change,
  - reject any implementation that requires reboot/logout/manual System Settings refresh.

- Reword `owner` and `token` as **opaque persisted fields** until stronger evidence exists. The contract should default to preserving existing values on update and explicitly define behavior for first-write creation.

- Tighten the `100%` semantics. Pick one and verify it:
  - remove the policy to express "no limit", or
  - keep a policy with `soclimit = 100`.

  The current acceptance criteria allow both outcomes, which makes the contract ambiguous.

- Strengthen Acceptance Criteria with at least these checks:
  - after applying a limit, `pmset -g battlimit` reflects it within a defined timeout,
  - unknown plist keys are preserved,
  - file remains root-owned with expected permissions,
  - the app surfaces failure when helper approval/auth is missing,
  - schedule is reconciled correctly after sleep/wake, app relaunch, and day rollover,
  - external changes from System Settings are detected and reconciled.

- Add explicit risk notes for:
  - private schema drift,
  - archive fidelity mismatch,
  - concurrent writes,
  - helper approval/notarization requirements,
  - fallback behavior when reload is not observed.
