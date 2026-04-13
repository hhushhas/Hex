import Foundation

public extension URL {
	static var hexApplicationSupport: URL {
		get throws {
			let fm = FileManager.default
			let appSupport = try fm.url(
				for: .applicationSupportDirectory,
				in: .userDomainMask,
				appropriateFor: nil,
				create: true
			)
			let hexDirectory = preferredHexApplicationSupport(
				using: fm,
				appSupportDirectory: appSupport,
				homeDirectory: fm.homeDirectoryForCurrentUser
			)
			try fm.createDirectory(at: hexDirectory, withIntermediateDirectories: true)
			return hexDirectory
		}
	}

	static func preferredHexApplicationSupport(
		using fm: FileManager,
		appSupportDirectory: URL,
		homeDirectory: URL
	) -> URL {
		let defaultHexDirectory = appSupportDirectory.appendingPathComponent("com.kitlangton.Hex", isDirectory: true)
		let sharedContainerHexDirectory = homeDirectory
			.appendingPathComponent("Library/Containers/com.kitlangton.Hex/Data/Library/Application Support/com.kitlangton.Hex", isDirectory: true)

		// Unsandboxed local builds otherwise create a parallel settings/models store under
		// ~/Library/Application Support. If the official sandbox container already exists,
		// prefer it so locally built copies inherit the user's current Hex data.
		guard defaultHexDirectory.standardizedFileURL != sharedContainerHexDirectory.standardizedFileURL,
			  fm.fileExists(atPath: sharedContainerHexDirectory.path)
		else {
			return defaultHexDirectory
		}

		return sharedContainerHexDirectory
	}

	static var legacyDocumentsDirectory: URL {
		FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
	}

	static func hexMigratedFileURL(named fileName: String) -> URL {
		let newURL = (try? hexApplicationSupport.appending(component: fileName))
			?? documentsDirectory.appending(component: fileName)
		let legacyURL = legacyDocumentsDirectory.appending(component: fileName)
		FileManager.default.migrateIfNeeded(from: legacyURL, to: newURL)
		return newURL
	}

	static var hexModelsDirectory: URL {
		get throws {
			let modelsDirectory = try hexApplicationSupport.appendingPathComponent("models", isDirectory: true)
			try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
			return modelsDirectory
		}
	}
}

public extension FileManager {
	func migrateIfNeeded(from legacy: URL, to new: URL) {
		guard fileExists(atPath: legacy.path), !fileExists(atPath: new.path) else { return }
		try? copyItem(at: legacy, to: new)
	}

	func removeItemIfExists(at url: URL) {
		guard fileExists(atPath: url.path) else { return }
		try? removeItem(at: url)
	}
}
