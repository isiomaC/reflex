# Reflex priorities

Updated: 2026-09-25

## Current state

The core loop is present: privacy-bounded local context → live Jev decision → SwiftData Inspector history → one-off or ten-run replay. The next work should close the gaps that keep this from being a complete experimentation tool, then harden the finished product.

## P0 — Complete the Replay Lab experiment loop

**Why first:** This is the largest remaining MVP gap. Replay currently reuses a stored sanitized snapshot, but it cannot yet test an intentionally changed state or present an A/B comparison.

- [ ] Add an editable synthetic-state form for the allowed fields only: app name, bundle identifier, window title, clipboard sample, and recent application list.
- [ ] Preserve the stored record as immutable State A; build the edited synthetic snapshot as State B and label it clearly in the UI.
- [ ] Show original versus new activity/action probability distributions and a per-option delta table.
- [ ] Add a regression test that proves edits create a new replay input without modifying the stored `DecisionRecord`.

**Done when:** a user can select an Inspector record, alter safe synthetic fields, replay it, and see State A / State B / delta values in one screen.

## P1 — Make long replay batches safe and understandable

**Why next:** The runner validates 1–100 requests and runs sequentially, but the app has no cancel control and no explicit acknowledgement before a costly 100-run batch.

- [ ] Add a cancellable replay task owned by `AppModel`; expose a Cancel button while a batch is active.
- [ ] Keep progress visible and clear partial results when cancellation occurs.
- [ ] Offer 10 runs by default; require an explicit confirmation dialog before 100 runs.
- [ ] Surface live-provider failures (missing key, offline, timeout, rate limit, authentication) directly in Replay Lab.
- [ ] Add tests for cancellation, confirmation gating, and error presentation state.

**Done when:** a user can start, monitor, cancel, and safely opt into a 100-run sequential experiment without the UI becoming unresponsive.

## P2 — Finish Inspector completeness

**Why next:** Inspection works, but one advertised Phase 4 capability is only implemented internally.

- [ ] Add a user-facing **Copy sanitized JSON** action for the selected record, backed by existing `DecisionRecord.exportJSON()`.
- [ ] Add visible probability distributions to the Inspector detail pane instead of showing only selected outcomes.
- [ ] Add filtering for result/error state if error records are introduced; keep activity filtering.
- [ ] Add tests that exported/copied data never includes API keys, app names, window titles, or clipboard text.

**Done when:** every stored decision can be read, visually understood, safely copied, replayed, and compared without inspecting source code or a database.

## P3 — Phase 6 hardening and demo readiness

**Why next:** Do this after the remaining product behavior is complete to avoid repeatedly redoing screenshots, accessibility work, and performance measurements.

- [ ] Run the full unit suite after every completed priority; add UI-level coverage for navigation, Inspector selection, Replay handoff, and clear history.
- [ ] Perform a keyboard and VoiceOver pass for Lens, Inspector, Replay Lab, Settings, and menu-bar controls.
- [ ] Run Instruments/Time Profiler while capturing context, loading a full 200-record history, and running a 10-request replay batch; record actionable findings.
- [ ] Perform a privacy review against the actual serialized payload and local SwiftData records.
- [ ] Refresh README to describe current Phase 5 capabilities, build/run scripts, live-key setup, privacy limits, and replay boundaries.
- [ ] Capture screenshots and write a five-minute demo script: capture → inspect → replay → compare → clear history.

**Done when:** a new developer can clone, build, test, understand privacy guarantees, and demonstrate the complete loop confidently.

## Deferred after MVP

- Automatic desktop actions, browser automation, shell execution, OCR, screenshots, keylogging, cloud sync, accounts, team collaboration, and iOS support remain out of scope.
- Do not add model calibration claims; repeat-run figures are empirical stability measurements only.

## Recommended next slice

Start P0 with immutable State A / editable State B and the A/B delta table. It unlocks the central value proposition of Reflex and makes the existing replay engine visibly useful.
