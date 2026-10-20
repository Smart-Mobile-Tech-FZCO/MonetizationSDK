import Foundation

enum APIClientError: Error, Equatable {
    case encoding
    case network(URLError.Code?)
    case httpStatus(Int)
    case emptyBody
    case decoding
}

/// Sends one envelope and returns the decoded response. Stubbed in tests.
protocol PaymentAPIClient: Sendable {
    func send(_ envelope: RequestEnvelope, to url: URL) async throws -> APIResponse
}

struct URLSessionAPIClient: PaymentAPIClient {
    static let timeout: TimeInterval = 30

    let session: URLSession
    let logger: SDKLogger

    init(session: URLSession = .shared, logger: SDKLogger) {
        self.session = session
        self.logger = logger
    }

    func send(_ envelope: RequestEnvelope, to url: URL) async throws -> APIResponse {
        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        do {
            request.httpBody = try JSONEncoder().encode(envelope)
        } catch {
            throw APIClientError.encoding
        }

        logger.log("→ Action \(envelope.request.action.rawValue) \(url.host ?? url.absoluteString) "
                   + "tx=\(envelope.request.transactionID) session=\(envelope.request.sessionID ?? "-") "
                   + "phn=\(SDKLogger.mask(envelope.request.phn)) pin=\(envelope.request.pinCode == nil ? "-" : "***")")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.log("✗ Action \(envelope.request.action.rawValue) network error: \(error.localizedDescription)")
            throw APIClientError.network((error as? URLError)?.code)
        }

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            logger.log("✗ Action \(envelope.request.action.rawValue) HTTP \(http.statusCode)")
            throw APIClientError.httpStatus(http.statusCode)
        }
        guard !data.isEmpty else { throw APIClientError.emptyBody }

        do {
            let decoded = try JSONDecoder().decode(APIResponse.self, from: data)
            logger.log("← Action \(envelope.request.action.rawValue) Error=\(decoded.error) "
                       + "NextAction=\(decoded.nextAction?.action.map(String.init) ?? "-") "
                       + "Message=\(decoded.message ?? "-")")
            return decoded
        } catch {
            logger.log("✗ Action \(envelope.request.action.rawValue) undecodable body (\(data.count) bytes)")
            throw APIClientError.decoding
        }
    }
}

/// The three backend calls, routed to the right endpoint.
struct PaymentAPI: Sendable {
    let client: PaymentAPIClient
    let initiateURL: URL
    let apiURL: URL

    func send(_ envelope: RequestEnvelope) async throws -> APIResponse {
        let url = envelope.request.action == .initiate ? initiateURL : apiURL
        return try await client.send(envelope, to: url)
    }
}

struct SDKLogger: Sendable {
    let isEnabled: Bool

    func log(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        print("[PaymentSDK] \(message())")
    }

    /// `"96171020136"` → `"9617•••••36"`.
    static func mask(_ phone: String?) -> String {
        guard let phone, !phone.isEmpty else { return "-" }
        guard phone.count > 6 else { return String(repeating: "•", count: phone.count) }
        return phone.prefix(4) + String(repeating: "•", count: phone.count - 6) + phone.suffix(2)
    }
}
