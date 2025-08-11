import Foundation
import ArgumentParser
import NotaryCore
import AsyncHTTPClient

struct ValidationError: Error, LocalizedError {
    let message: String
    
    init(_ message: String) {
        self.message = message
    }
    
    var errorDescription: String? {
        return message
    }
}

@main
struct NotaryCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "notary",
        abstract: "A Swift tool for code signing and notarization",
        version: "1.0.0",
        subcommands: [
            SignCommand.self,
            NotarizeCommand.self,
            VerifyCommand.self,
            ListIdentitiesCommand.self,
            ConfigCommand.self
        ]
    )
}

struct SignCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sign",
        abstract: "Sign a binary or bundle"
    )
    
    @Argument(help: "Path to the binary or bundle to sign")
    var path: String
    
    @Option(name: .shortAndLong, help: "Signing identity name")
    var identity: String?
    
    @Option(name: .shortAndLong, help: "Team identifier")
    var teamId: String?
    
    @Option(name: .shortAndLong, help: "Path to entitlements file")
    var entitlements: String?
    
    @Flag(name: .long, help: "Enable hardened runtime")
    var hardenedRuntime: Bool = false
    
    @Flag(name: .long, help: "Deep sign bundles")
    var deep: Bool = false
    
    @Flag(name: .long, help: "Force re-signing")
    var force: Bool = false
    
    @Flag(name: .long, help: "Add secure timestamp")
    var timestamp: Bool = false
    
    func run() async throws {
        let configManager = try ConfigurationManager()
        configManager.mergeEnvironmentVariables()
        let config = configManager.getConfiguration()
        
        let signingService = CodeSigningService()
        
        let identityName = identity ?? config.signingIdentity?.name
        guard let identityName = identityName else {
            throw ValidationError("No signing identity specified. Use --identity or configure in ~/.notary/config.json")
        }
        
        let certificate = Certificate(
            commonName: identityName,
            organizationName: "",
            organizationUnit: "",
            countryName: "",
            serialNumber: UUID().uuidString,
            issuer: "",
            subject: identityName,
            notBefore: Date(),
            notAfter: Date().addingTimeInterval(365 * 24 * 60 * 60),
            publicKey: Data(),
            signature: Data(),
            rawData: Data()
        )
        
        let signingIdentity = SigningIdentity(
            certificate: certificate,
            privateKey: Data(),
            type: .developerID,
            teamIdentifier: teamId ?? config.signingIdentity?.teamIdentifier
        )
        
        var entitlementsObj: Entitlements?
        if let entitlementsPath = entitlements ?? config.options.entitlementsFile {
            let url = URL(fileURLWithPath: entitlementsPath)
            entitlementsObj = try Entitlements.from(file: url)
        }
        
        let signingConfig = SigningConfiguration(
            identity: signingIdentity,
            entitlements: entitlementsObj,
            timestamp: timestamp || config.options.timestamp,
            hardenedRuntime: hardenedRuntime || config.options.hardenedRuntime,
            deepSign: deep || config.options.deepSign,
            force: force || config.options.force
        )
        
        let url = URL(fileURLWithPath: path)
        
        print("🔏 Signing \(url.lastPathComponent)...")
        try await signingService.sign(at: url, with: signingConfig)
        
        print("✅ Successfully signed \(url.lastPathComponent)")
        
        if try await signingService.verify(at: url) {
            print("✓ Signature verified successfully")
        } else {
            print("⚠️ Warning: Signature verification failed")
        }
    }
}

struct NotarizeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "notarize",
        abstract: "Submit an app for notarization"
    )
    
    @Argument(help: "Path to the app or archive to notarize")
    var path: String
    
    @Option(name: .shortAndLong, help: "Bundle identifier")
    var bundleId: String
    
    @Option(name: .long, help: "Apple ID username")
    var appleId: String?
    
    @Option(name: .shortAndLong, help: "App-specific password")
    var password: String?
    
    @Option(name: .shortAndLong, help: "Team ID")
    var teamId: String?
    
    @Option(name: .long, help: "Keychain profile name")
    var keychainProfile: String?
    
    @Flag(name: .long, help: "Wait for notarization to complete")
    var wait: Bool = false
    
    @Flag(name: .long, help: "Staple the notarization ticket")
    var staple: Bool = false
    
    func run() async throws {
        let configManager = try ConfigurationManager()
        configManager.mergeEnvironmentVariables()
        let config = configManager.getConfiguration()
        
        let credentials = config.notarizationCredentials
        
        let finalAppleId = appleId ?? credentials?.appleId
        let finalPassword = password ?? credentials?.password
        let finalTeamId = teamId ?? credentials?.teamId
        
        guard let finalAppleId = finalAppleId,
              let finalPassword = finalPassword,
              let finalTeamId = finalTeamId else {
            throw ValidationError("Missing credentials. Provide --apple-id, --password, and --team-id or configure in ~/.notary/config.json")
        }
        
        let request = NotarizationRequest(
            bundleIdentifier: bundleId,
            filePath: URL(fileURLWithPath: path),
            teamId: finalTeamId,
            username: finalAppleId,
            password: finalPassword
        )
        
        print("📦 Submitting \(URL(fileURLWithPath: path).lastPathComponent) for notarization...")
        
        let notarizationService = NotarizationService()
        let result = try await notarizationService.notarize(request)
        
        switch result.status {
        case .success:
            print("✅ Notarization successful!")
            if let requestId = result.request.requestUUID {
                print("   Request ID: \(requestId)")
            }
        case .invalid:
            print("❌ Notarization failed - Invalid submission")
            for issue in result.issues.filter({ $0.severity == .error }) {
                print("   • \(issue.message)")
            }
        case .rejected:
            print("❌ Notarization rejected")
        case .failed:
            print("❌ Notarization failed")
        default:
            print("⏳ Notarization status: \(result.status)")
        }
        
        if staple && result.status == .success {
            print("📎 Stapling notarization ticket...")
        }
    }
}

