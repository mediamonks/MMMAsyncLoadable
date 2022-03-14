//
// MMMAsyncLoadable. Part of MMMTemple.
// Copyright (C) 2016-2022 MediaMonks. All rights reserved.
//

import Foundation
import MMMLoadable

extension AsyncLoadable {
	
	/// Map a ``AsyncLoadable<C>`` into ``AsyncLoadable<T>`` by supplying a closure that maps ``C`` into
	/// ``T``. This is helpfull if you want to quickly map a loadable from a "thin" to a "fat" model without creating
	/// unneccessary `MMMLoadableProxy`s. E.g. ``AsyncLoadable<API.User>`` into
	/// ``AsyncLoadable<Models.User>``.
	///
	/// If the original loadable is already synced / has contents available, we map it directly.
	///
	/// If there is an error thrown in the callback, we use that as the new ``AsyncLoadable/error`` and set it to failed.
	///
	///	**Example**
	///	```
	///	func fetchUser() -> AsyncLoadable<Models.User> {
	///		// apiClient.getUser() returns AsyncLoadable<API.User>
	///		apiClient.getUser().map { apiUser in
	///			return Models.User(apiModel: apiUser)
	///		}
	///	}
	///	```
	///
	/// - Returns: A new ``AsyncLoadable<T>``.
	public func map<T>(_ transform: @escaping (C) throws -> T) -> AsyncLoadable<T> {
		return MapAsyncLoadable(self, transform)
	}
	
	/// Map a ``AsyncLoadable<C>`` into ``AsyncLoadable<T>`` by supplying a closure that maps ``C`` into
	/// ``T``. This is helpfull if you want to quickly map a loadable from a "thin" to a "fat" model without creating
	/// unneccessary `MMMLoadableProxy`s. E.g. ``AsyncLoadable<API.User>`` into
	/// ``AsyncLoadable<Models.User>``. This allows for the closure to call async functions.
	///
	/// If there is an error thrown in the callback, we use that as the new ``AsyncLoadable/error`` and set it to failed.
	///
	///	**Please note** that unlike the other map function, that doesn't take an async closure, if the content is available,
	///	we don't map it directly, you will have to sync the loadable again. The original loadable won't ever sync again if
	///	content is available, you will have to call `sync` manually to do that.
	///
	///	**Example**
	///	```
	///	func fetchUser() -> AsyncLoadable<Models.User> {
	///		// apiClient.getUser() returns AsyncLoadable<API.User>
	///		apiClient.getUser().map { apiUser in
	///			return await Models.User(apiModel: apiUser)
	///		}
	///	}
	///	```
	///
	/// - Returns: A new ``AsyncLoadable<T>``.
	public func map<T>(_ transform: @escaping (C) async throws -> T) -> AsyncLoadable<T> {
		return MapAsyncAwaitLoadable(self, transform)
	}
	
	/// FlatMap a ``AsyncLoadable<C>`` into ``AsyncLoadable<T>`` by supplying a closure that maps ``C`` into
	/// ``AsyncLoadable<T>``. This is helpfull if you want to chain loadables without having to observe each one.
	///
	/// For example say you have `LoadableA` that upon success will load `LoadableB` using a value in it's contents,
	/// `LoadableB` will be exposed to the users, since that only contains valuable info for them. If `LoadableA` fails,
	/// we don't have to try to load `LoadableB`.
	///
	/// If there is an error thrown in the callback, we use that as the new ``AsyncLoadable/error`` and set it to failed.
	///
	///	**Please note** that unlike the map function, that doesn't take an async closure, if the content is available,
	///	we don't map it directly, you will have to sync the loadable again. The original loadable won't ever sync again if
	///	content is available, you will have to call `sync` manually to do that.
	///
	///	**Example**
	///	```
	///	func fetchLoadableB() -> AsyncLoadable<BValue> {
	///		loadableA().flatMap { aVal in
	///			return LoadableB(identifier: aVal.identifier)
	///		}
	///	}
	///	```
	/// - Returns: A new ``AsyncLoadable<T>``.
	public func flatMap<T>(_ transform: @escaping (C) async throws -> AsyncLoadable<T>) -> AsyncLoadable<T> {
		return FlatMapAsyncLoadable(self, transform)
	}
}

