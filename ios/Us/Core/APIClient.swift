import Foundation

enum APIClientError: LocalizedError {
    case invalidResponse
    case unauthorized
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "The server returned an unexpected response."
        case .unauthorized: return "Your session expired. Please sign in again."
        case .http(let code): return "Request failed (\(code))."
        }
    }
}

/// Type-erased Encodable so we can pass heterogeneous request bodies.
struct AnyEncodable: Encodable {
    private let encodeFunc: (Encoder) throws -> Void
    init(_ wrapped: some Encodable) { encodeFunc = wrapped.encode }
    func encode(to encoder: Encoder) throws { try encodeFunc(encoder) }
}

final class APIClient {
    static let shared = APIClient()

    private let baseURL = APIConfig.baseURL
    private let session = URLSession.shared
    let decoder: JSONDecoder
    let encoder: JSONEncoder

    init() {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .custom { d in
            let container = try d.singleValueContainer()
            let str = try container.decode(String.self)
            if let date = DateParsing.rfc3339Frac.date(from: str) { return date }
            if let date = DateParsing.rfc3339.date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date: \(str)")
        }
        decoder = dec
        encoder = JSONEncoder()
    }

    struct Empty: Codable {}

    @discardableResult
    func send<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: (any Encodable)? = nil,
        authorized: Bool = true
    ) async throws -> T {
        let data = try await raw(path, method: method, body: body, authorized: authorized, retryOn401: true)
        if T.self == Empty.self { return Empty() as! T }
        return try decoder.decode(T.self, from: data)
    }

    func sendVoid(_ path: String, method: String, body: (any Encodable)? = nil, authorized: Bool = true) async throws {
        _ = try await raw(path, method: method, body: body, authorized: authorized, retryOn401: true)
    }

    private func raw(_ path: String, method: String, body: (any Encodable)?, authorized: Bool, retryOn401: Bool) async throws -> Data {
        var req = URLRequest(url: baseURL.appendingPathComponent(path))
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if authorized, let token = TokenStore.accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let body { req.httpBody = try encoder.encode(AnyEncodable(body)) }

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw APIClientError.invalidResponse }

        if http.statusCode == 401 && authorized && retryOn401 {
            if try await refresh() {
                return try await raw(path, method: method, body: body, authorized: authorized, retryOn401: false)
            }
            throw APIClientError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            if let apiErr = try? decoder.decode(APIErrorResponse.self, from: data) { throw apiErr }
            throw APIClientError.http(http.statusCode)
        }
        return data
    }

    /// Attempts to rotate the refresh token. Returns true on success.
    private func refresh() async throws -> Bool {
        guard let rt = TokenStore.refreshToken else { return false }
        var req = URLRequest(url: baseURL.appendingPathComponent("/v1/auth/refresh"))
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try encoder.encode(["refreshToken": rt])

        let (data, response) = try await session.data(for: req)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            TokenStore.clear()
            return false
        }
        let auth = try decoder.decode(AuthResponse.self, from: data)
        TokenStore.accessToken = auth.accessToken
        TokenStore.refreshToken = auth.refreshToken
        return true
    }

    // MARK: - Media (raw bytes + multipart upload)

    /// Authenticated GET returning raw bytes (used for loading images).
    func fetchData(_ path: String) async throws -> Data {
        try await raw(path, method: "GET", body: nil, authorized: true, retryOn401: true)
    }

    /// Uploads a single image as multipart/form-data and returns the JSON response.
    func uploadImage(_ path: String, imageData: Data, filename: String, caption: String?) async throws -> Data {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        func appendString(_ s: String) { body.append(s.data(using: .utf8)!) }
        appendString("--\(boundary)\r\n")
        appendString("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        appendString("Content-Type: image/jpeg\r\n\r\n")
        body.append(imageData)
        appendString("\r\n")
        if let caption, !caption.isEmpty {
            appendString("--\(boundary)\r\n")
            appendString("Content-Disposition: form-data; name=\"caption\"\r\n\r\n")
            appendString(caption)
            appendString("\r\n")
        }
        appendString("--\(boundary)--\r\n")

        func makeRequest() -> URLRequest {
            var req = URLRequest(url: baseURL.appendingPathComponent(path))
            req.httpMethod = "POST"
            req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            if let token = TokenStore.accessToken {
                req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
            req.httpBody = body
            return req
        }

        var (data, response) = try await session.data(for: makeRequest())
        if (response as? HTTPURLResponse)?.statusCode == 401, try await refresh() {
            (data, response) = try await session.data(for: makeRequest())
        }
        guard let status = (response as? HTTPURLResponse)?.statusCode else {
            throw APIClientError.invalidResponse
        }
        guard (200..<300).contains(status) else {
            if let apiErr = try? decoder.decode(APIErrorResponse.self, from: data) { throw apiErr }
            throw APIClientError.http(status)
        }
        return data
    }
}

enum DateParsing {
    static let rfc3339Frac: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static let rfc3339: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
}
