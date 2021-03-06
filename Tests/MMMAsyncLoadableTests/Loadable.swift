//
// MMMAsyncLoadable. Part of MMMTemple.
// Copyright (C) 2016-2022 MediaMonks. All rights reserved.
//

import Foundation
import MMMAsyncLoadable

public struct MyData: Equatable {
	public let title: String
	public let count: Int
	
	public static func `default`() -> MyData {
		MyData(title: "Data Title", count: 20)
	}
	
	public static func construct(_ other: MyData) -> MyData {
		MyData(title: "\(other.title) - And Title", count: other.count + 20)
	}
}

public enum MyError: Error {
	case foo, bar
}

public final class MyLoadable: AsyncLoadable<MyData> {
	
	private let timeout: TimeInterval
	private let shouldFail: Bool
	
    public init(timeout: TimeInterval = 0.05, shouldFail: Bool = false) {
		
		self.timeout = timeout
		self.shouldFail = shouldFail
		
		super.init()
	}
	
    internal var doSyncCounter = 0
    
	public override func doSync() {
		
        doSyncCounter += 1
        
		DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
			
			if self.shouldFail {
				self.setFailedToSyncWithError(MyError.foo)
			} else {
				self.setDidSyncSuccessfullyWithContent(.default())
			}
		}
	}
}

public final class OtherLoadable: AsyncLoadable<MyData> {
	
	private let data: MyData
	private let shouldFail: Bool
	
	public init(data: MyData, shouldFail: Bool = false) {
		
        self.data = data
		self.shouldFail = shouldFail
		
		super.init()
	}
	
    internal var doSyncCounter = 0
    
	public override func doSync() {
		
        doSyncCounter += 1
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
			
			if self.shouldFail {
				self.setFailedToSyncWithError(MyError.bar)
			} else {
				self.setDidSyncSuccessfullyWithContent(.construct(self.data))
			}
		}
	}
}
