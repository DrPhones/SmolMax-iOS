import XCTest
@testable import SmolMax_iOS

final class GGUFValidationTests: XCTestCase {
    
    func testGGUFMagicValidation() throws {
        // Create dummy valid GGUF header in memory
        var data = Data()
        data.append(contentsOf: [0x47, 0x47, 0x55, 0x46]) // "GGUF"
        var version: UInt32 = 3
        data.append(Data(bytes: &version, count: 4))
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_valid.gguf")
        try data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let repo = LocalModelRepository()
        let result = try repo.validateGGUF(at: tempURL)
        XCTAssertEqual(result.architecture, .llama)
    }
    
    func testInvalidMagicThrows() {
        var data = Data()
        data.append(contentsOf: [0x42, 0x41, 0x44, 0x21]) // "BAD!"
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_invalid.gguf")
        try? data.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let repo = LocalModelRepository()
        XCTAssertThrowsError(try repo.validateGGUF(at: tempURL))
    }
}
