import XCTest
@testable import NotaryCore

final class NotarizationTests: XCTestCase {
    func testNotarizationRequestCreation() {
        let request = NotarizationRequest(
            bundleIdentifier: "com.example.app",
            filePath: URL(fileURLWithPath: "/path/to/app.app"),
            teamId: "TEAM123",
            username: "user@example.com",
            password: "secret"
        )
        
        XCTAssertEqual(request.bundleIdentifier, "com.example.app")
        XCTAssertEqual(request.teamId, "TEAM123")
        XCTAssertEqual(request.username, "user@example.com")
        XCTAssertEqual(request.status, .pending)
        XCTAssertNil(request.requestUUID)
    }
    
    func testNotarizationStatusTerminal() {
        XCTAssertTrue(NotarizationStatus.success.isTerminal)
        XCTAssertTrue(NotarizationStatus.invalid.isTerminal)
        XCTAssertTrue(NotarizationStatus.failed.isTerminal)
        XCTAssertTrue(NotarizationStatus.rejected.isTerminal)
        XCTAssertFalse(NotarizationStatus.pending.isTerminal)
        XCTAssertFalse(NotarizationStatus.inProgress.isTerminal)
    }
    
    func testNotarizationResult() {
        let request = NotarizationRequest(
            bundleIdentifier: "com.example.app",
            filePath: URL(fileURLWithPath: "/path/to/app.app"),
            teamId: "TEAM123",
            username: "user@example.com",
            password: "secret",
            createdAt: Date().addingTimeInterval(-300)
        )
        
        let issues = [
            NotarizationIssue(
                severity: .error,
                message: "Missing entitlement",
                path: "Contents/MacOS/App",
                code: "MISSING_ENTITLEMENT"
            ),
            NotarizationIssue(
                severity: .warning,
                message: "Deprecated API usage",
                path: nil,
                code: "DEPRECATED_API"
            )
        ]
        
        let result = NotarizationResult(
            request: request,
            status: .invalid,
            logFileURL: URL(fileURLWithPath: "/tmp/log.txt"),
            issues: issues
        )
        
        XCTAssertEqual(result.status, .invalid)
        XCTAssertEqual(result.issues.count, 2)
        XCTAssertEqual(result.issues.filter { $0.severity == .error }.count, 1)
        XCTAssertGreaterThan(result.duration, 0)
    }
    
    func testNotarizationErrorDescriptions() {
        let invalidCredsError = NotarizationError.invalidCredentials
        XCTAssertEqual(invalidCredsError.errorDescription, "Invalid Apple ID credentials")
        
        let uploadError = NotarizationError.uploadFailed(reason: "Network timeout")
        XCTAssertEqual(uploadError.errorDescription, "Upload failed: Network timeout")
        
        let timeoutError = NotarizationError.timeout
        XCTAssertEqual(timeoutError.errorDescription, "Notarization timed out")
        
        let issues = [
            NotarizationIssue(severity: .error, message: "Error 1"),
            NotarizationIssue(severity: .error, message: "Error 2"),
            NotarizationIssue(severity: .warning, message: "Warning 1")
        ]
        let failedError = NotarizationError.notarizationFailed(issues: issues)
        XCTAssertEqual(failedError.errorDescription, "Notarization failed with 2 error(s)")
    }
}