import Foundation
import Crypto

public actor CodeSigningService {
    private let processRunner: ProcessRunner
    
    public init(processRunner: ProcessRunner = ProcessRunner()) {
        self.processRunner = processRunner
    }
    
    public func sign(at path: URL, with configuration: SigningConfiguration) async throws {
        var arguments = ["codesign"]
        
        if configuration.force {
            arguments.append("--force")
        }
        
        if configuration.deepSign {
            arguments.append("--deep")
        }
        
        if configuration.timestamp {
            arguments.append("--timestamp")
        }
        
        if configuration.hardenedRuntime {
            arguments.append("--options")
            arguments.append("runtime")
        }
        
        arguments.append("--sign")
        arguments.append(configuration.identity.displayName)
        
        if let entitlements = configuration.entitlements {
            let entitlementsPath = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("plist")
            
            try entitlements.plistData.write(to: entitlementsPath)
            defer { try? FileManager.default.removeItem(at: entitlementsPath) }
            
            arguments.append("--entitlements")
            arguments.append(entitlementsPath.path)
        }
        
        arguments.append(path.path)
        
        let result = try await processRunner.run(arguments: arguments)
        
        if result.exitCode != 0 {
            throw SigningError.signingFailed(reason: result.standardError)
        }
    }
    
    public func verify(at path: URL, deep: Bool = true) async throws -> Bool {
        var arguments = ["codesign", "--verify"]
        
        if deep {
            arguments.append("--deep")
        }
        
        arguments.append("--strict")
        arguments.append("--verbose=2")
        arguments.append(path.path)
        
        let result = try await processRunner.run(arguments: arguments)
        return result.exitCode == 0
    }
    
    public func extractSigningInfo(from path: URL) async throws -> SigningInfo {
        let arguments = ["codesign", "--display", "--verbose=4", path.path]
        let result = try await processRunner.run(arguments: arguments)
        
        guard result.exitCode == 0 else {
            throw SigningError.invalidBinary
        }
        
        return try parseSigningInfo(from: result.standardError)
    }
    
    public func removeSignature(from path: URL) async throws {
        let arguments = ["codesign", "--remove-signature", path.path]
        let result = try await processRunner.run(arguments: arguments)
        
        if result.exitCode != 0 {
            throw SigningError.signingFailed(reason: "Failed to remove signature")
        }
    }
    
    public func listIdentities() async throws -> [SigningIdentity] {
        let arguments = ["security", "find-identity", "-v", "-p", "codesigning"]
        let result = try await processRunner.run(arguments: arguments)
        
        guard result.exitCode == 0 else {
            throw SigningError.identityNotFound
        }
        
        return try parseIdentities(from: result.standardOutput)
    }
    
    private func parseSigningInfo(from output: String) throws -> SigningInfo {
        var info = SigningInfo()
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("Authority=") {
                info.authorities.append(line.replacingOccurrences(of: "Authority=", with: "").trimmingCharacters(in: .whitespaces))
            } else if line.contains("TeamIdentifier=") {
                info.teamIdentifier = line.replacingOccurrences(of: "TeamIdentifier=", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.contains("Identifier=") {
                info.identifier = line.replacingOccurrences(of: "Identifier=", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.contains("Format=") {
                info.format = line.replacingOccurrences(of: "Format=", with: "").trimmingCharacters(in: .whitespaces)
            } else if line.contains("Signature=") {
                info.signatureSize = line.replacingOccurrences(of: "Signature=", with: "").trimmingCharacters(in: .whitespaces)
            }
        }
        
        return info
    }
    
    private func parseIdentities(from output: String) throws -> [SigningIdentity] {
        var identities: [SigningIdentity] = []
        
        let lines = output.components(separatedBy: .newlines)
        for line in lines {
            guard line.contains(")") && line.contains("\"") else { continue }
            
            let components = line.components(separatedBy: "\"")
            guard components.count >= 2 else { continue }
            
            let name = components[1]
            let certificate = Certificate(
                commonName: name,
                organizationName: "",
                organizationUnit: "",
                countryName: "",
                serialNumber: UUID().uuidString,
                issuer: "",
                subject: name,
                notBefore: Date(),
                notAfter: Date().addingTimeInterval(365 * 24 * 60 * 60),
                publicKey: Data(),
                signature: Data(),
                rawData: Data()
            )
            
            let type: CertificateType
            if name.contains("Developer ID Application") {
                type = .developerID
            } else if name.contains("Apple Distribution") {
                type = .appleDistribution
            } else if name.contains("Mac Developer") {
                type = .macInstaller
            } else {
                type = .custom(name)
            }
            
            let identity = SigningIdentity(
                certificate: certificate,
                privateKey: Data(),
                type: type,
                teamIdentifier: extractTeamId(from: line)
            )
            
            identities.append(identity)
        }
        
        return identities
    }
    
    private func extractTeamId(from line: String) -> String? {
        if let range = line.range(of: "\\([A-Z0-9]+\\)", options: .regularExpression) {
            let teamId = String(line[range])
            return String(teamId.dropFirst().dropLast())
        }
        return nil
    }
}

public struct SigningInfo: Sendable {
    public var identifier: String?
    public var format: String?
    public var teamIdentifier: String?
    public var authorities: [String] = []
    public var signatureSize: String?
    public var isHardenedRuntime: Bool = false
    public var timestamp: Date?
    
    public init() {}
}

public actor ProcessRunner {
    public init() {}
    
    public func run(arguments: [String]) async throws -> ProcessResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = arguments
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        try process.run()
        process.waitUntilExit()
        
        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        
        return ProcessResult(
            exitCode: Int(process.terminationStatus),
            standardOutput: String(data: outputData, encoding: .utf8) ?? "",
            standardError: String(data: errorData, encoding: .utf8) ?? ""
        )
    }
}

public struct ProcessResult: Sendable {
    public let exitCode: Int
    public let standardOutput: String
    public let standardError: String
}