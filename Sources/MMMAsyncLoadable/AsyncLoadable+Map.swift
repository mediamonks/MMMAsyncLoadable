//
// MMMAsyncLoadable. Part of MMMTemple.
// Copyright (C) 2016-2022 MediaMonks. All rights reserved.
//

import Foundation
import MMMLoadable

extension AsyncLoadable {
    
	/// Map a ``AsyncLoadable<C>`` into ``AsyncLoadable<T>`` by supplying a closure that maps ``C`` into
	/// ``T``. This is helpful if you want to quickly map a loadable from a "thin" to a "fat" model without creating
	/// unnecessary `MMMLoadableProxy`s. E.g. ``AsyncLoadable<API.User>`` into
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
    public func map<T>(
        _ transform: @escaping (C) throws -> T
    ) -> AsyncLoadable<T> {
        return MapAsyncLoadable(origin: self, map: transform)
	}
    
	/// Similar to ``AsyncLoadable/map(_:)`` but with the ability to supply a async callback.
    ///
    /// **Please note** that unlike the map function, that doesn't take an async closure, if the content is available,
    /// we don't map it directly, you will have to sync the loadable again. The original loadable won't ever sync again if
    /// content is available, you will have to call `sync` manually to do that.
    ///
    /// - Returns: A new ``AsyncLoadable<T>``.
    public func asyncMap<T>(
        _ transform: @escaping (C) async throws -> T
    ) -> AsyncLoadable<T> {
        return MapAsyncAwaitLoadable(origin: self, map: transform)
	}
	
	/// FlatMap a ``AsyncLoadable<C>`` into ``AsyncLoadable<T>`` by supplying a closure that maps ``C`` into
	/// ``AsyncLoadable<T>``. This is helpful if you want to chain loadables without having to observe each one.
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
	public func flatMap<T>(
        _ transform: @escaping (C) async throws -> AsyncLoadable<T>
    ) -> AsyncLoadable<T> {
        return FlatMapAsyncLoadable(origin: self, map: transform)
	}
    
    /// Join two ``AsyncLoadable``s together, from ``AsyncLoadable<C>`` and ``AsyncLoadable<T>`` to a
    /// ``AsyncLoadable<(C, T)>``. This could come in useful when you want to grab data from `C` to construct
    /// your loadable `T` without losing `C`.
    ///
    /// This behaves the same as ``AsyncLoadable/flatMap(_:)``.
    ///
    /// **Example**
    /// ```
    /// func fetchLoadableB() -> AsyncLoadable<(AValue, BValue)> {
    ///     loadableA().joined { aVal in
    ///         return LoadableB(identifier: aVal.identifier)
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: A new ``AsyncLoadable<(C, T)>``.
    public func joined<T>(
        _ transform: @escaping (C) async throws -> AsyncLoadable<T>
    ) -> AsyncLoadable<(C, T)> {
        return JoinedAsyncLoadable(origin: self, map: transform)
    }
}

/// Internal declaration to map a loadable, not to be exposed publicly.
internal final class MapAsyncLoadable<O, C>: AsyncLoadable<C> {
	
	private let origin: AsyncLoadable<O>
	private let map: (O) throws -> C
    
    public override var isContentsAvailable: Bool { origin.isContentsAvailable && content != nil }
    public override func needsSync() -> Bool { origin.needsSync() || super.needsSync() }
    
	public init(
        origin: AsyncLoadable<O>,
        map: @escaping (O) throws -> C
    ) {
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
                try await self?.update()
			} catch {
				self?.setFailedToSyncWithError(error)
			}
		}
	}
    
    private func update() async throws {
        
        let originalContent: O = try await {
            if didFetchIfNeeded {
                return try await origin.fetchIfNeeded()
            } else {
                return try await origin.fetch()
            }
        }()
        
        let newContent = try self.map(originalContent)
        
        setDidSyncSuccessfullyWithContent(newContent)
    }
}

/// Internal declaration to map a loadable using an async callback, not to be exposed publicly.
internal final class MapAsyncAwaitLoadable<O, C>: AsyncLoadable<C> {
	
	private let origin: AsyncLoadable<O>
	private let map: (O) async throws -> C
    
    public override var isContentsAvailable: Bool { origin.isContentsAvailable && content != nil }
    public override func needsSync() -> Bool { origin.needsSync() || super.needsSync() }
    
	public init(
        origin: AsyncLoadable<O>,
        map: @escaping (O) async throws -> C
    ) {
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
                try await self?.update()
			} catch {
				self?.setFailedToSyncWithError(error)
			}
		}
	}
    
    private func update() async throws {
        
        let originalContent: O = try await {
            if didFetchIfNeeded {
                return try await origin.fetchIfNeeded()
            } else {
                return try await origin.fetch()
            }
        }()
        
        let newContent = try await self.map(originalContent)
        
        setDidSyncSuccessfullyWithContent(newContent)
    }
}

/// Internal declaration to flatMap a loadable, not to be exposed publicly.
internal final class FlatMapAsyncLoadable<O, C>: AsyncLoadable<C> {
    
    private let origin: AsyncLoadable<O>
    private let map: (O) async throws -> AsyncLoadable<C>
    
    public override var isContentsAvailable: Bool { origin.isContentsAvailable && content != nil }
    public override func needsSync() -> Bool { origin.needsSync() || super.needsSync() }
    
    public init(
        origin: AsyncLoadable<O>,
        map: @escaping (O) async throws -> AsyncLoadable<C>
    ) {
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
                try await self?.update()
            } catch {
                self?.setFailedToSyncWithError(error)
            }
        }
    }
    
    private func update() async throws {
        
        let fetchIfNeeded = didFetchIfNeeded
        
        let originalContent: O = try await {
            if fetchIfNeeded {
                return try await origin.fetchIfNeeded()
            } else {
                return try await origin.fetch()
            }
        }()
        
        let newLoadable = try await self.map(originalContent)
        let newContent: C = try await {
            if fetchIfNeeded {
                return try await newLoadable.fetchIfNeeded()
            } else {
                return try await newLoadable.fetch()
            }
        }()
        
        setDidSyncSuccessfullyWithContent(newContent)
    }
}

/// Internal declaration to flatMap a loadable, not to be exposed publicly.
internal final class JoinedAsyncLoadable<O, C>: AsyncLoadable<(O, C)> {
    
    private let origin: AsyncLoadable<O>
    private let map: (O) async throws -> AsyncLoadable<C>
    
    public override var isContentsAvailable: Bool { origin.isContentsAvailable && content != nil }
    public override func needsSync() -> Bool { origin.needsSync() || super.needsSync() }
    
    public init(
        origin: AsyncLoadable<O>,
        map: @escaping (O) async throws -> AsyncLoadable<C>
    ) {
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
                try await self?.update()
            } catch {
                self?.setFailedToSyncWithError(error)
            }
        }
    }
    
    private func update() async throws {
        
        let originalContent: O = try await {
            if didFetchIfNeeded {
                return try await origin.fetchIfNeeded()
            } else {
                return try await origin.fetch()
            }
        }()
        
        let newLoadable = try await self.map(originalContent)
        let newContent: C = try await {
            if didFetchIfNeeded {
                return try await newLoadable.fetchIfNeeded()
            } else {
                return try await newLoadable.fetch()
            }
        }()
        
        setDidSyncSuccessfullyWithContent((originalContent, newContent))
    }
}
