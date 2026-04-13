import XCTest
@testable import HexCore

final class StoragePathsTests: XCTestCase {
	func testPreferredHexApplicationSupportUsesSandboxContainerWhenPresent() throws {
		let fm = FileManager.default
		let tempRoot = try makeTemporaryDirectory()
		defer { try? fm.removeItem(at: tempRoot) }

		let appSupport = tempRoot.appendingPathComponent("Library/Application Support", isDirectory: true)
		let sharedContainer = tempRoot
			.appendingPathComponent("Library/Containers/com.kitlangton.Hex/Data/Library/Application Support/com.kitlangton.Hex", isDirectory: true)

		try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
		try fm.createDirectory(at: sharedContainer, withIntermediateDirectories: true)

		let resolved = URL.preferredHexApplicationSupport(
			using: fm,
			appSupportDirectory: appSupport,
			homeDirectory: tempRoot
		)

		XCTAssertEqual(resolved.standardizedFileURL, sharedContainer.standardizedFileURL)
	}

	func testPreferredHexApplicationSupportFallsBackWhenSandboxContainerIsMissing() throws {
		let fm = FileManager.default
		let tempRoot = try makeTemporaryDirectory()
		defer { try? fm.removeItem(at: tempRoot) }

		let appSupport = tempRoot.appendingPathComponent("Library/Application Support", isDirectory: true)
		try fm.createDirectory(at: appSupport, withIntermediateDirectories: true)

		let resolved = URL.preferredHexApplicationSupport(
			using: fm,
			appSupportDirectory: appSupport,
			homeDirectory: tempRoot
		)

		XCTAssertEqual(
			resolved.standardizedFileURL,
			appSupport.appendingPathComponent("com.kitlangton.Hex", isDirectory: true).standardizedFileURL
		)
	}

	private func makeTemporaryDirectory() throws -> URL {
		let url = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString, isDirectory: true)
		try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
		return url
	}
}
