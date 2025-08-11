import Foundation
import AsyncHTTPClient
import NIOCore
import NIOHTTP1

public actor NotarizationService {
    private let httpClient: HTTPClient
    private let processRunner: ProcessRunner
    private let pollInterval: TimeInterval = 30
    private let maxPollAttempts: Int = 120
    
    public init(httpClient: HTTPClient? = nil, processRunner: ProcessRunner = ProcessRunner()) {
        self.httpClient = httpClient ?? HTTPClient(eventLoopGroupProvider: .singleton)
        self.processRunner = processRunner
    }
    
    deinit {
        try? httpClient.syncShutdown()
    }
    
    public func notarize(_ request: NotarizationRequest) async throws -> NotarizationResult {
        var mutableRequest = request
        
        mutableRequest.status = .inProgress
        
        let uploadResult = try await uploadForNotarization(request)
        mutableRequest.requestUUID = uploadResult.requestUUID
        
        let finalStatus = try await pollNotarizationStatus(requestUUID: uploadResult.requestUUID, credentials: request)
        
        mutableRequest.status = finalStatus.status
        
        if finalStatus.status == .success {
            try await stapleNotarization(to: request.filePath, requestUUID: uploadResult.requestUUID)
        }
        
        let issues = finalStatus.status == .invalid ? try await fetchNotarizationLog(requestUUID: uploadResult.requestUUID, credentials: request) : []
        
        return NotarizationResult(
            request: mutableRequest,
            status: finalStatus.status,
            logFileURL: finalStatus.logFileURL,
            issues: issues
        )
    }
    
    public func submitForNotarization(at path: URL, credentials: Credentials) async throws -> String {
        let arguments = [
            "xcrun", "notarytool", "submit",
            path.path,
            "--apple-id", credentials.username,
            "--password", credentials.password,
            "--team-id", credentials.teamId,
            "--wait",
            "--output-format", "json"
        ]
        
        let result = try await processRunner.run(arguments: arguments)
        
        guard result.exitCode == 0 else {
            throw NotarizationError.uploadFailed(reason: result.standardError)
        }
        
        guard let data = result.standardOutput.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let requestId = json["id"] as? String else {
            throw NotarizationError.uploadFailed(reason: "Failed to parse response")
        }
        
        return requestId
    }
    
    public func checkStatus(requestId: String, credentials: Credentials) async throws -> NotarizationStatus {
        let arguments = [
            "xcrun", "notarytool", "info",
            requestId,
            "--apple-id", credentials.username,
            "--password", credentials.password,
            "--team-id", credentials.teamId,
            "--output-format", "json"
        ]
        
        let result = try await processRunner.run(arguments: arguments)
        
        guard result.exitCode == 0 else {
            throw NotarizationError.statusCheckFailed
        }
        
        guard let data = result.standardOutput.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let statusString = json["status"] as? String else {
            throw NotarizationError.statusCheckFailed
        }
        
        return NotarizationStatus(rawValue: statusString.lowercased()) ?? .pending
    }
    
    public func getLog(requestId: String, credentials: Credentials) async throws -> String {
        let arguments = [
            "xcrun", "notarytool", "log",
            requestId,
            "--apple-id", credentials.username,
            "--password", credentials.password,
            "--team-id", credentials.teamId
        ]
        
        let result = try await processRunner.run(arguments: arguments)
        
        guard result.exitCode == 0 else {
            throw NotarizationError.statusCheckFailed
        }
        
        return result.standardOutput
    }
    
    private func uploadForNotarization(_ request: NotarizationRequest) async throws -> UploadResult {
        let zipPath = try await createZipArchive(from: request.filePath)
        defer { try? FileManager.default.removeItem(at: zipPath) }
        
        let credentials = Credentials(
            username: request.username,
            password: request.password,
            teamId: request.teamId
        )
        
        let requestId = try await submitForNotarization(at: zipPath, credentials: credentials)
        
        return UploadResult(requestUUID: requestId, uploadURL: nil)
    }
    
    private func pollNotarizationStatus(requestUUID: String, credentials: NotarizationRequest) async throws -> StatusResult {
        let creds = Credentials(
            username: credentials.username,
            password: credentials.password,
            teamId: credentials.teamId
        )
        
        for _ in 0..<maxPollAttempts {
            let status = try await checkStatus(requestId: requestUUID, credentials: creds)
            
            if status.isTerminal {
                return StatusResult(status: status, logFileURL: nil)
            }
            
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        
        throw NotarizationError.timeout
    }
    
    private func fetchNotarizationLog(requestUUID: String, credentials: NotarizationRequest) async throws -> [NotarizationIssue] {
        let creds = Credentials(
            username: credentials.username,
            password: credentials.password,
            teamId: credentials.teamId
        )
        
        let log = try await getLog(requestId: requestUUID, credentials: creds)
        return parseNotarizationLog(log)
    }
    
    private func parseNotarizationLog(_ log: String) -> [NotarizationIssue] {
        var issues: [NotarizationIssue] = []
        
        let lines = log.components(separatedBy: .newlines)
        for line in lines {
            if line.contains("error:") || line.contains("ERROR:") {
                issues.append(NotarizationIssue(
                    severity: .error,
                    message: line,
                    path: nil,
                    code: nil
                ))
            } else if line.contains("warning:") || line.contains("WARNING:") {
                issues.append(NotarizationIssue(
                    severity: .warning,
                    message: line,
                    path: nil,
                    code: nil
                ))
            }
        }
        
        return issues
    }
    
    private func stapleNotarization(to path: URL, requestUUID: String) async throws {
        let arguments = ["xcrun", "stapler", "staple", path.path]
        let result = try await processRunner.run(arguments: arguments)
        
        if result.exitCode != 0 {
            print("⚠️ Warning: Failed to staple notarization ticket: \(result.standardError)")
        }
    }
    
    private func createZipArchive(from path: URL) async throws -> URL {
        let zipPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("zip")
        
        let arguments = ["ditto", "-c", "-k", "--keepParent", path.path, zipPath.path]
        let result = try await processRunner.run(arguments: arguments)
        
        guard result.exitCode == 0 else {
            throw NotarizationError.invalidBundle
        }
        
        return zipPath
    }
}

public struct Credentials {
    public let username: String
    public let password: String
    public let teamId: String
    
    public init(username: String, password: String, teamId: String) {
        self.username = username
        self.password = password
        self.teamId = teamId
    }
}

struct UploadResult {
    let requestUUID: String
    let uploadURL: URL?
}

struct StatusResult {
    let status: NotarizationStatus
    let logFileURL: URL?
}