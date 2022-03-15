//
// MMMAsyncLoadable. Part of MMMTemple.
// Copyright (C) 2016-2022 MediaMonks. All rights reserved.
//

import Foundation
import MMMLoadable

/// An async loadable makes it possible to fetch the content `C` using the async/await syntax.
public protocol AsyncLoadableProtocol: MMMLoadableProtocol {
	
	associatedtype C
	
	/// The associated content for this loadable. This is now a concrete type, so if your loadable loads multiple values,
	/// either pass a `tuple` (recommended up to 2 values) or a wrapping `struct`.
	var content: C? { get }
	
	/// Fetch the content asynchronously, instead of adding a listener, this will throw upon `setFailedWithError` and
	/// return the content when `setDidSyncSuccessfully`. Equivalent of ``sync()``
	/// - Returns: The content.
	func fetch() async throws -> C
	
	/// Similar to ``fetch()``, only when ``MMMPureLoadableProtocol/needsSync()`` is `true`. Equivalent
	/// of ``syncIfNeeded()``.
	/// - Returns: The content.
	func fetchIfNeeded() async throws -> C
}
