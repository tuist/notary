import Foundation
import Crypto

public struct Certificate: Sendable {
    public let commonName: String
    public let organizationName: String
    public let organizationUnit: String
    public let countryName: String
    public let serialNumber: String
    public let issuer: String
    public let subject: String
    public let notBefore: Date
    public let notAfter: Date
    public let publicKey: Data
    public let signature: Data
    public let rawData: Data
    
    public init(
        commonName: String,
        organizationName: String,
        organizationUnit: String,
        countryName: String,
        serialNumber: String,
        issuer: String,
        subject: String,
        notBefore: Date,
        notAfter: Date,
        publicKey: Data,
        signature: Data,
        rawData: Data
    ) {
        self.commonName = commonName
        self.organizationName = organizationName
        self.organizationUnit = organizationUnit
        self.countryName = countryName
        self.serialNumber = serialNumber
        self.issuer = issuer
        self.subject = subject
        self.notBefore = notBefore
        self.notAfter = notAfter
        self.publicKey = publicKey
        self.signature = signature
        self.rawData = rawData
    }
    
    public var isValid: Bool {
        let now = Date()
        return now >= notBefore && now <= notAfter
    }
    
    public var isExpired: Bool {
        return Date() > notAfter
    }
    
    public var daysUntilExpiration: Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: notAfter)
        return components.day ?? 0
    }
}

public enum CertificateType: Sendable {
    case developerID
    case appleDistribution
    case macInstaller
    case developerIDInstaller
    case custom(String)
    
    public var identifier: String {
        switch self {
        case .developerID:
            return "Developer ID Application"
        case .appleDistribution:
            return "Apple Distribution"
        case .macInstaller:
            return "3rd Party Mac Developer Installer"
        case .developerIDInstaller:
            return "Developer ID Installer"
        case .custom(let id):
            return id
        }
    }
}

public struct CertificateChain: Sendable {
    public let certificates: [Certificate]
    public let rootCertificate: Certificate?
    public let intermediateCertificates: [Certificate]
    public let leafCertificate: Certificate
    
    public init(certificates: [Certificate]) throws {
        guard !certificates.isEmpty else {
            throw CertificateError.emptyCertificateChain
        }
        
        self.certificates = certificates
        self.leafCertificate = certificates.first!
        
        if certificates.count > 1 {
            self.intermediateCertificates = Array(certificates.dropFirst().dropLast())
            self.rootCertificate = certificates.last
        } else {
            self.intermediateCertificates = []
            self.rootCertificate = nil
        }
    }
    
    public func validate() throws {
        for certificate in certificates {
            guard certificate.isValid else {
                throw CertificateError.invalidCertificate(reason: "Certificate expired or not yet valid: \(certificate.commonName)")
            }
        }
    }
}

public enum CertificateError: Error, LocalizedError {
    case emptyCertificateChain
    case invalidCertificate(reason: String)
    case certificateNotFound
    case invalidFormat
    case verificationFailed
    
    public var errorDescription: String? {
        switch self {
        case .emptyCertificateChain:
            return "The certificate chain is empty"
        case .invalidCertificate(let reason):
            return "Invalid certificate: \(reason)"
        case .certificateNotFound:
            return "Certificate not found"
        case .invalidFormat:
            return "Invalid certificate format"
        case .verificationFailed:
            return "Certificate verification failed"
        }
    }
}