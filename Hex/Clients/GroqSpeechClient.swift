import Foundation
import HexCore

private struct GroqTranscriptionResponse: Decodable {
  let text: String
}

private struct GroqErrorEnvelope: Decodable {
  struct Payload: Decodable {
    let message: String?
  }

  let error: Payload
}

enum GroqSpeechClientError: LocalizedError {
  case missingAPIKey
  case invalidResponse
  case apiError(String)

  var errorDescription: String? {
    switch self {
    case .missingAPIKey:
      return "Add a Groq API key in Settings before using Groq transcription."
    case .invalidResponse:
      return "Groq returned an invalid transcription response."
    case let .apiError(message):
      return message
    }
  }
}

actor GroqSpeechClient {
  private let session: URLSession
  private let endpoint = URL(string: "https://api.groq.com/openai/v1/audio/transcriptions")!
  private let logger = HexLog.groq

  init(session: URLSession = .shared) {
    self.session = session
  }

  func transcribe(url: URL, model: GroqTranscriptionModel, language: String?) async throws -> String {
    guard let apiKey = try GroqAPIKeyStore.load(), !apiKey.isEmpty else {
      throw GroqSpeechClientError.missingAPIKey
    }

    let fileData = try Data(contentsOf: url)
    var request = URLRequest(url: endpoint)
    request.httpMethod = "POST"

    let boundary = "Boundary-\(UUID().uuidString)"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
    request.httpBody = makeMultipartBody(
      boundary: boundary,
      fileData: fileData,
      filename: url.lastPathComponent,
      mimeType: mimeType(for: url),
      model: model.rawValue,
      language: language
    )

    logger.notice("Submitting Groq transcription model=\(model.rawValue, privacy: .public) file=\(url.lastPathComponent, privacy: .private)")
    let (data, response) = try await session.data(for: request)
    guard let http = response as? HTTPURLResponse else {
      throw GroqSpeechClientError.invalidResponse
    }

    guard (200 ..< 300).contains(http.statusCode) else {
      if
        let envelope = try? JSONDecoder().decode(GroqErrorEnvelope.self, from: data),
        let message = envelope.error.message,
        !message.isEmpty
      {
        throw GroqSpeechClientError.apiError(message)
      }
      if let fallback = String(data: data, encoding: .utf8), !fallback.isEmpty {
        throw GroqSpeechClientError.apiError(fallback)
      }
      throw GroqSpeechClientError.apiError("Groq request failed with status \(http.statusCode).")
    }

    guard let transcription = try? JSONDecoder().decode(GroqTranscriptionResponse.self, from: data) else {
      throw GroqSpeechClientError.invalidResponse
    }
    return transcription.text
  }

  private func makeMultipartBody(
    boundary: String,
    fileData: Data,
    filename: String,
    mimeType: String,
    model: String,
    language: String?
  ) -> Data {
    var body = Data()

    func append(_ string: String) {
      body.append(Data(string.utf8))
    }

    func appendField(name: String, value: String) {
      append("--\(boundary)\r\n")
      append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
      append("\(value)\r\n")
    }

    appendField(name: "model", value: model)
    appendField(name: "response_format", value: "json")
    appendField(name: "temperature", value: "0")
    if let language, !language.isEmpty {
      appendField(name: "language", value: language)
    }

    append("--\(boundary)\r\n")
    append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
    append("Content-Type: \(mimeType)\r\n\r\n")
    body.append(fileData)
    append("\r\n")
    append("--\(boundary)--\r\n")
    return body
  }

  private func mimeType(for url: URL) -> String {
    switch url.pathExtension.lowercased() {
    case "wav":
      return "audio/wav"
    case "mp3":
      return "audio/mpeg"
    case "m4a":
      return "audio/m4a"
    case "ogg":
      return "audio/ogg"
    case "webm":
      return "audio/webm"
    default:
      return "application/octet-stream"
    }
  }
}
