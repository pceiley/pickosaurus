import os

/// Instruments markers intentionally carry no URL, host, passcode, or destination identity.
enum RoutingPerformance {
    private static let log = OSLog(subsystem: "com.pickosaurus", category: .pointsOfInterest)
    static func linkReceived() { os_signpost(.event, log: log, name: "Link received") }
    static func pickerWillOpen() { os_signpost(.event, log: log, name: "Picker will open") }
    static func destinationSelected() { os_signpost(.event, log: log, name: "Destination selected") }
    static func launchRequested() { os_signpost(.event, log: log, name: "Launch requested") }
    static func launchCompleted() { os_signpost(.event, log: log, name: "Launch completed") }
}
