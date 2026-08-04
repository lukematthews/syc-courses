import Foundation

struct ActivationResponse: Decodable, Sendable { let entitlement: EntitlementEnvelope; let refreshCredential: String }
struct RefreshResponse: Decodable, Sendable { let entitlement: EntitlementEnvelope }

enum LicensingAPIError: Error, LocalizedError {
    case invalidResponse, server(String)
    var errorDescription: String? { switch self { case .invalidResponse: "The licensing service returned an invalid response."; case .server(let code): code } }
}

struct LicensingAPIClient: Sendable {
    let endpoint: URL
    let session: URLSession

    func activate(code: String, installationId: String, appVersion: String, platform: String) async throws -> ActivationResponse {
        try await post("v1/activations", body: ["invitationCode": code, "installationId": installationId, "appVersion": appVersion, "platform": platform])
    }

    func refresh(credential: String, installationId: String, appVersion: String) async throws -> RefreshResponse {
        try await post("v1/entitlements/refresh", body: ["refreshCredential": credential, "installationId": installationId, "appVersion": appVersion])
    }

    private func post<T: Decodable>(_ path: String, body: [String: String]) async throws -> T {
        var request = URLRequest(url: endpoint.appendingPathComponent(path))
        request.httpMethod = "POST"; request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LicensingAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let code = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]).flatMap { $0["error"] as? [String: Any] }?["code"] as? String
            throw LicensingAPIError.server(code ?? "TEMPORARY_SERVER_ERROR")
        }
        do { return try JSONDecoder().decode(T.self, from: data) } catch { throw LicensingAPIError.invalidResponse }
    }
}
