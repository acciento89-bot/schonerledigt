import Foundation

func check(_ value: Bool, _ name: String) { if !value { fatalError("FAIL: \(name)") }; print("PASS: \(name)") }
func rejects(_ name: String, _ action: () throws -> Void) { do { try action(); fatalError("FAIL: \(name)") } catch { print("PASS: \(name)") } }
let a = "00000000-0000-0000-0000-000000000001"
let b = "00000000-0000-0000-0000-000000000002"
let date = Date(timeIntervalSince1970: 1_800_000_000)
let steps = [SequenceStep(routineID: a, title: "Door"), SequenceStep(routineID: b, title: "Lights")]
func card(_ id: String, _ token: String?, _ order: Double?) -> SequenceCardState { SequenceCardState(id: id, title: id == a ? "Door" : "Lights", confirmationToken: token, confirmationOrder: order, confirmedAt: order.map { date.addingTimeInterval($0) }) }
let old = [card(a, "a0", 1), card(b, "b0", 2)]
var sequence = try HouseholdSequence(name: "Leaving home", steps: steps, people: ["Alex", "Sam"], cards: old, at: date)
check(sequence.progress(cards: old) == 0, "Previous card confirmations never count as a fresh round")
check(sequence.eligibleStepID(cards: old) == a, "Only first dependent step is eligible")
check(sequence.responsiblePerson == "Alex", "First roster person owns first round")
let wrongOrder = [card(a, "a1", 4), card(b, "b1", 3)]
check(sequence.progress(cards: wrongOrder) == 1 && sequence.eligibleStepID(cards: wrongOrder) == b, "Earlier external confirmation requires recheck after predecessor")
let equalOrder = [card(a, "a1", 4), card(b, "b1", 4)]
check(sequence.progress(cards: equalOrder) == 1, "Ambiguous equal order does not bypass dependency")
let first = [card(a, "a1", 3), card(b, "b0", 2)]
try sequence.handover(to: "Sam", note: "Please finish lights", cards: first, at: date.addingTimeInterval(10))
check(sequence.handovers.last!.pendingIDs == [b] && sequence.responsiblePerson == "Sam", "Incomplete handover persists exact remaining work and owner")
rejects("Incomplete round cannot be silently reset") { try sequence.nextRound(cards: first, at: date.addingTimeInterval(20)) }
let done = [card(a, "a1", 3), card(b, "b2", 5)]
check(sequence.progress(cards: done) == 2, "Chronological confirmations complete round")
try sequence.nextRound(cards: done, at: date.addingTimeInterval(30))
check(sequence.rounds.count == 1 && sequence.rounds[0].pendingIDs.isEmpty, "Completed round is retained")
check(sequence.responsiblePerson == "Sam" && sequence.progress(cards: done) == 0, "Next round rotates and excludes previous completion tokens")
check(sequence.eligibleStepID(cards: []) == nil, "Deleted card cannot be marked complete")
try sequence.reconfigure(name: "Leaving home", steps: [steps[0]], people: ["Alex"], cards: done, at: date.addingTimeInterval(40))
check(sequence.rounds.last!.pendingIDs == [a,b] && sequence.steps.count == 1, "Repair preserves incomplete prior round instead of erasing it")
rejects("Duplicate card cannot create a dependency loop") { _ = try HouseholdSequence(name: "Bad", steps: [steps[0],steps[0]], people: [], cards: [], at: date) }
rejects("Empty sequence rejected") { _ = try HouseholdSequence(name: "Bad", steps: [], people: [], cards: [], at: date) }
rejects("Ambiguous roster rejected") { _ = try HouseholdSequence(name: "Bad", steps: steps, people: ["Alex","alex"], cards: [], at: date) }
let unassigned = try HouseholdSequence(name: "Solo", steps: steps, people: [], cards: [], at: date)
check(unassigned.responsiblePerson == nil, "Rotation is optional")
let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: folder) }
let legacyURL = folder.appendingPathComponent("app-state.json")
let legacyBytes = Data("{\"legacy\":\"photos/reminders/cloud remain unchanged\"}".utf8)
try legacyBytes.write(to: legacyURL)
let archive = SequenceArchive(url: folder.appendingPathComponent("sequences.json"))
check(try archive.load().isEmpty, "First install starts without sequences")
try archive.save([sequence])
check(try SequenceArchive(url: archive.url).load() == [sequence], "Cold restart retains group/rotation/rounds/handovers")
check(try Data(contentsOf: legacyURL) == legacyBytes, "Existing app-state remains byte-identical")
let versionless = try JSONEncoder().encode([sequence]); try versionless.write(to: archive.url)
check(try archive.load() == [sequence], "Versionless sequence archive migrates without loss")
let broken = Data("{broken".utf8); try broken.write(to: archive.url)
rejects("Corrupt sequence file surfaces error") { _ = try archive.load() }
rejects("Corrupt sequence file cannot be overwritten") { try archive.save([]) }
check(try Data(contentsOf: archive.url) == broken, "Corrupt bytes preserved")
let future = Data("{\"schemaVersion\":999,\"sequences\":[]}".utf8); try future.write(to: archive.url)
rejects("Future schema is not replaced") { try archive.save([]) }
check(try Data(contentsOf: archive.url) == future, "Future bytes preserved")
print("ALL HOUSEHOLD SEQUENCE TESTS PASSED")

