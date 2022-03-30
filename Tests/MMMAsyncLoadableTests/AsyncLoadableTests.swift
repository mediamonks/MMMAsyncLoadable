//
// MMMAsyncLoadable. Part of MMMTemple.
// Copyright (C) 2016-2022 MediaMonks. All rights reserved.
//

import XCTest
@testable import MMMAsyncLoadable

internal final class AsyncObservablesTests: XCTestCase {
	
	public func testBasics() async throws {
		
		let loadable = MyLoadable(timeout: 0.01)
		let data = try await loadable.fetch()
		
		XCTAssertEqual(data, .default())
        XCTAssertEqual(loadable.doSyncCounter, 1)
        
		let mapData = try await loadable.map { $0.title }.fetch()
		
		XCTAssertEqual(mapData, MyData.default().title)
        XCTAssertEqual(loadable.doSyncCounter, 2)
        
		do {
			_ = try await MyLoadable(timeout: 0.01, shouldFail: true).fetch()
			
			XCTFail("Call did not throw")
		} catch {
			XCTAssertEqual(error as! MyError, MyError.foo)
		}
		
        let flatOriginal = MyLoadable(timeout: 0.01)
        var flatRaw: OtherLoadable!
		let flatMapped = flatOriginal.flatMap { data -> OtherLoadable in
            let l = OtherLoadable(data: data)
            flatRaw = l
            return l
        }
        
		let flatMapData = try await flatMapped.fetchIfNeeded()
        
        XCTAssertEqual(flatMapData, .construct(.default()))
        
        // Should reset right after doSync.
        XCTAssertFalse(flatOriginal.didFetchIfNeeded)
        XCTAssertFalse(flatMapped.didFetchIfNeeded)
        XCTAssertFalse(flatRaw.didFetchIfNeeded)
        
        XCTAssertEqual(flatRaw.doSyncCounter, 1)
        XCTAssertEqual(flatOriginal.doSyncCounter, 1)
        
        _ = try await flatMapped.fetchIfNeeded()
        
        // Should have data, so no fetch needed at all.
        XCTAssertFalse(flatOriginal.didFetchIfNeeded)
        XCTAssertFalse(flatMapped.didFetchIfNeeded)
        XCTAssertFalse(flatRaw.didFetchIfNeeded)
        
        XCTAssertEqual(flatRaw.doSyncCounter, 1)
        XCTAssertEqual(flatOriginal.doSyncCounter, 1)
        
        _ = try await flatMapped.fetch()
        
        // Since the map is evaluated after the original is synced, this count will be 1 due
        // to it being a fresh "OtherLoadable".
        XCTAssertEqual(flatRaw.doSyncCounter, 1)
        XCTAssertEqual(flatOriginal.doSyncCounter, 2)
    }
    
    public func testMapping() async throws {
		
		let loadable = MyLoadable(timeout: 0.01, shouldFail: false)
		let mapped = loadable.map { $0.title }
		
        XCTAssertEqual(loadable.doSyncCounter, 0)
        
        let expectation = XCTestExpectation()
        
        let observer = loadable.sink { l in
            
            if l.isContentsAvailable {
                XCTAssert(l.content != nil)
                
                expectation.fulfill()
            }
        }
        
		XCTAssertEqual(mapped.loadableState, loadable.loadableState)
		XCTAssertNotNil(observer)
        
		_ = try await mapped.fetch()
        
        XCTAssertEqual(loadable.doSyncCounter, 1)
        
        wait(for: [expectation], timeout: 5)
        
		XCTAssertEqual(mapped.loadableState, loadable.loadableState)
		
		let preSynced = MyLoadable(timeout: 0.01, shouldFail: false)
		
        XCTAssertEqual(preSynced.doSyncCounter, 0)
        
		_ = try await preSynced.fetch()
        
        XCTAssertEqual(preSynced.doSyncCounter, 1)
        
        XCTAssert(preSynced.isContentsAvailable)
        
		let preSyncMap = preSynced.map { $0.title }
		
        XCTAssertEqual(preSynced.doSyncCounter, 1)
        
		XCTAssertEqual(preSynced.loadableState, preSyncMap.loadableState)
		XCTAssertEqual(preSynced.isContentsAvailable, preSyncMap.isContentsAvailable)
		
        let preSyncAsyncMap = preSynced.asyncMap { data -> String in
			try await Task.sleep(nanoseconds: 1000)
			return data.title
		}
		
        XCTAssertEqual(preSynced.doSyncCounter, 1)
        
		XCTAssertNotEqual(preSynced.loadableState, preSyncAsyncMap.loadableState)
		XCTAssertNotEqual(preSynced.isContentsAvailable, preSyncAsyncMap.isContentsAvailable)
		
		_ = try await preSyncAsyncMap.fetch()
		
        XCTAssertEqual(preSynced.doSyncCounter, 2)
        
		XCTAssertEqual(preSynced.loadableState, preSyncAsyncMap.loadableState)
		XCTAssertEqual(preSynced.isContentsAvailable, preSyncAsyncMap.isContentsAvailable)
		
		let flatMapped = preSynced.flatMap { OtherLoadable(data: $0) }
		
        XCTAssertEqual(preSynced.doSyncCounter, 2)
        
		XCTAssertNotEqual(preSynced.loadableState, flatMapped.loadableState)
		XCTAssertNotEqual(preSynced.isContentsAvailable, flatMapped.isContentsAvailable)
		
		_ = try await flatMapped.fetch()
		
        XCTAssertEqual(preSynced.doSyncCounter, 3)
        
		XCTAssertEqual(preSynced.loadableState, flatMapped.loadableState)
		XCTAssertEqual(preSynced.isContentsAvailable, flatMapped.isContentsAvailable)
		
        _ = try await flatMapped.fetchIfNeeded()
        
        XCTAssertEqual(preSynced.doSyncCounter, 3)
        
		let loadableFail = MyLoadable(timeout: 0.01, shouldFail: true)
		let flatMapNonFail = loadableFail.flatMap { OtherLoadable(data: $0) }
		
		do {
			_ = try await flatMapNonFail.fetch()
			
			XCTFail("Should fail")
		} catch {
			XCTAssertEqual(error as! MyError, loadableFail.error as! MyError)
		}
	}
    
    public func testJoining() async throws {
        
        let loadable = MyLoadable(timeout: 0.01, shouldFail: false)
        
        XCTAssertEqual(loadable.doSyncCounter, 0)
        
        var otherLoadable: OtherLoadable!
        let joinedLoadable: AsyncLoadable<(MyData, MyData)> = loadable.joined { data in
            let other = OtherLoadable(data: data, shouldFail: false)
            otherLoadable = other
            return other
        }
        
        let (data1, data2) = try await joinedLoadable.fetch()
        
        XCTAssertEqual(data1, .default())
        XCTAssertEqual(data2, .construct(.default()))
        
        XCTAssertEqual(loadable.doSyncCounter, 1)
        XCTAssertEqual(otherLoadable.doSyncCounter, 1)
        
        _ = try await joinedLoadable.fetchIfNeeded()
        
        XCTAssertEqual(loadable.doSyncCounter, 1)
        XCTAssertEqual(otherLoadable.doSyncCounter, 1)
        
        _ = try await joinedLoadable.fetch()
        
        XCTAssertEqual(loadable.doSyncCounter, 2)
        
        // Since the map is evaluated after the original is synced, this count will be 1 due
        // to it being a fresh "OtherLoadable".
        XCTAssertEqual(otherLoadable.doSyncCounter, 1)
    }
}
