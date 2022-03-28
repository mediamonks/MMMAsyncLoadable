//
// MMMAsyncLoadable. Part of MMMTemple.
// Copyright (C) 2016-2022 MediaMonks. All rights reserved.
//

import Foundation
import MMMLoadable

/// ``MMMLoadableObserver`` that supports asynchronous closures as it's callback.
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

extension MMMPureLoadableProtocol {
    
    /// Observe changes in this loadable by supplying a async closure. Will stop listening to
    /// changes when ``MMMLoadableObserver/remove()`` is called or the observer
    /// deallocates.
    ///
    /// - Parameter block: Get's called every time the loadable changes.
    /// - Returns: The observer, you usually want to store this outside of the scope, e.g.
    ///            in a private property so it doesn't deallocate right away.
    public func sink(_ block: @Sendable @escaping (Self) async -> Void) -> AsyncLoadableObserver? {
        return AsyncLoadableObserver(loadable: self) { loadable in
            await block(loadable as! Self)
        }
    }
}
