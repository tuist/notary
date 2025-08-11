import XCTest
@testable import NotaryCore

final class CertificateTests: XCTestCase {
    func testCertificateValidity() {
        let validCert = Certificate(
            commonName: "Test Developer",
            organizationName: "Test Org",
            organizationUnit: "Development",
            countryName: "US",
            serialNumber: "12345",
            issuer: "Apple Worldwide Developer Relations",
            subject: "Test Developer",
            notBefore: Date().addingTimeInterval(-86400),
            notAfter: Date().addingTimeInterval(86400 * 365),
            publicKey: Data(),
            signature: Data(),
            rawData: Data()
        )
        
        XCTAssertTrue(validCert.isValid)
        XCTAssertFalse(validCert.isExpired)
        XCTAssertGreaterThan(validCert.daysUntilExpiration, 360)
    }
    
    func testExpiredCertificate() {
        let expiredCert = Certificate(
            commonName: "Expired Developer",
            organizationName: "Test Org",
            organizationUnit: "Development",
            countryName: "US",
            serialNumber: "12345",
            issuer: "Apple Worldwide Developer Relations",
            subject: "Expired Developer",
            notBefore: Date().addingTimeInterval(-86400 * 400),
            notAfter: Date().addingTimeInterval(-86400),
            publicKey: Data(),
            signature: Data(),
            rawData: Data()
        )
        
        XCTAssertFalse(expiredCert.isValid)
        XCTAssertTrue(expiredCert.isExpired)
        XCTAssertLessThan(expiredCert.daysUntilExpiration, 0)
    }
    
    func testCertificateChainValidation() throws {
        let leafCert = Certificate(
            commonName: "Leaf Certificate",
            organizationName: "Test Org",
            organizationUnit: "Development",
            countryName: "US",
            serialNumber: "1",
            issuer: "Intermediate CA",
            subject: "Leaf Certificate",
            notBefore: Date().addingTimeInterval(-86400),
            notAfter: Date().addingTimeInterval(86400 * 365),
            publicKey: Data(),
            signature: Data(),
            rawData: Data()
        )
        
        let intermediateCert = Certificate(
            commonName: "Intermediate CA",
            organizationName: "Test Org",
            organizationUnit: "CA",
            countryName: "US",
            serialNumber: "2",
            issuer: "Root CA",
            subject: "Intermediate CA",
            notBefore: Date().addingTimeInterval(-86400 * 365),
            notAfter: Date().addingTimeInterval(86400 * 365 * 2),
            publicKey: Data(),
            signature: Data(),
            rawData: Data()
        )
        
        let rootCert = Certificate(
            commonName: "Root CA",
            organizationName: "Test Org",
            organizationUnit: "Root",
            countryName: "US",
            serialNumber: "3",
            issuer: "Root CA",
            subject: "Root CA",
            notBefore: Date().addingTimeInterval(-86400 * 365 * 2),
            notAfter: Date().addingTimeInterval(86400 * 365 * 5),
            publicKey: Data(),
            signature: Data(),
            rawData: Data()
        )
        
        let chain = try CertificateChain(certificates: [leafCert, intermediateCert, rootCert])
        
        XCTAssertEqual(chain.leafCertificate.commonName, "Leaf Certificate")
        XCTAssertEqual(chain.intermediateCertificates.count, 1)
        XCTAssertEqual(chain.rootCertificate?.commonName, "Root CA")
        
        XCTAssertNoThrow(try chain.validate())
    }
    
    func testCertificateTypes() {
        XCTAssertEqual(CertificateType.developerID.identifier, "Developer ID Application")
        XCTAssertEqual(CertificateType.appleDistribution.identifier, "Apple Distribution")
        XCTAssertEqual(CertificateType.macInstaller.identifier, "3rd Party Mac Developer Installer")
        XCTAssertEqual(CertificateType.developerIDInstaller.identifier, "Developer ID Installer")
        XCTAssertEqual(CertificateType.custom("Custom Type").identifier, "Custom Type")
    }
}