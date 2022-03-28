//
// MMMAsyncLoadable. Part of MMMTemple.
// Copyright (C) 2016-2022 MediaMonks. All rights reserved.
//

import Foundation
import MMMLoadable

/// AsyncLoadable is a concrete implementation of ``AsyncLoadableProtocol``, subclass from this class to make
/// your own loadable, so you can avoid working with generics "down the line".
open class AsyncLoadable<C>: MMMLoadable, AsyncLoadableProtocol {
	
	/// Errors thrown by the ``AsyncLoadable``.
	public enum AsyncError: Error {
		/// We've lost the weak reference to our parent (self) inside the callback, that means we should be `nil` as well.
		case lostParent
		/// We've synced successfully, however, ``AsyncLoadable/isContentsAvailable`` is false, or
		/// ``AsyncLoadable/content`` is nil.
		case invalidData
		/// We did not sync succesfully, and no ``AsyncLoadable/error`` was passed.
		case unknownError
	}
	
	/// The content of this loadable, possible to set internally.
	public internal(set) var content: C?
	
	/// If the content is available, defaults to `content != nil`.
	public override var isContentsAvailable: Bool { content != nil }
	
	/// Call this to sucessfully sync the loadable.
	/// - Parameter content: The content we've synced with.
	public func setDidSyncSuccessfullyWithContent(_ content: C?) {
		self.content = content
		super.setDidSyncSuccessfully()
	}
	
	@available(*, unavailable)
	open override func setDidSyncSuccessfully() {
		assertionFailure("Use setDidSyncSuccessfullyWithContent(_:) instead")
	}
	
	private var waiter: MMMSimpleLoadableWaiter?
	
	/// Fetch the content for this loadable. Similar to ``sync()`` only we immediately return either the ``content`` or
	/// throw the ``error``.
	/// - Returns: The content.
	public func fetch() async throws -> C {
		
		return try await withUnsafeThrowingContinuation { (c: UnsafeContinuation<C, Error>) in
			
			waiter = MMMSimpleLoadableWaiter.whenDoneSyncing(self) { [weak self] in
				
				guard let self = self else {
					c.resume(throwing: AsyncError.lostParent)
					return
				}
				
				switch self.loadableState {
				case .idle, .syncing:
					// Wait.
					break
				case .didFailToSync:
				
					if let error = self.error {
						c.resume(throwing: error)
					} else {
						c.resume(throwing: AsyncError.unknownError)
					}
					
					self.waiter = nil
					
					return
					
				case .didSyncSuccessfully:
					
					if self.isContentsAvailable, let content = self.content {
						c.resume(returning: content)
					} else {
						c.resume(throwing: AsyncError.invalidData)
					}
					
					self.waiter = nil
					
					return
				}
			}
			
			self.sync()
		}
	}
	
	/// Fetch the content for this loadable, if it needs sync. Similar to ``syncIfNeeded()``.
	/// - Returns: The content.
	public func fetchIfNeeded() async throws -> C {
		
		guard needsSync() else {
			if self.isContentsAvailable, let content = self.content {
				return content
			} else {
				throw AsyncError.invalidData
			}
		}
        
		return try await fetch()
	}
}
