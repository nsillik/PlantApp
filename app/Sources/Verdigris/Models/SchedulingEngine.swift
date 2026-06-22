import Foundation

struct SchedulingEngine {
    func nextDueDates(
        schedule: CareSchedule,
        species: PlantSpecies,
        careSheet: CareSheet,
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
            let isOverdue = dueDate < now
            tasks.append(CareTask(
                id: UUID(),
                plantID: schedule.plantID,
                plantName: plantName,
                eventType: eventType,
                dueDate: dueDate,
                isOverdue: isOverdue
            ))
        }

        return tasks
    }

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
