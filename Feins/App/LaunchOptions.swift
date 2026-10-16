import Foundation

/// Steuerung über Startargumente, vor allem für UI-Tests und Screenshots.
struct LaunchOptions {
    var isUITesting = false
    var seedSampleData = false
    var forcedAppearance: Appearance?
    var initialTab: AppTab?
    /// Ersetzt im UI-Test das Mikrofon: die App "hört" diesen Text.
    var simulatedSpeech: String?
    /// Zeigt im UI-Test einen bestimmten KI-Status an, unabhängig vom Simulator.
    var forcedAIStatus: OnDeviceAIStatus?

    static var current: LaunchOptions {
        let arguments = ProcessInfo.processInfo.arguments
        var options = LaunchOptions()
        options.isUITesting = arguments.contains("-ui-testing")
        options.seedSampleData = arguments.contains("-seed-sample-data")
        if let index = arguments.firstIndex(of: "-appearance"), arguments.indices.contains(index + 1) {
            options.forcedAppearance = Appearance(rawValue: arguments[index + 1])
        }
        if let index = arguments.firstIndex(of: "-tab"), arguments.indices.contains(index + 1) {
            options.initialTab = AppTab(rawValue: arguments[index + 1])
        }
        if let index = arguments.firstIndex(of: "-simulate-speech"), arguments.indices.contains(index + 1) {
            options.simulatedSpeech = arguments[index + 1]
        }
        if let index = arguments.firstIndex(of: "-ai-status"), arguments.indices.contains(index + 1) {
            options.forcedAIStatus = OnDeviceAIStatus(rawValue: arguments[index + 1])
        }
        return options
    }
}