struct VerifyCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "verify",
        abstract: "Verify code signature"
    )
    
    @Argument(help: "Path to verify")
    var path: String
    
    @Flag(name: .long, help: "Deep verification")
    var deep: Bool = false
    
    @Flag(name: .long, help: "Verbose output")
    var verbose: Bool = false
    
    func run() async throws {
        let signingService = CodeSigningService()
        let url = URL(fileURLWithPath: path)
        
        print("🔍 Verifying \(url.lastPathComponent)...")
        
        let isValid = try await signingService.verify(at: url, deep: deep)
        
        if isValid {
            print("✅ Valid signature")
            
            if verbose {
                let info = try await signingService.extractSigningInfo(from: url)
                
                if let identifier = info.identifier {
                    print("   Identifier: \(identifier)")
                }
                if let teamId = info.teamIdentifier {
                    print("   Team ID: \(teamId)")
                }
                if !info.authorities.isEmpty {
                    print("   Authorities:")
                    for authority in info.authorities {
                        print("     • \(authority)")
                    }
                }
                if let format = info.format {
                    print("   Format: \(format)")
                }
            }
        } else {
            print("❌ Invalid signature")
            throw ValidationError("Signature verification failed")
        }
    }
}

struct ListIdentitiesCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list-identities",
        abstract: "List available signing identities"
    )
    
    @Flag(name: .long, help: "Show only valid identities")
    var validOnly: Bool = false
    
    func run() async throws {
        let signingService = CodeSigningService()
        
        print("🔑 Available signing identities:")
        print("")
        
        let identities = try await signingService.listIdentities()
        
        if identities.isEmpty {
            print("No signing identities found")
            return
        }
        
        for (index, identity) in identities.enumerated() {
            if validOnly && !identity.isValid {
                continue
            }
            
            print("\(index + 1)) \(identity.displayName)")
            print("   Type: \(identity.type.identifier)")
            if !identity.isValid {
                print("   ⚠️ Certificate expired or invalid")
            }
        }
    }
}

struct ConfigCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "config",
        abstract: "Manage notary configuration"
    )
    
    @Flag(name: .long, help: "Show current configuration")
    var show: Bool = false
    
    @Option(name: .long, help: "Set Apple ID")
    var appleId: String?
    
    @Option(name: .long, help: "Set Team ID")
    var teamId: String?
    
    @Option(name: .long, help: "Set signing identity")
    var identity: String?
    
    func run() async throws {
        let configManager = try ConfigurationManager()
        
        if show {
            let config = configManager.getConfiguration()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(config)
            if let json = String(data: data, encoding: .utf8) {
                print(json)
            }
            return
        }
        
        var config = configManager.getConfiguration()
        var updated = false
        
        if let appleId = appleId {
            config = NotaryConfiguration(
                signingIdentity: config.signingIdentity,
                notarizationCredentials: NotarizationCredentialsConfiguration(
                    appleId: appleId,
                    teamId: config.notarizationCredentials?.teamId,
                    password: config.notarizationCredentials?.password,
                    apiKey: config.notarizationCredentials?.apiKey,
                    apiIssuer: config.notarizationCredentials?.apiIssuer,
                    keychainProfile: config.notarizationCredentials?.keychainProfile
                ),
                options: config.options,
                paths: config.paths
            )
            updated = true
        }
        
        if let teamId = teamId {
            config = NotaryConfiguration(
                signingIdentity: SigningIdentityConfiguration(
                    name: config.signingIdentity?.name,
                    teamIdentifier: teamId,
                    certificateFile: config.signingIdentity?.certificateFile,
                    privateKeyFile: config.signingIdentity?.privateKeyFile,
                    password: config.signingIdentity?.password
                ),
                notarizationCredentials: config.notarizationCredentials,
                options: config.options,
                paths: config.paths
            )
            updated = true
        }
        
        if let identity = identity {
            config = NotaryConfiguration(
                signingIdentity: SigningIdentityConfiguration(
                    name: identity,
                    teamIdentifier: config.signingIdentity?.teamIdentifier,
                    certificateFile: config.signingIdentity?.certificateFile,
                    privateKeyFile: config.signingIdentity?.privateKeyFile,
                    password: config.signingIdentity?.password
                ),
                notarizationCredentials: config.notarizationCredentials,
                options: config.options,
                paths: config.paths
            )
            updated = true
        }
        
        if updated {
            try configManager.updateConfiguration(config)
            print("✅ Configuration updated")
        } else {
            print("No changes to configuration")
        }
    }
}