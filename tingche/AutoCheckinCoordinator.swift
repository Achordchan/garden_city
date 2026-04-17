import Foundation

@MainActor
final class AutoCheckinCoordinator {
    static let shared = AutoCheckinCoordinator()

    private var accountManager: AccountManager?
    private var dataManager: DataManager?
    private var hasStarted = false
    private var scheduledTimer: Timer?
    private var runningTask: Task<Void, Never>?
    private var lastRunDay: Date?

    private init() {}

    deinit {
        scheduledTimer?.invalidate()
    }

    func startIfNeeded(accountManager: AccountManager, dataManager: DataManager) {
        self.accountManager = accountManager
        self.dataManager = dataManager

        guard !hasStarted else { return }
        hasStarted = true

        LogStore.shared.add(category: "CHECKIN", "自动签到协调器已启动")
        scheduleNextRun()
        runIfNeeded(trigger: "启动补签")
    }

    private func scheduleNextRun() {
        scheduledTimer?.invalidate()

        let now = Date()
        let calendar = Calendar.current
        let nextRun = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 0, minute: 1),
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        ) ?? now.addingTimeInterval(3600)

        let interval = max(1, nextRun.timeIntervalSince(now))
        scheduledTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.handleScheduledRun()
            }
        }

        LogStore.shared.add(
            category: "CHECKIN",
            "已安排下次自动签到：\(DateFormatter.displayFormatter.string(from: nextRun))"
        )
    }

    private func handleScheduledRun() {
        accountManager?.resetDailyStatusesIfNeeded()
        runIfNeeded(trigger: "每日自动签到")
        scheduleNextRun()
    }

    private func runIfNeeded(trigger: String) {
        guard runningTask == nil else {
            LogStore.shared.add(category: "CHECKIN", "跳过自动签到：已有任务在执行")
            return
        }

        guard let accountManager, let dataManager else {
            LogStore.shared.add(category: "CHECKIN", "跳过自动签到：缺少运行上下文")
            return
        }

        let today = Calendar.current.startOfDay(for: Date())
        if let lastRunDay, Calendar.current.isDate(lastRunDay, inSameDayAs: today) {
            LogStore.shared.add(category: "CHECKIN", "跳过自动签到：今天已经执行过，触发来源：\(trigger)")
            return
        }

        runningTask = Task {
            let didRun = await accountManager.performAutoCheckin(dataManager: dataManager, trigger: trigger)
            await MainActor.run {
                if didRun {
                    self.lastRunDay = today
                }
                self.runningTask = nil
            }
        }
    }
}
