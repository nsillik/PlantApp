import Dependencies
import SwiftUI

@MainActor
@Observable
final class HomeViewModel {
    var plants: [Plant] = []
    var catalog: [PlantSpecies] = []
    var userProfile: UserProfile?
    var careTasks: [CareTask] = []
    var isLoading = false
    var isLogging = false
    var errorMessage: String?

    @ObservationIgnored
    @Dependency(\.plantRepository) private var repository
    @ObservationIgnored
    @Dependency(\.userProfileRepository) private var profileRepository
    @ObservationIgnored
    @Dependency(\.catalogService) private var catalogService
    @ObservationIgnored
    @Dependency(\.careScheduleRepository) private var scheduleRepository
    @ObservationIgnored
    @Dependency(\.notificationScheduling) private var scheduler

    private let engine = SchedulingEngine()

    func checkNotificationPermissionIfNeeded() async -> Bool {
        guard !careTasks.isEmpty else { return false }
        return !(await scheduler.authorizationGranted())
    }

    var todayTasks: [CareTask] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        return careTasks.filter { $0.isOverdue || ($0.dueDate >= startOfDay && $0.dueDate < endOfDay) }
    }

    var upcomingTasks: [CareTask] {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let endOfWindow = Calendar.current.date(byAdding: .day, value: 7, to: startOfToday)!
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!
        return careTasks.filter { $0.dueDate >= startOfTomorrow && $0.dueDate < endOfWindow && !$0.isOverdue }
    }

    func loadAll() async {
        isLoading = true
        errorMessage = nil
        do {
            async let plantsTask = repository.fetchAll()
            async let catalogTask = catalogService.loadCatalog()
            async let profileTask = profileRepository.fetch()
            async let schedulesTask = scheduleRepository.fetchAll()
            async let eventsTask = scheduleRepository.fetchAllCareEvents(since: Calendar.current.startOfDay(for: Date()))

            plants = try await plantsTask
            catalog = try await catalogTask
            userProfile = try await profileTask
            let schedules = try await schedulesTask
            let recentEvents = try await eventsTask

            recomputeTasks(plants: plants, catalog: catalog, profile: userProfile, schedules: schedules, recentEvents: recentEvents)
        } catch {
            errorMessage = String(localized: "Failed to load data.")
        }
        isLoading = false
    }

    func logCareEvent(plantID: UUID, eventType: CareEventType) async {
        isLogging = true
        let event = CareEvent(
            id: UUID(),
            plantID: plantID,
            eventType: eventType,
            timestamp: Date(),
            photoData: nil
        )

        do {
            try await scheduleRepository.recordCareEvent(event, updatingScheduleFor: plantID)
            await loadAll()
            await reRegisterNotifications()
        } catch {
            errorMessage = String(localized: "Failed to log care event.")
        }
        isLogging = false
    }

    func deletePlant(_ plant: Plant) async {
        do {
            try await repository.delete(plant)
            plants.removeAll { $0.id == plant.id }
            careTasks.removeAll { $0.plantID == plant.id }
        } catch {
            errorMessage = String(localized: "Failed to delete plant.")
        }
    }

    func reRegisterNotifications() async {
        let allSchedules = (try? await scheduleRepository.fetchAll()) ?? []
        let plantsMap = Dictionary(uniqueKeysWithValues: plants.map { ($0.id, $0) })
        let catMap = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })

        var allTasks: [CareTask] = []
        for schedule in allSchedules {
            guard let plant = plantsMap[schedule.plantID],
                  let species = catMap[plant.speciesID] else { continue }
            let season = userProfile.map { Season.current(latitude: $0.latitude) } ?? .spring
            allTasks += engine.nextDueDates(
                schedule: schedule,
                species: species,
                season: season,
                plantName: plant.name,
                now: Date()
            )
        }

        await scheduler.registerTasks(allTasks)
    }

    private func recomputeTasks(
        plants: [Plant],
        catalog: [PlantSpecies],
        profile: UserProfile?,
        schedules: [CareSchedule],
        recentEvents: [CareEvent]
    ) {
        let catMap = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
        let scheduleMap = Dictionary(uniqueKeysWithValues: schedules.map { ($0.plantID, $0) })
        let season = profile.map { Season.current(latitude: $0.latitude) } ?? .spring
        let completedKeys = Set(recentEvents.map { "\($0.plantID.uuidString)-\($0.eventType.rawValue)" })

        var allTasks: [CareTask] = []
        for plant in plants {
            guard let species = catMap[plant.speciesID] else { continue }
            let schedule = scheduleMap[plant.id] ?? CareSchedule(
                id: UUID(),
                plantID: plant.id,
                lastWatered: nil,
                lastFertilized: nil,
                lastPruned: nil,
                lastRepotted: nil,
                adherenceOffset: 0
            )
            allTasks += engine.nextDueDates(
                schedule: schedule,
                species: species,
                season: season,
                plantName: plant.name,
                now: Date()
            )
        }

        careTasks = allTasks.sorted { $0.dueDate < $1.dueDate }
            .map { task in
                guard completedKeys.contains(task.id) else { return task }
                var updated = task
                updated.status = .completed
                return updated
            }
    }
}

