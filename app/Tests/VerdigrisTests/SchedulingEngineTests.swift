import Testing
import Foundation

@testable import Verdigris

@Suite("Scheduling Engine Tests")
struct SchedulingEngineTests {
    let engine = SchedulingEngine()
    let testSpecies = PlantSpecies(
        id: UUID(),
        name: PlantName(commonNamesLocalized: ["en": "Monstera"]),
        wateringInterval: 7,
        fertilizingInterval: 30,
        pruningInterval: 90,
        repottingInterval: 365
    )

    @Test("Baseline: no prior events uses interval from now")
    func baselineNoPriorEvents() {
        let now = Date()
        let schedule = CareSchedule(
            id: UUID(), plantID: UUID(),
            lastWatered: nil, lastFertilized: nil, lastPruned: nil, lastRepotted: nil,
            adherenceOffset: 0
        )

        let tasks = engine.nextDueDates(
            schedule: schedule, species: testSpecies,
            careSheet: CareSheet(water: "", light: "", soil: "", humidity: "", toxicity: "", commonProblems: ""),
            season: .spring, plantName: "Test", now: now
        )

        #expect(tasks.count == 4)
        for task in tasks {
            let expected = Calendar.current.date(byAdding: .day, value: interval(for: task.eventType), to: now)!
            #expect(Calendar.current.isDate(task.dueDate, inSameDayAs: expected))
            #expect(!task.isOverdue)
        }
    }

    @Test("Overdue detection: last event + interval < now")
    func overdueDetection() {
        let now = Date()
        let past = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        let schedule = CareSchedule(
            id: UUID(), plantID: UUID(),
            lastWatered: past, lastFertilized: past, lastPruned: past, lastRepotted: past,
            adherenceOffset: 0
        )

        let tasks = engine.nextDueDates(
            schedule: schedule, species: testSpecies,
            careSheet: CareSheet(water: "", light: "", soil: "", humidity: "", toxicity: "", commonProblems: ""),
            season: .spring, plantName: "Test", now: now
        )

        #expect(tasks.count == 4)
        let wateredTask = tasks.first { $0.eventType == .watered }
        #expect(wateredTask?.isOverdue == true)
    }

    @Test("Adherence offset extends interval")
    func adherenceAdjustment() {
        let now = Date()
        let past = Calendar.current.date(byAdding: .day, value: -5, to: now)!
        let schedule = CareSchedule(
            id: UUID(), plantID: UUID(),
            lastWatered: past, lastFertilized: past, lastPruned: past, lastRepotted: past,
            adherenceOffset: 4
        )

        let tasks = engine.nextDueDates(
            schedule: schedule, species: testSpecies,
            careSheet: CareSheet(water: "", light: "", soil: "", humidity: "", toxicity: "", commonProblems: ""),
            season: .spring, plantName: "Test", now: now
        )

        let wateredTask = tasks.first { $0.eventType == .watered }
        // wateringInterval = 7, offset = 4, offset/2 = 2, so adjusted = 9
        let expectedDate = Calendar.current.date(byAdding: .day, value: 9, to: past)!
        #expect(Calendar.current.isDate(wateredTask!.dueDate, inSameDayAs: expectedDate))
    }

    @Test("All four care types coexist in output")
    func multipleCareTypes() {
        let now = Date()
        let schedule = CareSchedule(
            id: UUID(), plantID: UUID(),
            lastWatered: nil, lastFertilized: nil, lastPruned: nil, lastRepotted: nil,
            adherenceOffset: 0
        )

        let tasks = engine.nextDueDates(
            schedule: schedule, species: testSpecies,
            careSheet: CareSheet(water: "", light: "", soil: "", humidity: "", toxicity: "", commonProblems: ""),
            season: .spring, plantName: "Test", now: now
        )

        #expect(tasks.count == 4)
        let types = Set(tasks.map(\.eventType))
        #expect(types == [.watered, .fertilized, .pruned, .repotted])
    }

    @Test("Output is deterministic: same inputs produce same due dates")
    func deterministic() {
        let now = Date()
        let schedule = CareSchedule(
            id: UUID(), plantID: UUID(),
            lastWatered: Calendar.current.date(byAdding: .day, value: -3, to: now)!,
            lastFertilized: nil, lastPruned: nil, lastRepotted: nil,
            adherenceOffset: 2
        )

        let first = engine.nextDueDates(
            schedule: schedule, species: testSpecies,
            careSheet: CareSheet(water: "", light: "", soil: "", humidity: "", toxicity: "", commonProblems: ""),
            season: .summer, plantName: "Test", now: now
        )
        let second = engine.nextDueDates(
            schedule: schedule, species: testSpecies,
            careSheet: CareSheet(water: "", light: "", soil: "", humidity: "", toxicity: "", commonProblems: ""),
            season: .summer, plantName: "Test", now: now
        )

        #expect(first.count == second.count)
        for (f, s) in zip(first, second) {
            #expect(f.eventType == s.eventType)
            #expect(f.dueDate == s.dueDate)
            #expect(f.isOverdue == s.isOverdue)
            #expect(f.plantID == s.plantID)
            #expect(f.plantName == s.plantName)
        }
    }

    @Test("Winter extends watering interval vs summer")
    func seasonAdjustment() {
        let now = Date()
        let past = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        let schedule = CareSchedule(
            id: UUID(), plantID: UUID(),
            lastWatered: past, lastFertilized: nil, lastPruned: nil, lastRepotted: nil,
            adherenceOffset: 0
        )

        let winterTasks = engine.nextDueDates(
            schedule: schedule, species: testSpecies,
            careSheet: CareSheet(water: "", light: "", soil: "", humidity: "", toxicity: "", commonProblems: ""),
            season: .winter, plantName: "Test", now: now
        )
        let summerTasks = engine.nextDueDates(
            schedule: schedule, species: testSpecies,
            careSheet: CareSheet(water: "", light: "", soil: "", humidity: "", toxicity: "", commonProblems: ""),
            season: .summer, plantName: "Test", now: now
        )

        let winterWater = winterTasks.first { $0.eventType == .watered }!
        let summerWater = summerTasks.first { $0.eventType == .watered }!
        #expect(winterWater.dueDate > summerWater.dueDate)
    }

    private func interval(for type: CareEventType) -> Int {
        switch type {
        case .watered: 7
        case .fertilized: 30
        case .pruned: 90
        case .repotted: 365
        }
    }
}
