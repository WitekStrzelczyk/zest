import Foundation
import os.log

/// A scheduled task that runs at regular intervals
struct ScheduledTask: Sendable {
    let id: String
    let interval: TimeInterval
    let action: @Sendable () async -> Void
    var lastRun: Date?
    var isRunning: Bool = false
}

/// Generic scheduler for running recurring background tasks
/// Supports multiple tasks with different intervals
final class SchedulerService: @unchecked Sendable {
    // MARK: - Singleton

    static let shared = SchedulerService()

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.zest.app", category: "Scheduler")
    private var tasks: [String: ScheduledTask] = [:]
    private var timer: Timer?
    private let checkInterval: TimeInterval = 60 // Check every minute
    private let queue = DispatchQueue(label: "com.zest.scheduler", qos: .utility)

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API

    /// Register a recurring task
    /// - Parameters:
    ///   - id: Unique identifier for the task
    ///   - interval: How often to run the task (in seconds)
    ///   - action: Async closure to execute
    func register(id: String, interval: TimeInterval, action: @escaping @Sendable () async -> Void) {
        queue.sync {
            let task = ScheduledTask(id: id, interval: interval, action: action)
            tasks[id] = task
            logger.info("Registered task '\(id)' with interval \(interval)s")
        }
    }

    /// Unregister a task
    func unregister(id: String) {
        queue.sync {
            tasks.removeValue(forKey: id)
            logger.info("Unregistered task '\(id)'")
        }
    }

    /// Start the scheduler - begins checking for due tasks
    func start() {
        queue.sync {
            guard timer == nil else {
                logger.warning("Scheduler already running")
                return
            }

            logger.info("Starting scheduler with \(self.tasks.count) registered tasks")
        }

        // Run all tasks immediately on start
        Task { [weak self] in
            await self?.runAllDueTasks()
        }

        // Schedule periodic checks on main thread
        DispatchQueue.main.async { [weak self] in
            self?.timer = Timer.scheduledTimer(withTimeInterval: self?.checkInterval ?? 60, repeats: true) { [weak self] _ in
                Task {
                    await self?.checkAndRunDueTasks()
                }
            }

            if let timer = self?.timer {
                RunLoop.current.add(timer, forMode: .common)
            }
        }
    }

    /// Stop the scheduler
    func stop() {
        DispatchQueue.main.async { [weak self] in
            self?.timer?.invalidate()
            self?.timer = nil
        }

        queue.sync {
            logger.info("Scheduler stopped")
        }
    }

    /// Manually trigger a specific task
    func runNow(id: String) async {
        let task: ScheduledTask? = queue.sync {
            tasks[id]
        }

        guard var taskToUpdate = task else {
            logger.warning("Task '\(id)' not found")
            return
        }

        if taskToUpdate.isRunning {
            logger.debug("Task '\(id)' already running, skipping")
            return
        }

        taskToUpdate.isRunning = true
        queue.sync {
            tasks[id] = taskToUpdate
        }

        logger.debug("Manually running task '\(id)'")
        await taskToUpdate.action()

        // Update last run time
        queue.sync {
            if var updatedTask = tasks[id] {
                updatedTask.lastRun = Date()
                updatedTask.isRunning = false
                tasks[id] = updatedTask
            }
        }
    }

    // MARK: - Private

    private func checkAndRunDueTasks() async {
        let now = Date()
        var tasksToRun: [ScheduledTask] = []

        queue.sync {
            for (id, var task) in tasks {
                // Skip if already running
                if task.isRunning {
                    continue
                }

                // Check if task is due
                if let lastRun = task.lastRun {
                    if now.timeIntervalSince(lastRun) >= task.interval {
                        task.isRunning = true
                        tasks[id] = task
                        tasksToRun.append(task)
                    }
                } else {
                    // Never run before
                    task.isRunning = true
                    tasks[id] = task
                    tasksToRun.append(task)
                }
            }
        }

        // Run due tasks
        for task in tasksToRun {
            logger.debug("Running scheduled task '\(task.id)'")
            await task.action()

            // Update last run time
            queue.sync {
                if var updatedTask = tasks[task.id] {
                    updatedTask.lastRun = Date()
                    updatedTask.isRunning = false
                    tasks[task.id] = updatedTask
                }
            }
        }
    }

    private func runAllDueTasks() async {
        logger.debug("Running all tasks on scheduler start")
        await checkAndRunDueTasks()
    }
}

// MARK: - Convenience Extensions

extension SchedulerService {
    /// Register a task with interval in minutes
    func register(id: String, intervalMinutes: Int, action: @escaping @Sendable () async -> Void) {
        register(id: id, interval: TimeInterval(intervalMinutes * 60), action: action)
    }

    /// Common task IDs
    enum TaskID {
        public static let calendarCacheRefresh = "calendar-cache-refresh"
    }
}
