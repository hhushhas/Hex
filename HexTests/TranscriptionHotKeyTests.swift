import AppKit
import ComposableArchitecture
import Foundation
import Testing

@testable import Hex

@Suite(.serialized)
@MainActor
struct TranscriptionHotKeyTests {
  @Test
  func hotKeyPressDuringTranscriptionIsIgnored() async {
    var state = Self.makeState()
    state.isTranscribing = true

    let store = TestStore(initialState: state) {
      TranscriptionFeature()
    }

    await store.send(.hotKeyPressed)
    await store.finish()
  }

  @Test
  func hotKeyPressStartsRecordingWhenIdle() async {
    let now = Date(timeIntervalSince1970: 1_234)
    let activeApp = NSWorkspace.shared.frontmostApplication
    let store = TestStore(initialState: Self.makeState()) {
      TranscriptionFeature()
    } withDependencies: {
      $0.date.now = now
      $0.recording.startRecording = {}
      $0.sleepManagement.preventSleep = { _ in }
      $0.soundEffects.play = { _ in }
    }

    await store.send(.hotKeyPressed)
    await store.receive(.startRecording) {
      $0.isRecording = true
      $0.recordingStartTime = now
      $0.sourceAppBundleID = activeApp?.bundleIdentifier
      $0.sourceAppName = activeApp?.localizedName
    }
    await store.finish()
  }

  private static func makeState() -> TranscriptionFeature.State {
    TranscriptionFeature.State(
      hexSettings: Shared(.init()),
      isRemappingScratchpadFocused: Shared(false),
      modelBootstrapState: Shared(.init(isModelReady: true)),
      transcriptionHistory: Shared(.init())
    )
  }
}
