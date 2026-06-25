import Foundation

/// Pure computation engine that determines when a plant's next care tasks are due.
///
/// Combines the plant's ``CareSchedule`` (last-event dates), the species' base intervals,
/// and adjustment factors (season, adherence offset) to produce a deterministic list
/// of ``CareTask`` values.  This engine has no dependency on Core Data, app state, or
/// any injected service — it is a pure function of its inputs, making it testable and
/// usable from widgets or extensions.
struct SchedulingEngine {
    /// Returns one ``CareTask`` per care type for the given plant.
    ///
    /// - Parameters:
    ///   - schedule: The plant's care schedule (last-event dates, adherence offset).
    ///   - species: The plant's species definition (base intervals from catalog).
    ///   - season: The current growing season, which may shorten or lengthen watering intervals.
    ///   - plantName: Display name, propagated into each ``CareTask``.
    ///   - now: The reference "current" date — typically ``Date()``, but injected for determinism.
    /// - Returns: One ``CareTask`` per care type (water, fertilize, prune, repot), each with its
    ///   computed due date and overdue flag.
    func nextDueDates(
        schedule: CareSchedule,
        species: PlantSpecies,
        season: Season,
        plantName: String,
        now: Date
    ) -> [CareTask] {
        let calendar = Calendar.current
        var tasks: [CareTask] = []

        let intervals: [(Date?, Int, CareEventType)] = [
            (schedule.lastWatered, species.wateringInterval, .watered),
            (schedule.lastFertilized, species.fertilizingInterval, .fertilized),
            (schedule.lastPruned, species.pruningInterval, .pruned),
            (schedule.lastRepotted, species.repottingInterval, .repotted)
        ]

        for (lastDate, baseInterval, eventType) in intervals {
            let adjusted = adjustedInterval(
                base: baseInterval,
                eventType: eventType,
                season: season,
                adherenceOffset: schedule.adherenceOffset
            )
            let dueDate: Date
            if let last = lastDate {
                dueDate = calendar.date(byAdding: .day, value: adjusted, to: last) ?? now
            } else {
                dueDate = calendar.date(byAdding: .day, value: adjusted, to: now) ?? now
            }
            let status: CareTask.Status = .incomplete
            tasks.append(CareTask(
                id: UUID(),
                plantID: schedule.plantID,
                plantName: plantName,
                eventType: eventType,
                dueDate: dueDate,
                status: status
            ))
        }

        return tasks
    }

    /// Applies season and adherence adjustments to a base interval.
    /// - Parameter base: The species' default interval in days.
    /// - Parameter eventType: The type of care event (only watering is seasonally adjusted).
    /// - Parameter season: The current season (summer shortens watering; winter extends it).
    /// - Parameter adherenceOffset: User's historical lateness in days; half of it is added to the interval.
    /// - Returns: Adjusted interval in days, clamped to a minimum of 1.
    private func adjustedInterval(
        base: Int,
        eventType: CareEventType,
        season: Season,
        adherenceOffset: Int
    ) -> Int {
        var adjusted = base

        switch season {
        case .summer:
            if eventType == .watered {
                adjusted = max(1, adjusted - 1)
            }
        case .winter:
            if eventType == .watered {
                adjusted += 2
            }
        case .spring, .fall:
            break
        }

        adjusted += adherenceOffset / 2

        return max(1, adjusted)
    }
}
