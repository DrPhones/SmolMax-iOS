import XCTest
@testable import SmolMax_iOS

final class MemoryBudgetTests: XCTestCase {
    
    func testMemoryReserveFraction() {
        XCTAssertEqual(AppConfiguration.memoryReserveFraction, 0.25)
    }
    
    func testCanLoadSmallModel() {
        let memManager = MemoryManager()
        // 400MB model on 6GB device should always succeed
        let canLoad = memManager.canLoadModel(fileSize: 400 * 1024 * 1024, isMoE: false, expertPoolSize: 4)
        XCTAssertTrue(canLoad)
    }
    
    func testRejectModelLargerThanAvailableRAM() {
        let memManager = MemoryManager()
        // 16GB dense model should be rejected on 6GB device
        let canLoad = memManager.canLoadModel(fileSize: 16 * 1024 * 1024 * 1024, isMoE: false, expertPoolSize: 4)
        XCTAssertFalse(canLoad)
    }
    
    func testMoEModelFitsUnderBudgetWithExpertPaging() {
        let memManager = MemoryManager()
        // 8.4GB MoE model (Ling-mini-2.0) with pool size 4 should fit in ~3GB budget
        let canLoad = memManager.canLoadModel(fileSize: 8500 * 1024 * 1024, isMoE: true, expertPoolSize: 4)
        XCTAssertTrue(canLoad)
    }
}
