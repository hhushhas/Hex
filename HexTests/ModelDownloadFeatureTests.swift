import ComposableArchitecture
import Foundation
import HexCore
import Testing

@testable import Hex

@Suite(.serialized)
@MainActor
struct ModelDownloadFeatureTests {
  @Test
  func savingGroqAPIKeyMarksSelectedModelReady() async {
    let groqModel = GroqTranscriptionModel.whisperLargeV3.rawValue
    let otherGroqModel = GroqTranscriptionModel.whisperLargeV3Turbo.rawValue
    var initialState = ModelDownloadFeature.State(
      hexSettings: Shared(.init(selectedModel: groqModel)),
      modelBootstrapState: Shared(.init())
    )
    initialState.availableModels = [
      .init(name: groqModel, isReady: false),
      .init(name: otherGroqModel, isReady: false),
    ]
    initialState.curatedModels = [
      .init(
        displayName: "Whisper Large v3",
        internalName: groqModel,
        size: "Multilingual",
        accuracyStars: 5,
        speedStars: 5,
        storageSize: "Cloud",
        providerName: "Groq",
        symbolName: "cloud.fill",
        isReady: false
      ),
      .init(
        displayName: "Whisper Large v3 Turbo",
        internalName: otherGroqModel,
        size: "Multilingual",
        accuracyStars: 4,
        speedStars: 5,
        storageSize: "Cloud",
        providerName: "Groq",
        symbolName: "cloud.fill",
        isReady: false
      ),
    ]
    initialState.groqAPIKeyInput = "gsk_test"

    let store = TestStore(initialState: initialState) {
      ModelDownloadFeature()
    } withDependencies: {
      $0.groqAPIKey.saveAPIKey = { _ in }
    }

    await store.send(.saveGroqAPIKey) {
      $0.isSavingGroqAPIKey = true
      $0.groqCredentialError = nil
    }

    await store.receive(.groqAPIKeySaved(.success(()))) {
      $0.isSavingGroqAPIKey = false
      $0.groqAPIKeyInput = ""
      $0.groqCredentialError = nil
      $0.availableModels[id: groqModel]?.isReady = true
      $0.availableModels[id: otherGroqModel]?.isReady = true
      $0.curatedModels[id: groqModel]?.isReady = true
      $0.curatedModels[id: otherGroqModel]?.isReady = true
      $0.$modelBootstrapState.withLock {
        $0.isModelReady = true
        $0.progress = 1
        $0.lastError = nil
        $0.modelIdentifier = groqModel
        $0.modelDisplayName = "Whisper Large v3"
      }
      $0.$hexSettings.withLock {
        $0.hasCompletedModelBootstrap = true
      }
    }
  }

  @Test
  func groqModelsAreTreatedAsCloudSelections() {
    #expect(TranscriptionModelCatalog.isCloud(GroqTranscriptionModel.whisperLargeV3.rawValue))
    #expect(TranscriptionModelCatalog.isCloud(GroqTranscriptionModel.whisperLargeV3Turbo.rawValue))
    #expect(!TranscriptionModelCatalog.isCloud(ParakeetModel.multilingualV3.identifier))
  }
}
