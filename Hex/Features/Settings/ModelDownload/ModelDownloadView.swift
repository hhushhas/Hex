import ComposableArchitecture
import Inject
import SwiftUI

public struct ModelDownloadView: View {
	@ObserveInjection var inject

	@Bindable var store: StoreOf<ModelDownloadFeature>
	var shouldFlash: Bool = false

	public init(store: StoreOf<ModelDownloadFeature>, shouldFlash: Bool = false) {
		self.store = store
		self.shouldFlash = shouldFlash
	}

	public var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			if !store.modelBootstrapState.isModelReady,
			   let message = store.modelBootstrapState.lastError,
			   !message.isEmpty
			{
				AutoDownloadBannerView(
					title: "Download failed",
					subtitle: message,
					progress: nil,
					style: .error
				)
			}
			if !store.anyModelReady {
				AutoDownloadBannerView(
					title: "Set up a model to start transcribing",
					subtitle: "Choose a local model to download, or select Groq and add an API key. Until one model is ready, recordings can't be transcribed.",
					progress: store.isDownloading ? store.downloadProgress : nil,
					style: .info
				)
				.overlay(
					RoundedRectangle(cornerRadius: 8)
						.stroke(Color.accentColor, lineWidth: shouldFlash ? 3 : 0)
						.animation(.easeInOut(duration: 0.5).repeatCount(3, autoreverses: true), value: shouldFlash)
				)
			}
			// Always show a concise, opinionated list (no dropdowns)
			CuratedList(store: store)
			if store.selectedModelIsCloud {
				VStack(alignment: .leading, spacing: 10) {
					Text(store.selectedModelProviderName ?? "Cloud provider")
						.font(.headline)
					Text(store.selectedModelIsReady
					     ? "API key stored in Keychain. Groq transcriptions can run immediately."
					     : "Add your Groq API key to Keychain for this model. Hex will keep the existing selectable-but-not-ready flow until a key is saved.")
						.settingsCaption()
					SecureField(
						store.selectedModelIsReady ? "Replace Groq API key" : "Groq API key",
						text: Binding(
							get: { store.groqAPIKeyInput },
							set: { store.send(.groqAPIKeyInputChanged($0)) }
						)
					)
					.textFieldStyle(.roundedBorder)
					HStack(spacing: 8) {
						Button(store.selectedModelIsReady ? "Replace API Key" : "Save API Key") {
							store.send(.saveGroqAPIKey)
						}
						.disabled(store.groqAPIKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || store.isSavingGroqAPIKey)
						if store.selectedModelIsReady {
							Button("Clear API Key", role: .destructive) {
								store.send(.deleteGroqAPIKey)
							}
						}
					}
					if let error = store.groqCredentialError, !error.isEmpty {
						Text(error)
							.foregroundStyle(.red)
							.font(.caption)
					}
				}
				.padding(12)
				.background(
					RoundedRectangle(cornerRadius: 10)
						.fill(Color(NSColor.controlBackgroundColor))
				)
				.overlay(
					RoundedRectangle(cornerRadius: 10)
						.stroke(Color.gray.opacity(0.18))
				)
			}
			if let err = store.downloadError {
				Text("Download Error: \(err)")
					.foregroundColor(.red)
					.font(.caption)
			}
		}
		.frame(maxWidth: 500)
		.task {
			if store.availableModels.isEmpty {
				store.send(.fetchModels)
			}
		}
		.enableInjection()
	}
}
