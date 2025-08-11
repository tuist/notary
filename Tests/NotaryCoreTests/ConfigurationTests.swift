import XCTest
@testable import NotaryCore

final class ConfigurationTests: XCTestCase {
    var tempConfigURL: URL!
    
    override func setUp() {
        super.setUp()
        tempConfigURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }
    
    override func tearDown() {
        try? FileManager.default.removeItem(at: tempConfigURL)
        super.tearDown()
    }
    
    func testDefaultConfiguration() {
        let config = NotaryConfiguration()
        
        XCTAssertNil(config.signingIdentity)
        XCTAssertNil(config.notarizationCredentials)
        XCTAssertTrue(config.options.deepSign)
        XCTAssertTrue(config.options.hardenedRuntime)
        XCTAssertTrue(config.options.timestamp)
        XCTAssertFalse(config.options.force)
    }
    
    func testConfigurationSaveAndLoad() throws {
        let originalConfig = NotaryConfiguration(
            signingIdentity: SigningIdentityConfiguration(
                name: "Developer ID Application: Test",
                teamIdentifier: "TEAM123"
            ),
            notarizationCredentials: NotarizationCredentialsConfiguration(
                appleId: "test@example.com",
                teamId: "TEAM123",
                password: "secret"
            ),
            options: SigningOptions(
                deepSign: false,
                force: true
            )
        )
        
        try originalConfig.save(to: tempConfigURL)
        
        let loadedConfig = try NotaryConfiguration.load(from: tempConfigURL)
        
        XCTAssertEqual(loadedConfig.signingIdentity?.name, "Developer ID Application: Test")
        XCTAssertEqual(loadedConfig.signingIdentity?.teamIdentifier, "TEAM123")
        XCTAssertEqual(loadedConfig.notarizationCredentials?.appleId, "test@example.com")
        XCTAssertFalse(loadedConfig.options.deepSign)
        XCTAssertTrue(loadedConfig.options.force)
    }
    
    func testCredentialsValidation() {
        let invalidCreds1 = NotarizationCredentialsConfiguration()
        XCTAssertFalse(invalidCreds1.isValid)
        
        let validCredsKeychain = NotarizationCredentialsConfiguration(
            keychainProfile: "MyProfile"
        )
        XCTAssertTrue(validCredsKeychain.isValid)
        
        let validCredsAPI = NotarizationCredentialsConfiguration(
            apiKey: "key123",
            apiIssuer: "issuer456"
        )
        XCTAssertTrue(validCredsAPI.isValid)
        
        let validCredsPassword = NotarizationCredentialsConfiguration(
            appleId: "user@example.com",
            teamId: "TEAM123",
            password: "secret"
        )
        XCTAssertTrue(validCredsPassword.isValid)
        
        let incompleteCreds = NotarizationCredentialsConfiguration(
            appleId: "user@example.com",
            teamId: "TEAM123"
        )
        XCTAssertFalse(incompleteCreds.isValid)
    }
    
    func testPathConfiguration() {
        let paths = PathConfiguration(
            outputDirectory: "~/Desktop/signed",
            tempDirectory: "/var/tmp/notary",
            logDirectory: "~/.notary/logs"
        )
        
        XCTAssertTrue(paths.resolvedOutputDirectory.path.contains("Desktop/signed"))
        XCTAssertEqual(paths.resolvedTempDirectory.path, "/var/tmp/notary")
        XCTAssertTrue(paths.resolvedLogDirectory.path.contains(".notary/logs"))
    }
}