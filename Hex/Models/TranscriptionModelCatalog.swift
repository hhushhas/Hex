import Foundation

enum TranscriptionModelCatalog {
  static func source(for modelID: String) -> TranscriptionModelSource {
    if GroqTranscriptionModel(rawValue: modelID) != nil {
      return .groq
    }
    return .local
  }

  static func isCloud(_ modelID: String) -> Bool {
    source(for: modelID) != .local
  }
}

enum TranscriptionModelSource: Sendable {
  case local
  case groq
}

enum GroqTranscriptionModel: String, CaseIterable, Sendable {
  case whisperLargeV3 = "whisper-large-v3"
  case whisperLargeV3Turbo = "whisper-large-v3-turbo"

  var providerName: String { "Groq" }
}
