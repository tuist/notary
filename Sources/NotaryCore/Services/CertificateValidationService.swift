import Foundation
import Crypto
import Security

public actor CertificateValidationService {
    private let trustedAnchors: [Certificate]
    
    public init(trustedAnchors: [Certificate] = []) {
        self.trustedAnchors = trustedAnchors
    }
    
    public func validateCertificate(_ certificate: Certificate) async throws {
        guard certificate.isValid else {
            if certificate.isExpired {
                throw CertificateError.invalidCertificate(reason: "Certificate has expired")
            } else {
                throw CertificateError.invalidCertificate(reason: "Certificate is not yet valid")
            }
        }
        
        if certificate.daysUntilExpiration < 30 {
            print("⚠️ Warning: Certificate expires in \(certificate.daysUntilExpiration) days")
        }
        
        try await validateCertificateChain(certificate)
    }
    
    public func validateCertificateChain(_ certificate: Certificate) async throws {
        guard isAppleCertificate(certificate) else {
            throw CertificateError.invalidCertificate(reason: "Not an Apple certificate")
        }
        
        try await verifySignature(certificate)
    }
    
    public func importCertificate(from data: Data, password: String? = nil) async throws -> Certificate {
        if let password = password {
            return try await importP12Certificate(data: data, password: password)
        } else {
            return try await importDERCertificate(data: data)
        }
    }
    
    public func exportCertificate(_ certificate: Certificate, includePrivateKey: Bool = false, password: String? = nil) async throws -> Data {
        if includePrivateKey {
            guard let password = password else {
                throw CertificateError.invalidCertificate(reason: "Password required for private key export")
            }
            return try await exportP12Certificate(certificate, password: password)
        } else {
            return certificate.rawData
        }
    }
    
    public func findCertificates(matching query: CertificateQuery) async throws -> [Certificate] {
        let keychainCerts = try await searchKeychain(query: query)
        return keychainCerts.filter { cert in
            query.matches(certificate: cert)
        }
    }
    
    private func isAppleCertificate(_ certificate: Certificate) -> Bool {
        return certificate.issuer.contains("Apple") || 
               certificate.subject.contains("Apple") ||
               certificate.commonName.contains("Developer ID") ||
               certificate.commonName.contains("Apple Distribution") ||
               certificate.commonName.contains("Mac Developer")
    }
    
    private func verifySignature(_ certificate: Certificate) async throws {
        if #available(macOS 10.14, *) {
            guard !certificate.publicKey.isEmpty, !certificate.signature.isEmpty else {
                return
            }
            
            do {
                let publicKey = try P256.Signing.PublicKey(x963Representation: certificate.publicKey)
                let signature = try P256.Signing.ECDSASignature(rawRepresentation: certificate.signature)
                let isValid = publicKey.isValidSignature(
                    signature,
                    for: certificate.rawData
                )
                
                if !isValid {
                    throw CertificateError.verificationFailed
                }
            } catch {
                throw CertificateError.verificationFailed
            }
        }
    }
    
    private func importP12Certificate(data: Data, password: String) async throws -> Certificate {
        var items: CFArray?
        let options = [kSecImportExportPassphrase as String: password] as CFDictionary
        
        let status = SecPKCS12Import(data as CFData, options, &items)
        guard status == errSecSuccess,
              let itemArray = items as? [[String: Any]],
              let firstItem = itemArray.first,
              let identity = firstItem[kSecImportItemIdentity as String] else {
            throw CertificateError.invalidFormat
        }
        
        var certificate: SecCertificate?
        SecIdentityCopyCertificate(identity as! SecIdentity, &certificate)
        
        guard let cert = certificate else {
            throw CertificateError.certificateNotFound
        }
        
        return try parseCertificate(from: cert)
    }
    
    private func importDERCertificate(data: Data) async throws -> Certificate {
        guard let certificate = SecCertificateCreateWithData(nil, data as CFData) else {
            throw CertificateError.invalidFormat
        }
        
        return try parseCertificate(from: certificate)
    }
    
    private func exportP12Certificate(_ certificate: Certificate, password: String) async throws -> Data {
        throw CertificateError.invalidCertificate(reason: "P12 export not implemented")
    }
    
    private func searchKeychain(query: CertificateQuery) async throws -> [Certificate] {
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnRef as String: true
        ]
        
        var items: CFTypeRef?
        let status = SecItemCopyMatching(searchQuery as CFDictionary, &items)
        
        guard status == errSecSuccess,
              let certificates = items as? [SecCertificate] else {
            return []
        }
        
        return certificates.compactMap { try? parseCertificate(from: $0) }
    }
    
    private func parseCertificate(from secCert: SecCertificate) throws -> Certificate {
        guard let data = SecCertificateCopyData(secCert) as Data? else {
            throw CertificateError.invalidFormat
        }
        
        guard let summary = SecCertificateCopySubjectSummary(secCert) as String? else {
            throw CertificateError.invalidFormat
        }
        
        return Certificate(
            commonName: summary,
            organizationName: "",
            organizationUnit: "",
            countryName: "",
            serialNumber: UUID().uuidString,
            issuer: "",
            subject: summary,
            notBefore: Date(),
            notAfter: Date().addingTimeInterval(365 * 24 * 60 * 60),
            publicKey: Data(),
            signature: Data(),
            rawData: data
        )
    }
}

public struct CertificateQuery {
    public let commonName: String?
    public let organizationName: String?
    public let teamIdentifier: String?
    public let type: CertificateType?
    public let onlyValid: Bool
    
    public init(
        commonName: String? = nil,
        organizationName: String? = nil,
        teamIdentifier: String? = nil,
        type: CertificateType? = nil,
        onlyValid: Bool = true
    ) {
        self.commonName = commonName
        self.organizationName = organizationName
        self.teamIdentifier = teamIdentifier
        self.type = type
        self.onlyValid = onlyValid
    }
    
    func matches(certificate: Certificate) -> Bool {
        if onlyValid && !certificate.isValid {
            return false
        }
        
        if let name = commonName, !certificate.commonName.contains(name) {
            return false
        }
        
        if let org = organizationName, !certificate.organizationName.contains(org) {
            return false
        }
        
        if let certType = type {
            let typeString = certType.identifier
            if !certificate.commonName.contains(typeString) {
                return false
            }
        }
        
        return true
    }
}