// Existing app snapshots store ISO8601 dates at whole-second precision. Distinct
// event identities and persisted history order must still distinguish a recheck.
let sameSecond = date.addingTimeInterval(100)
let routineA = RoutineItem(id: UUID(uuidString: a)!, title: "Door", symbol: "lock", tintHex: "000000", resetRule: .manual, completedAt: sameSecond, sortOrder: 0)
let routineB = RoutineItem(id: UUID(uuidString: b)!, title: "Lights", symbol: "lightbulb", tintHex: "000000", resetRule: .manual, completedAt: sameSecond, sortOrder: 1)
let eventA = CompletionEvent(routineID: routineA.id, routineTitle: routineA.title, symbol: routineA.symbol, tintHex: routineA.tintHex, completedAt: sameSecond)
let eventB = CompletionEvent(routineID: routineB.id, routineTitle: routineB.title, symbol: routineB.symbol, tintHex: routineB.tintHex, completedAt: sameSecond)
let live = SequenceCardAdapter.states(routines: [routineA,routineB], history: [eventB,eventA], at: sameSecond)
let fresh = try HouseholdSequence(name: "Fresh", steps: steps, people: [], cards: [], at: date)
check(fresh.progress(cards: live) == 2, "Same-second persisted history order retains dependency chronology")
check(live.first!.confirmationToken == eventA.id.uuidString, "Real completion identity is captured")
let reversedHistory = SequenceCardAdapter.states(routines: [routineA,routineB], history: [eventA,eventB], at: sameSecond)
check(fresh.progress(cards: reversedHistory) == 1, "Widget/card confirmation before predecessor needs recheck")
let noEvidence = SequenceCardAdapter.states(routines: [routineA], history: [], at: sameSecond)
check(noEvidence.first!.confirmationToken == nil, "Missing matching completion event is not invented")
var expires = routineA; expires.resetRule = .afterHours(1)
let expired = SequenceCardAdapter.states(routines: [expires], history: [eventA], at: sameSecond.addingTimeInterval(3600))
check(expired.first!.confirmationToken == nil, "Existing reset boundary keeps sequence pending")
print("ALL SEQUENCE CARD ADAPTER TESTS PASSED")

