import XCTest
@testable import MMMAsyncLoadable

internal final class AsyncObservablesTests: XCTestCase {
	
	public func testBasics() async throws {
		
		let loadable = MyLoadable(timeout: 0.1)
		let data = try await loadable.fetch()
		
		XCTAssertEqual(data, .default())
		
		let mapData = try await loadable.map { $0.title }.fetch()
		
		XCTAssertEqual(mapData, MyData.default().title)
		
		do {
			_ = try await MyLoadable(timeout: 0.1, shouldFail: true).fetch()
			
			XCTFail("Call did not throw")
		} catch {
			XCTAssertEqual(error as! MyError, MyError.foo)
		}
		
		let flatMapped = MyLoadable(timeout: 0.1).flatMap { OtherLoadable(data: $0) }
		let flatMapData = try await flatMapped.fetch()
		
		XCTAssertEqual(flatMapData, .construct(.default()))
    }
    
    public func testMapping() async throws {
		
		let loadable = MyLoadable(timeout: 0.1, shouldFail: false)
		let mapped = loadable.map { $0.title }
		
		XCTAssertEqual(mapped.loadableState, loadable.loadableState)
		
		_ = try await mapped.fetch()
		
		XCTAssertEqual(mapped.loadableState, loadable.loadableState)
		
		let preSynced = MyLoadable(timeout: 0.1, shouldFail: false)
		
		_ = try await preSynced.fetch()
        
        XCTAssert(preSynced.isContentsAvailable)
        
		let preSyncMap = preSynced.map { $0.title }
		
		XCTAssertEqual(preSynced.loadableState, preSyncMap.loadableState)
		XCTAssertEqual(preSynced.isContentsAvailable, preSyncMap.isContentsAvailable)
		
        let preSyncAsyncMap = preSynced.asyncMap { data -> String in
			try await Task.sleep(nanoseconds: 1000)
			return data.title
		}
		
		XCTAssertNotEqual(preSynced.loadableState, preSyncAsyncMap.loadableState)
		XCTAssertNotEqual(preSynced.isContentsAvailable, preSyncAsyncMap.isContentsAvailable)
		
		_ = try await preSyncAsyncMap.fetch()
		
		XCTAssertEqual(preSynced.loadableState, preSyncAsyncMap.loadableState)
		XCTAssertEqual(preSynced.isContentsAvailable, preSyncAsyncMap.isContentsAvailable)
		
		let flatMapped = preSynced.flatMap { OtherLoadable(data: $0) }
		
		XCTAssertNotEqual(preSynced.loadableState, flatMapped.loadableState)
		XCTAssertNotEqual(preSynced.isContentsAvailable, flatMapped.isContentsAvailable)
		
		_ = try await flatMapped.fetch()
		
		XCTAssertEqual(preSynced.loadableState, flatMapped.loadableState)
		XCTAssertEqual(preSynced.isContentsAvailable, flatMapped.isContentsAvailable)
		
		let loadableFail = MyLoadable(timeout: 0.1, shouldFail: true)
		let flatMapNonFail = loadableFail.flatMap { OtherLoadable(data: $0) }
		
		do {
			_ = try await flatMapNonFail.fetch()
			
			XCTFail("Should fail")
		} catch {
			XCTAssertEqual(error as! MyError, loadableFail.error as! MyError)
		}
	}
    
    public func testJoining() async throws {
        
        let loadable = MyLoadable(timeout: 0.1, shouldFail: false)
        
        let (data1, data2) = try await loadable.joined { data in
            OtherLoadable(data: data, shouldFail: false)
        }.fetch()
        
        XCTAssertEqual(data1, .default())
        XCTAssertEqual(data2, .construct(.default()))
    }
}
