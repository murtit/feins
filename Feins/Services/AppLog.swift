import OSLog

enum AppLog {
    static let assistant = Logger(subsystem: "ch.murtit.feins", category: "assistant")
    static let speech = Logger(subsystem: "ch.murtit.feins", category: "speech")
    static let reminders = Logger(subsystem: "ch.murtit.feins", category: "reminders")
}
