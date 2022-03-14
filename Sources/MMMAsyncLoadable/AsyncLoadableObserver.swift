//
// MMMAsyncLoadable. Part of MMMTemple.
// Copyright (C) 2016-2022 MediaMonks. All rights reserved.
//

import Foundation
import MMMLoadable

/// ``MMMLoadableObserver`` that supports asynchronous blocks as it's callback.
public final class AsyncLoadableObserver: MMMLoadableObserver {
	
	public init?(
		loadable: MMMPureLoadableProtocol?,
		callback: @Sendable @escaping (MMMPureLoadableProtocol) async -> Void
	) {
		super.init(loadable: loadable) { loadable in
			Task {
				await callback(loadable)
			}
		}
	}
}
