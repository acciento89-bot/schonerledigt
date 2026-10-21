import Foundation

/// Event IDs distinguish rechecks even when legacy ISO8601 timestamps share a second.
enum SequenceCardAdapter {
    static func states(routines: [RoutineItem], history: [CompletionEvent], at date: Date) -> [SequenceCardState] {
        routines.map { routine in
            guard routine.isCompleted(at: date), let completedAt = routine.completedAt,
                  let index = history.firstIndex(where: { $0.routineID == routine.id && $0.completedAt == completedAt }) else {
                return SequenceCardState(id: routine.id.uuidString, title: routine.title, confirmationToken: nil, confirmationOrder: nil)
            }
            return SequenceCardState(id: routine.id.uuidString, title: routine.title,
                                     confirmationToken: history[index].id.uuidString, confirmationOrder: -Double(index), confirmedAt: completedAt)
        }
    }
}
