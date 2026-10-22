# Household Sequences Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement task-by-task.

**Goal:** Reusable ordered existing-card rounds with optional responsibility rotation and explicit incomplete handover.
**Architecture:** Pure sequence engine consumes live card confirmation token/order adapters; separate atomic JSON preserves legacy state and existing card side effects. Native SwiftUI and Compose share equivalent behavior.
**Tech Stack:** Foundation/SwiftUI, Kotlin/Compose, cached Gson2.11 tree codec for JVM JSON tests.
**Spec:** docs/superpowers/specs/2026-10-21-household-sequences.md

## Global Constraints
Preserve differing platform identities, original Pro/oldstorage/reminders/evidence/CloudKit/widget/release paths. Group configuration device-local with explicit disclosure. Root runs all compilers/tests/nativeUI/devices; source freeze during requested commands. No version bump/push/merge. DE/EN. Native Duo remains unverified.

## Review Focus
- Stale, out-of-order, ambiguous equal-order and expired confirmations must not produce a green sequence.
- Missing card blocks until explicit repair; repairs archive partial prior round.
- Rotation cannot erase an incomplete round or its handover.
- Corrupt/future data never resets; legacy file bytes remain untouched.
- Roster/name/duplicate-ID input rejects malformed configurations; disk failures retain UI state.

### Task1: Pure Swift sequence engine/archive
Files: Tests/main.swift, Tests/run-sequences.sh; new Domain/HouseholdSequence.swift.
- [x] Write deterministic behavior assertions for ordered prefix/stale baselines/ties, optional roster/rotation, pending handover, missing card/repair, actual disk restart/migration/corrupt/future and untouched legacy bytes.
- [x] Root `sh Tests/run-sequences.sh` observed missing-feature RED.
- [x] Implement SequenceCardState, SequenceStep, HouseholdSequence.progress/eligibleStepID/handover/nextRound/reconfigure, SequenceArchive.load/save with strict validation and atomic replacement.
- [x] Root repeat full core suite GREEN.

### Task2: iOS integration
Files: new Store/SequenceStore.swift, Views/SequencesView.swift; RootView tab, pbxproj and DE/EN strings.
- [x] Adapter uses live active card + latest CompletionEvent ID and ordered history index. Preserve old snapshot schema/widget writes; reuse existing complete and evidence capture callbacks.
- [x] Implement group editor/list/detail, ordered checks, missing-card/error handling, optional roster, handover with explicit remaining steps, archived rounds and guarded next round.
- [ ] Root compile main+widget and existing reset tests, native keyboard/photo/offline/CloudKit/widget/Duo acceptance; record limits.

### Task3: Android parity
Files: Tests HouseholdSequenceTest.kt; new HouseholdSequence.kt, SequencesUi.kt; MainTabs integration and Gson dependency.
- [x] Write deterministic JUnit equivalents plus store/error/failure protection; root Gradle RED before production.
- [x] Implement engine/archive/store with current Routine completedAt millisecond token/order, preserving prefs/history/Pro/photos/reset behavior.
- [x] Root full JVM suite GREEN; integrate equivalent native UI with existing completion/photo/Pro paths and saved draft state.
- [x] Root full suite+assembleDebug; independent source review; fix evidence-backed defects; commit only after verification.

### Task4: Handoff
- [x] Exact commits/files/test receipts, native QA instructions and truthful DE/EN metadata drafts under SchonErledigtUpdate. Preserve clean branch for root native/release work.

Root verification: late-event-green.log full Swift core PASS; native-release.log iOS main+widget build SUCCEEDED; android-release2.log full JVM suite+assembleDebug BUILD SUCCESSFUL39s. Independent peer-review.json no source P1/P2. Original XCTest/native interaction/Duo/store remain unverified; do not check the combined native acceptance item. Kotlin editor inference compile failure in android-release.log corrected with explicit List<String> state and verified in final run.
