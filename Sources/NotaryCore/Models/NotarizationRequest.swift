import Foundation

public struct NotarizationRequest: Sendable {
    public let id: UUID
    public let bundleIdentifier: String
    public let filePath: URL
    public let teamId: String
    public let username: String
    public let password: String
    public let primaryBundleId: String?
    public let createdAt: Date
    public var status: NotarizationStatus
    public var requestUUID: String?
    public var logFileURL: URL?
    
    public init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        filePath: URL,
        teamId: String,
        username: String,
        password: String,
        primaryBundleId: String? = nil,
        createdAt: Date = Date(),
        status: NotarizationStatus = .pending
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.filePath = filePath
        self.teamId = teamId
        self.username = username
        self.password = password
        self.primaryBundleId = primaryBundleId
        self.createdAt = createdAt
        self.status = status
    }
}

public enum NotarizationStatus: String, Sendable {
    case pending
    case inProgress
    case success
    case invalid
    case failed
    case rejected
    
    public var isTerminal: Bool {
        switch self {
        case .success, .invalid, .failed, .rejected:
            return true
        case .pending, .inProgress:
            return false
        }
    }
}

public struct NotarizationResult: Sendable {
    public let request: NotarizationRequest
    public let status: NotarizationStatus
    public let logFileURL: URL?
    public let issues: [NotarizationIssue]
    public let completedAt: Date
    
    public init(
        request: NotarizationRequest,
        status: NotarizationStatus,
        logFileURL: URL? = nil,
        issues: [NotarizationIssue] = [],
        completedAt: Date = Date()
    ) {
        self.request = request
        self.status = status
        self.logFileURL = logFileURL
        self.issues = issues
        self.completedAt = completedAt
    }
    
    public var duration: TimeInterval {
        return completedAt.timeIntervalSince(request.createdAt)
    }
}

public struct NotarizationIssue: Sendable {
    public enum Severity: Sendable {
        case error
        case warning
        case info
    }
    
    public let severity: Severity
    public let message: String
    public let path: String?
    public let code: String?
    
    public init(
        severity: Severity,
        message: String,
        path: String? = nil,
        code: String? = nil
    ) {
        self.severity = severity
        self.message = message
        self.path = path
        self.code = code
    }
}

public enum NotarizationError: Error, LocalizedError {
    case invalidCredentials
    case networkError(Error)
    case uploadFailed(reason: String)
    case statusCheckFailed
    case notarizationFailed(issues: [NotarizationIssue])
    case timeout
    case invalidBundle
    
    public var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid Apple ID credentials"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .statusCheckFailed:
            return "Failed to check notarization status"
        case .notarizationFailed(let issues):
            let errors = issues.filter { $0.severity == .error }
            return "Notarization failed with \(errors.count) error(s)"
        case .timeout:
            return "Notarization timed out"
        case .invalidBundle:
            return "Invalid bundle or archive"
        }
    }
}