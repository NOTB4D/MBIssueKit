import Foundation

/// Non-sensitive runtime metadata captured with an issue report.
///
/// The context intentionally contains no application logs, network payloads,
/// state-management actions, or credentials.
public struct MBIssueTechnicalContext: Codable, Equatable, Sendable {
    public let screenName: String
    public let viewControllerName: String
    public let navigationStack: [String]
    public let appName: String
    public let bundleIdentifier: String
    public let appVersion: String
    public let buildNumber: String
    public let osVersion: String
    public let deviceModel: String
    public let deviceIdentifier: String
    public let architecture: String
    public let environment: String
    public let locale: String
    public let isDarkMode: Bool
    public let screenSize: String
    public let additional: [String: String]

    public init(
        screenName: String,
        viewControllerName: String,
        navigationStack: [String],
        appName: String,
        bundleIdentifier: String,
        appVersion: String,
        buildNumber: String,
        osVersion: String,
        deviceModel: String,
        deviceIdentifier: String,
        architecture: String,
        environment: String,
        locale: String,
        isDarkMode: Bool,
        screenSize: String,
        additional: [String: String] = [:]
    ) {
        self.screenName = screenName
        self.viewControllerName = viewControllerName
        self.navigationStack = navigationStack
        self.appName = appName
        self.bundleIdentifier = bundleIdentifier
        self.appVersion = appVersion
        self.buildNumber = buildNumber
        self.osVersion = osVersion
        self.deviceModel = deviceModel
        self.deviceIdentifier = deviceIdentifier
        self.architecture = architecture
        self.environment = environment
        self.locale = locale
        self.isDarkMode = isDarkMode
        self.screenSize = screenSize
        self.additional = additional
    }
}