/// Internal declaration to map a loadable, not to be exposed publicly.
internal final class MapAsyncLoadable<O, C>: AsyncLoadable<C> {
	
	private let origin: AsyncLoadable<O>
	private let map: (O) throws -> C
	
	public override var isContentsAvailable: Bool { origin.isContentsAvailable && content != nil }
	
	public init(_ origin: AsyncLoadable<O>, _ map: @escaping (O) throws -> C) {
		self.origin = origin
		self.map = map
		
		super.init()
	
		if origin.isContentsAvailable, let c = origin.content {
			do {
				let content = try map(c)
				
				switch origin.loadableState {
				case .didSyncSuccessfully:
					setDidSyncSuccessfullyWithContent(content)
				case .didFailToSync:
					self.content = content
					setFailedToSyncWithError(origin.error)
				case .syncing, .idle:
					self.content = content
				}
				
			} catch {
				setFailedToSyncWithError(error)
			}
		} else if let error = origin.error {
			setFailedToSyncWithError(error)
		}
	}
	
	deinit {
		syncTask?.cancel()
	}
	
	private var syncTask: Task<Void, Error>?
	
	public override func doSync() {
	
		syncTask?.cancel()
		syncTask = Task { [weak self] in
			
			do {
				if let oC = try await self?.origin.fetchIfNeeded(), let c = try self?.map(oC) {
					self?.setDidSyncSuccessfullyWithContent(c)
				} else {
					self?.setFailedToSyncWithError(self?.error)
				}
			} catch {
				self?.setFailedToSyncWithError(error)
			}
		}
	}
}

/// Internal declaration to map a loadable using an async callback, not to be exposed publicly.
internal final class MapAsyncAwaitLoadable<O, C>: AsyncLoadable<C> {
	
	private let origin: AsyncLoadable<O>
	private let map: (O) async throws -> C
	
	public override var isContentsAvailable: Bool { origin.isContentsAvailable && content != nil }
	
	public init(_ origin: AsyncLoadable<O>, _ map: @escaping (O) async throws -> C) {
		self.origin = origin
		self.map = map
		
		super.init()
		
		if let error = origin.error {
			setFailedToSyncWithError(error)
		}
	}
	
	deinit {
		syncTask?.cancel()
	}
	
	private var syncTask: Task<Void, Error>?
	
	public override func doSync() {
	
		syncTask?.cancel()
		syncTask = Task { [weak self] in
			
			do {
				if let oC = try await self?.origin.fetchIfNeeded(), let c = try await self?.map(oC) {
					self?.setDidSyncSuccessfullyWithContent(c)
				} else {
					self?.setFailedToSyncWithError(self?.error)
				}
			} catch {
				self?.setFailedToSyncWithError(error)
			}
		}
	}
}

/// Internal declaration to flatMap a loadable, not to be exposed publicly.
internal final class FlatMapAsyncLoadable<O, C>: AsyncLoadable<C> {
	
	private let origin: AsyncLoadable<O>
	private let map: (O) async throws -> AsyncLoadable<C>
	
	public init(_ origin: AsyncLoadable<O>, _ map: @escaping (O) async throws -> AsyncLoadable<C>) {
		self.origin = origin
		self.map = map
		
		super.init()
		
		if let error = origin.error {
			setFailedToSyncWithError(error)
		}
	}
	
	deinit {
		syncTask?.cancel()
	}
	
	private var syncTask: Task<Void, Error>?
	
	public override func doSync() {
	
		syncTask?.cancel()
		syncTask = Task { [weak self] in
			
			do {
				if let oC = try await self?.origin.fetchIfNeeded(), let c = try await self?.map(oC).fetch() {
					self?.setDidSyncSuccessfullyWithContent(c)
				} else {
					self?.setFailedToSyncWithError(self?.error)
				}
			} catch {
				self?.setFailedToSyncWithError(error)
			}
		}
	}
}