// An offline/shared snapshot may introduce an OLD completion identity that was
// not present when the round began. A fresh token alone is not a fresh check.
let lateA = CompletionEvent(routineID: routineA.id, routineTitle: routineA.title, symbol: routineA.symbol, tintHex: routineA.tintHex, completedAt: date.addingTimeInterval(-60))
let lateB = CompletionEvent(routineID: routineB.id, routineTitle: routineB.title, symbol: routineB.symbol, tintHex: routineB.tintHex, completedAt: date.addingTimeInterval(-30))
var oldRoutineA = routineA; oldRoutineA.completedAt = lateA.completedAt
var oldRoutineB = routineB; oldRoutineB.completedAt = lateB.completedAt
let lateOld = SequenceCardAdapter.states(routines: [oldRoutineA,oldRoutineB], history: [lateB,lateA], at: date)
check(fresh.progress(cards: lateOld) == 0, "Late-arriving old unknown completion IDs cannot satisfy a fresh round")
let fractionalStart = date.addingTimeInterval(0.8)
let fractionalGroup = try HouseholdSequence(name: "Precise", steps: steps, people: [], cards: [], at: fractionalStart)
oldRoutineA.completedAt = date.addingTimeInterval(0.2); oldRoutineB.completedAt = date.addingTimeInterval(0.4)
let fractionA = CompletionEvent(routineID: routineA.id, routineTitle: routineA.title, symbol: routineA.symbol, tintHex: routineA.tintHex, completedAt: oldRoutineA.completedAt!)
let fractionB = CompletionEvent(routineID: routineB.id, routineTitle: routineB.title, symbol: routineB.symbol, tintHex: routineB.tintHex, completedAt: oldRoutineB.completedAt!)
let fractionalOld = SequenceCardAdapter.states(routines: [oldRoutineA,oldRoutineB], history: [fractionB,fractionA], at: date.addingTimeInterval(1))
check(fractionalGroup.progress(cards: fractionalOld) == 0, "Pre-round confirmations in the same second are not rounded into valid work")
print("ALL LATE CONFIRMATION REGRESSIONS PASSED")

// Explicitly observed legitimate checks must survive the existing snapshot's
// whole-second ISO8601 encoding without admitting an unknown older event.
var precise = try HouseholdSequence(name: "Precise", steps: steps, people: [], cards: [], at: fractionalStart)
let actual = [SequenceCardState(id: a,title: "Door",confirmationToken: "actual-a",confirmationOrder: 1,confirmedAt: date.addingTimeInterval(0.85)), SequenceCardState(id: b,title: "Lights",confirmationToken: "actual-b",confirmationOrder: 2,confirmedAt: date.addingTimeInterval(0.9))]
check(precise.progress(cards: actual) == 2, "Real fresh same-second confirmations are accepted")
check(try precise.recordObservedConfirmations(cards: actual, at: date.addingTimeInterval(1)), "Exact new receipt identities are recorded from actual post-start observations")
let receiptsURL = folder.appendingPathComponent("precision.json")
try SequenceArchive(url: receiptsURL).save([precise])
precise = try SequenceArchive(url: receiptsURL).load()[0]
let truncated = [SequenceCardState(id: a,title: "Door",confirmationToken: "actual-a",confirmationOrder: 1,confirmedAt: date), SequenceCardState(id: b,title: "Lights",confirmationToken: "actual-b",confirmationOrder: 2,confirmedAt: date)]
check(precise.progress(cards: truncated) == 2, "Cold restart retains exact same-second receipt proof")
let impostor = [SequenceCardState(id: a,title: "Door",confirmationToken: "old-unknown",confirmationOrder: 1,confirmedAt: date), truncated[1]]
check(precise.progress(cards: impostor) == 0, "Time rounding never grants proof to an unobserved identity")
var unknown = fractionalGroup
check(try !unknown.recordObservedConfirmations(cards: fractionalOld, at: date.addingTimeInterval(1)), "Old events cannot be certified merely by being observed later")
print("ALL EXACT RECEIPT PRECISION TESTS PASSED")
