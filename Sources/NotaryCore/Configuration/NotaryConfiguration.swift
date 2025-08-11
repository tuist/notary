import Foundation

public struct NotaryConfiguration: Codable {
    public let signingIdentity: SigningIdentityConfiguration?
    public let notarizationCredentials: NotarizationCredentialsConfiguration?
    public let options: SigningOptions
    public let paths: PathConfiguration
    
    public init(
        signingIdentity: SigningIdentityConfiguration? = nil,
        notarizationCredentials: NotarizationCredentialsConfiguration? = nil,
        options: SigningOptions = SigningOptions(),
        paths: PathConfiguration = PathConfiguration()
    ) {
        self.signingIdentity = signingIdentity
        self.notarizationCredentials = notarizationCredentials
        self.options = options
        self.paths = paths
    }
    
    public static func load(from url: URL) throws -> NotaryConfiguration {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(NotaryConfiguration.self, from: data)
    }
    
    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        try data.write(to: url)
    }
}

public struct SigningIdentityConfiguration: Codable {
    public let name: String?
    public let teamIdentifier: String?
    public let certificateFile: String?
    public let privateKeyFile: String?
    public let password: String?
    
    public init(
        name: String? = nil,
        teamIdentifier: String? = nil,
        certificateFile: String? = nil,
        privateKeyFile: String? = nil,
        password: String? = nil
    ) {
        self.name = name
        self.teamIdentifier = teamIdentifier
        self.certificateFile = certificateFile
        self.privateKeyFile = privateKeyFile
        self.password = password
    }
}

public struct NotarizationCredentialsConfiguration: Codable {
    public let appleId: String?
    public let teamId: String?
    public let password: String?
    public let apiKey: String?
    public let apiIssuer: String?
    public let keychainProfile: String?
    
    public init(
        appleId: String? = nil,
        teamId: String? = nil,
        password: String? = nil,
        apiKey: String? = nil,
        apiIssuer: String? = nil,
        keychainProfile: String? = nil
    ) {
        self.appleId = appleId
        self.teamId = teamId
        self.password = password
        self.apiKey = apiKey
        self.apiIssuer = apiIssuer
        self.keychainProfile = keychainProfile
    }
    
    public var isValid: Bool {
        if let _ = keychainProfile {
            return true
        }
        
        if let _ = apiKey, let _ = apiIssuer {
            return true
        }
        
        if let _ = appleId, let _ = teamId, let _ = password {
            return true
        }
        
        return false
    }
}

public struct SigningOptions: Codable {
    public let deepSign: Bool
    public let force: Bool
    public let hardenedRuntime: Bool
    public let timestamp: Bool
    public let preserveMetadata: Bool
    public let entitlementsFile: String?
    public let requirementsFile: String?
    
    public init(
        deepSign: Bool = true,
        force: Bool = false,
        hardenedRuntime: Bool = true,
        timestamp: Bool = true,
        preserveMetadata: Bool = true,
        entitlementsFile: String? = nil,
        requirementsFile: String? = nil
    ) {
        self.deepSign = deepSign
        self.force = force
        self.hardenedRuntime = hardenedRuntime
        self.timestamp = timestamp
        self.preserveMetadata = preserveMetadata
        self.entitlementsFile = entitlementsFile
        self.requirementsFile = requirementsFile
    }
}

public struct PathConfiguration: Codable {
    public let outputDirectory: String
    public let tempDirectory: String
    public let logDirectory: String
    
    public init(
        outputDirectory: String = "./signed",
        tempDirectory: String = "/tmp/notary",
        logDirectory: String = "~/.notary/logs"
    ) {
        self.outputDirectory = outputDirectory
        self.tempDirectory = tempDirectory
        self.logDirectory = logDirectory
    }
    
    public var resolvedOutputDirectory: URL {
        URL(fileURLWithPath: (outputDirectory as NSString).expandingTildeInPath)
    }
    
    public var resolvedTempDirectory: URL {
        URL(fileURLWithPath: (tempDirectory as NSString).expandingTildeInPath)
    }
    
    public var resolvedLogDirectory: URL {
        URL(fileURLWithPath: (logDirectory as NSString).expandingTildeInPath)
    }
}

public class ConfigurationManager {
    private let configurationURL: URL
    private var configuration: NotaryConfiguration
    
    public init(configurationURL: URL? = nil) throws {
        if let url = configurationURL {
            self.configurationURL = url
            self.configuration = try NotaryConfiguration.load(from: url)
        } else {
            let defaultURL = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".notary")
                .appendingPathComponent("config.json")
            self.configurationURL = defaultURL
            
            if FileManager.default.fileExists(atPath: defaultURL.path) {
                self.configuration = try NotaryConfiguration.load(from: defaultURL)
            } else {
                self.configuration = NotaryConfiguration()
                try ensureConfigurationDirectory()
                try configuration.save(to: defaultURL)
            }
        }
    }
    
    public func getConfiguration() -> NotaryConfiguration {
        return configuration
    }
    
    public func updateConfiguration(_ configuration: NotaryConfiguration) throws {
        self.configuration = configuration
        try configuration.save(to: configurationURL)
    }
    
    public func mergeEnvironmentVariables() {
        var config = configuration
        
        if let appleId = ProcessInfo.processInfo.environment["NOTARY_APPLE_ID"] {
            config = NotaryConfiguration(
                signingIdentity: config.signingIdentity,
                notarizationCredentials: NotarizationCredentialsConfiguration(
                    appleId: appleId,
                    teamId: config.notarizationCredentials?.teamId ?? ProcessInfo.processInfo.environment["NOTARY_TEAM_ID"],
                    password: config.notarizationCredentials?.password ?? ProcessInfo.processInfo.environment["NOTARY_PASSWORD"],
                    apiKey: config.notarizationCredentials?.apiKey,
                    apiIssuer: config.notarizationCredentials?.apiIssuer,
                    keychainProfile: config.notarizationCredentials?.keychainProfile
                ),
                options: config.options,
                paths: config.paths
            )
        }
        
        configuration = config
    }
    
    private func ensureConfigurationDirectory() throws {
        let directory = configurationURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
}