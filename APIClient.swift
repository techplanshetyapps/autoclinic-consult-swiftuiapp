//
//  APIClient.swift
//  AutoClinicConsult
//
//  Thin async/await client matching autoclinic-consult-api's exact response
//  shapes (index.js), same pattern as the reference app's APIClient.
//  No dataset, embeddings, or model weights are ever downloaded to the
//  iPad — this client only ever sees the final ingest/query JSON.
//

import Foundation

struct IngestResponse: Decodable {
    let message: String
    let recordsIngested: Int
    let chunksIngested: Int
    let sample: [String]
}

struct QuerySource: Decodable, Identifiable {
    var id: String { text.prefix(24) + String(score) }
    let text: String
    let score: Double
    let subjectName: String?
    let topicName: String?
    let choiceType: String?
    let correctOption: String?
}

struct QueryResponse: Decodable {
    let answer: String
    let provider: String
    let model: String
    let sources: [QuerySource]
}

struct HealthResponse: Decodable {
    let status: String
    let recordsIndexed: Int
}

enum APIError: Error, LocalizedError {
    case badStatus(Int)
    case decoding

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Server returned status \(code)"
        case .decoding: return "Could not decode server response"
        }
    }
}

final class APIClient {
    // Point this at your Render deployment, e.g.
    // "https://autoclinic-consult-api.onrender.com"
    static let baseURL = URL(string: "https://autoclinic-consult-api.onrender.com")!

    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    func health() async throws -> HealthResponse {
        try await get("/api/health")
    }

    func ingest(limit: Int, subjectName: String?, topicName: String?, choiceType: String?, correctOption: String?) async throws -> IngestResponse {
        var body: [String: Any] = ["limit": limit]
        if let subjectName { body["subjectName"] = subjectName }
        if let topicName { body["topicName"] = topicName }
        if let choiceType { body["choiceType"] = choiceType }
        if let correctOption { body["correctOption"] = correctOption }
        return try await post("/api/ingest", body: body)
    }

    func query(_ question: String, topK: Int = 4) async throws -> QueryResponse {
        try await post("/api/query", body: ["question": question, "topK": topK])
    }

    // MARK: - HTTP helpers

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let url = Self.baseURL.appendingPathComponent(path)
        let (data, response) = try await session.data(from: url)
        try Self.validate(response)
        return try Self.decode(data)
    }

    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        var request = URLRequest(url: Self.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        try Self.validate(response)
        return try Self.decode(data)
    }

    private static func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError.badStatus(code)
        }
    }

    private static func decode<T: Decodable>(_ data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }
}