struct HomeView: View {
    @State private var viewModel: HomeViewModel
    @State private var showSettings = false
    @State private var showCatalog = false
    @State private var showNotificationAlert = false
    @State private var showCameraFlow = false
    @State private var savedPlant: Plant?
    let onboardingCoordinator: OnboardingCoordinator

    init(viewModel: HomeViewModel = HomeViewModel(), onboardingCoordinator: OnboardingCoordinator) {
        self._viewModel = State(initialValue: viewModel)
        self.onboardingCoordinator = onboardingCoordinator
    }

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.plants.isEmpty {
                    ProgressView(String(localized: "Loading plants…"))
                } else if let errorMessage = viewModel.errorMessage, viewModel.plants.isEmpty {
                    ContentUnavailableView(
                        String(localized: "Error"),
                        systemImage: "exclamationmark.triangle",
                        description: Text(errorMessage)
                    )
                } else if viewModel.plants.isEmpty {
                    ContentUnavailableView(
                        String(localized: "No Plants Yet"),
                        systemImage: "leaf",
                        description: Text(String(localized: "Add your first plant to get started."))
                    )
                } else {
                    dashboardContent
                }
            }
            .navigationTitle(String(localized: "My Plants"))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showCameraFlow = true
                    } label: {
                        Image(systemName: "camera")
                    }
                    Button(String(localized: "Add")) {
                        showCatalog = true
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showCatalog) {
                CatalogBrowseView { _, _ in
                    showCatalog = false
                    Task { await viewModel.loadAll() }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView {
                    onboardingCoordinator.resetOnboarding()
                }
            }
            .sheet(item: $savedPlant) { plant in
                NavigationStack {
                    PlantDetailView(plant: plant)
                }
            }
            .plantCameraAddFlow(isPresented: $showCameraFlow) { plant in
                savedPlant = plant
                Task { await viewModel.loadAll() }
            }
            .alert(String(localized: "Enable Notifications?"), isPresented: $showNotificationAlert) {
                Button(String(localized: "Yes")) {
                    Task { await requestNotificationPermission() }
                }
                Button(String(localized: "Not Now"), role: .cancel) {}
            } message: {
                Text(String(localized: "Get reminded when your plants need care."))
            }
        }
        .task {
            await viewModel.loadAll()
        }
        .refreshable {
            await viewModel.loadAll()
        }
    }

    private var dashboardContent: some View {
        List {
            if !viewModel.todayTasks.isEmpty {
                Section(String(localized: "Today")) {
                    ForEach(groupedTasks(viewModel.todayTasks), id: \.plantID) { group in
                        PlantTasksSection(
                            plantName: group.plantName,
                            tasks: group.tasks,
                            isLoading: viewModel.isLogging,
                            onLog: { eventType in
                                Task { await viewModel.logCareEvent(plantID: group.plantID, eventType: eventType) }
                            }
                        )
                    }
                }
            }

            if !viewModel.upcomingTasks.isEmpty {
                Section(String(localized: "Upcoming")) {
                    ForEach(groupedTasks(viewModel.upcomingTasks), id: \.plantID) { group in
                        PlantTasksSection(
                            plantName: group.plantName,
                            tasks: group.tasks,
                            isLoading: viewModel.isLogging,
                            onLog: { eventType in
                                Task { await viewModel.logCareEvent(plantID: group.plantID, eventType: eventType) }
                            }
                        )
                    }
                }
            }

            if viewModel.todayTasks.isEmpty && viewModel.upcomingTasks.isEmpty {
                Section {
                    ContentUnavailableView(
                        String(localized: "All Caught Up"),
                        systemImage: "checkmark.circle",
                        description: Text(String(localized: "No tasks due right now."))
                    )
                }
            }

            Section(String(localized: "My Plants")) {
                ForEach(viewModel.plants, id: \.id) { plant in
                    NavigationLink {
                        PlantDetailView(plant: plant)
                    } label: {
                        PlantRowView(plant: plant)
                    }
                    .swipeActions {
                        Button(String(localized: "Delete"), role: .destructive) {
                            Task { await viewModel.deletePlant(plant) }
                        }
                    }
                }
            }
        }
        .onAppear {
            if !viewModel.careTasks.isEmpty {
                Task {
                    if await viewModel.checkNotificationPermissionIfNeeded() {
                        showNotificationAlert = true
                    }
                }
            }
        }
    }

    private func requestNotificationPermission() async {
        @Dependency(\.notificationScheduling) var scheduler
        let granted = await scheduler.requestPermission()
        if granted {
            await viewModel.reRegisterNotifications()
        }
    }

    private func groupedTasks(_ tasks: [CareTask]) -> [(plantID: UUID, plantName: String, tasks: [CareTask])] {
        let grouped = Dictionary(grouping: tasks) { $0.plantID }
        return grouped.map { plantID, tasks in
            (plantID, tasks.first?.plantName ?? "", tasks.sorted { $0.dueDate < $1.dueDate })
        }.sorted { $0.plantName < $1.plantName }
    }
}

