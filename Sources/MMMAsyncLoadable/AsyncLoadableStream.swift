//
// MMMAsyncLoadable. Part of MMMTemple.
// Copyright (C) 2016-2022 MediaMonks. All rights reserved.
//

import Foundation
import MMMLoadable

/// Listen to an ``AsyncLoadable`` by using an ``AsyncStream``. This allows you to iterate over the
/// ``AsyncLoadableStream/iterator``, this will stream a new ``AsyncLoadableStreamObject`` on every
/// change in the loadable.
///
///	For example:
///
///	```
/// class MyView: UIView {
///
///		private let loadable: AsyncLoadable<MyData>
///
///		// It's crucial that we call `finish()` somehow, this is also called upon deinit,
///		// so storing it as a property is an easy way to accomplish this.
///		private var stream: AsyncLoadableStream<MyData>?
///
///		public init(loadable: AsyncLoadable<MyData>) {
///
///			let stream = AsyncLoadableStream(loadable)
///
///			self.loadable = loadable
///			self.stream = stream
///
///			for await obj in stream.iterator {
///				// Do something with the stream object, e.g. update UI.
///				updateUI()
///			}
///		}
///
///		private func updateUI() {
///			loader.isHidden = loadable.loadableState != .syncing
///		}
/// }
///	```
///
/// **Please note** that due to the nature of `async/await` in swift it's crucial to store the stream as a local (private) property
/// to ensure that ``AsyncLoadableStream/finish()`` get's called upon `deinit`. This stops the stream.
/// Otherwise your `Actor` will get blocked indefinitely, since it will keep on waiting for new values, causing a memory leak.
public final class AsyncLoadableStream<C> {
	
	private weak var loadable: AsyncLoadable<C>?
	private var observer: MMMLoadableObserver!
	
	/// The iterator to loop over, e.g. using a `for await val in stream.iterator { ...`.
	public var iterator: AsyncStream<AsyncLoadableStreamObject<C>> { _iterator }
	private var _iterator: AsyncStream<AsyncLoadableStreamObject<C>>!
	
	private var continuation: AsyncStream<AsyncLoadableStreamObject<C>>.Continuation!
	
	/// Initialize a new stream.
	/// - Parameters:
	///   - loadable: The ``AsyncLoadable`` to listen to.
	///   - bufferingPolicy: The buffering policy, by default we only store the latest value, however, if you need
	///   					 access to previous values, this is possible. Look at
	///   					 ``AsyncStream.Continuation.BufferingPolicy``.
	public init(
		_ loadable: AsyncLoadable<C>,
		bufferingPolicy: AsyncStream<AsyncLoadableStreamObject<C>>.Continuation.BufferingPolicy = .bufferingNewest(1)
	) {
		self.loadable = loadable
		
		observer = MMMLoadableObserver(loadable: loadable) { [weak self] _ in
			
			guard let self = self else {
				return
			}
			
			guard let loadable = self.loadable else {
				self.continuation.finish()
				return
			}
			
			self.continuation.yield(AsyncLoadableStreamObject<C>(loadable))
		}
		
		_iterator = .init(bufferingPolicy: bufferingPolicy) { [weak self] continuation in
			self?.continuation = continuation
		}
	}
	
	/// Finish the stream, this stops the `for await` loop. This is required to call somewhere, either by `deinit` (via
	/// a stored property) or manually.
	public func finish() {
		continuation.finish()
		observer.remove()
	}
	
	deinit {
		finish()
	}
}

/// Stateful object that get's passed in the ``AsyncLoadableStream/iterator``.
public struct AsyncLoadableStreamObject<C> {

	/// Contents property of the ``AsyncLoadable``, only available if ``AsyncLoadable/isContentsAvailable``.
	public let content: C?
	
	/// Error property of the ``AsyncLoadable``, if any.
	public let error: Error?
	
	/// The current state of the ``AsyncLoadable``.
	public let state: MMMLoadableState
	
	internal init(_ loadable: AsyncLoadable<C>) {
		self.content = loadable.isContentsAvailable ? loadable.content : nil
		self.error = loadable.error
		self.state = loadable.loadableState
	}
}
