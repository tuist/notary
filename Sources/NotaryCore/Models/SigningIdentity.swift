import Foundation
import Crypto

public struct SigningIdentity: Sendable {
    public let certificate: Certificate
    public let privateKey: Data
    public let type: CertificateType
    public let teamIdentifier: String?
    
    public init(
        certificate: Certificate,
        privateKey: Data,
        type: CertificateType,
        teamIdentifier: String? = nil
    ) {
        self.certificate = certificate
        self.privateKey = privateKey
        self.type = type
        self.teamIdentifier = teamIdentifier
    }
    
    public var isValid: Bool {
        return certificate.isValid
    }
    
    public var displayName: String {
        if let teamId = teamIdentifier {
            return "\(certificate.commonName) (\(teamId))"
        }
        return certificate.commonName
    }
}

public struct SigningConfiguration: Sendable {
    public let identity: SigningIdentity
    public let entitlements: Entitlements?
    public let timestamp: Bool
    public let hardenedRuntime: Bool
    public let deepSign: Bool
    public let force: Bool
    
    public init(
        identity: SigningIdentity,
        entitlements: Entitlements? = nil,
        timestamp: Bool = true,
        hardenedRuntime: Bool = true,
        deepSign: Bool = true,
        force: Bool = false
    ) {
        self.identity = identity
        self.entitlements = entitlements
        self.timestamp = timestamp
        self.hardenedRuntime = hardenedRuntime
        self.deepSign = deepSign
        self.force = force
    }
}

public struct Entitlements: Sendable {
    public let plistData: Data
    public let permissions: Set<String>
    
    public init(plistData: Data) throws {
        self.plistData = plistData
        
        let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil)
        guard let dict = plist as? [String: Any] else {
            throw SigningError.invalidEntitlements
        }
        
        self.permissions = Set(dict.keys)
    }
    
    public static func from(file: URL) throws -> Entitlements {
        let data = try Data(contentsOf: file)
        return try Entitlements(plistData: data)
    }
}

public enum SigningError: Error, LocalizedError {
    case invalidEntitlements
    case signingFailed(reason: String)
    case identityNotFound
    case invalidBinary
    case codesignNotFound
    
    public var errorDescription: String? {
        switch self {
        case .invalidEntitlements:
            return "Invalid entitlements file"
        case .signingFailed(let reason):
            return "Signing failed: \(reason)"
        case .identityNotFound:
            return "Signing identity not found in keychain"
        case .invalidBinary:
            return "Invalid binary or bundle"
        case .codesignNotFound:
            return "codesign tool not found"
        }
    }
}