private struct PlantTasksSection: View {
    let plantName: String
    let tasks: [CareTask]
    let isLoading: Bool
    let onLog: (CareEventType) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(plantName)
                .font(.headline)
            ForEach(tasks) { task in
                TaskRow(task: task, isLoading: isLoading, onLog: onLog)
            }
        }
    }
}

private struct TaskRow: View {
    let task: CareTask
    let isLoading: Bool
    let onLog: (CareEventType) -> Void

    var body: some View {
        HStack {
            Image(systemName: imageName)
                .foregroundStyle(imageColor)
            VStack(alignment: .leading) {
                Text(task.eventType.localizedLabel)
                    .font(.subheadline)
                    .fontWeight(task.isOverdue ? .bold : .regular)
                    .strikethrough(task.status == .completed)
                Text(task.dueDate, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if task.status == .completed {
                Text(String(localized: "Done"))
                    .font(.caption)
                    .foregroundStyle(.green)
            } else {
                Button(String(localized: "Done")) {
                    onLog(task.eventType)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(isLoading)
            }
        }
        .opacity(task.status == .completed ? 0.6 : 1)
    }

    private var imageName: String {
        switch task.status {
        case .completed: "checkmark.circle.fill"
        case .incomplete: task.isOverdue ? "exclamationmark.circle.fill" : "circle"
        }
    }

    private var imageColor: Color {
        switch task.status {
        case .completed: .green
        case .incomplete: task.isOverdue ? .red : .secondary
        }
    }
}

struct ThumbnailRow: View {
    let title: String
    let subtitle: String?
    let systemImage: String
    let imageColor: Color

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 44, height: 44)
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(imageColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PlantRowView: View {
    let plant: Plant

    var body: some View {
        ThumbnailRow(
            title: plant.name,
            subtitle: plant.placementLight.map { String(localized: "\($0.label) light") },
            systemImage: "leaf",
            imageColor: .green
        )
    }
}
