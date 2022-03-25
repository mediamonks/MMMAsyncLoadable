# MMMAsyncLoadable

[![Build](https://github.com/mediamonks/MMMAsyncLoadable/workflows/Build/badge.svg)](https://github.com/mediamonks/MMMAsyncLoadable/actions?query=workflow%3ABuild)
[![Test](https://github.com/mediamonks/MMMAsyncLoadable/workflows/Test/badge.svg)](https://github.com/mediamonks/MMMAsyncLoadable/actions?query=workflow%3ATest)

Use async/await with [MMMLoadable](https://github.com/mediamonks/MMMLoadable).

(This is a part of `MMMTemple` suite of iOS libraries we use at [MediaMonks](https://www.mediamonks.com/).)

## Installation

SPM:
```swift
.package(url: "https://github.com/mediamonks/MMMAsyncLoadable", .upToNextMajor(from: "0.1.0"))
```

Podfile:

```ruby
source 'https://github.com/mediamonks/MMMSpecs.git'
source 'https://github.com/CocoaPods/Specs.git'
...
pod 'MMMLoadable'
```

## Usage

### AsyncLoadable

An async loadable makes it possible to fetch the content `C` using the
async/await syntax. `AsyncLoadable` is a concrete implementation of
`AsyncLoadableProtocol`, subclass `AsyncLoadable` to make your own loadable, so
you can avoid working with generics "down the line".

`AsyncLoadable<C>` requires that your `MMMLoadable` 'contents' is a single
concrete type `C`. So if your loadable loads multiple values, either pass a
`tuple` (recommended up to 2 values) or a wrapping `struct`.

It introduces 2 new methods, `fetch` and `fetchIfNeeded`.

#### Fetch

`func fetch() async throws -> C`, fetch the content asynchronously, instead of
adding a listener, this will throw upon `setFailedWithError` and return the
content when `setDidSyncSuccessfully`. Equivalent of `MMMLoadable/sync()`.

#### Fetch if needed

`func fetchIfNeeded() async throws -> C`, similar to `fetch()`, only when
`MMMPureLoadableProtocol/needsSync()` is `true`. Equivalent of `syncIfNeeded()`.

Apart from that you're able to `map`/`flatMap` an `AsyncLoadable`.

#### Map

`func map<T>(_ transform: @escaping (C) throws -> T) -> AsyncLoadable<T>`

Map a `AsyncLoadable<C>` into `AsyncLoadable<T>` by supplying a closure that
maps `C` into `T`. This is helpful if you want to quickly map a loadable from a
"thin" to a "fat" model without creating unnecessary `MMMLoadableProxy`s.
E.g. `AsyncLoadable<API.User>` into `AsyncLoadable<Models.User>`.

If the original loadable is already synced / has contents available, we map it
directly.

If there is an error thrown in the callback, we use that as the new
`AsyncLoadable/error` and set it to failed.

**Example**
```swift
func fetchUser() -> AsyncLoadable<Models.User> {
    // apiClient.getUser() returns AsyncLoadable<API.User>
	apiClient.getUser().map { apiUser in
        return Models.User(apiModel: apiUser)
	}
}
```

#### AsyncMap

`func asyncMap<T>(_ transform: @escaping (C) async throws -> T) -> AsyncLoadable<T>`

Map a `AsyncLoadable<C>` into `AsyncLoadable<T>` by supplying a `async` closure
that maps `C` into `T`. This is similar to `map` but allows to take a `async`
closure, downside of this is that it won't directly map the loadable if content
is available, so you'll have to make sure to sync it again.

If there is an error thrown in the callback, we use that as the new
`AsyncLoadable/error` and set it to failed.

**Example**
```swift
func fetchUser() -> AsyncLoadable<Models.User> {
    // apiClient.getUser() returns AsyncLoadable<API.User>
	apiClient.getUser().asyncMap { apiUser in
        try await Models.FetchUser(apiModel: apiUser)
	}
}
```

#### FlatMap

`func flatMap<T>(_ transform: @escaping (C) async throws -> AsyncLoadable<T>) -> AsyncLoadable<T>`

FlatMap a `AsyncLoadable<C>` into `AsyncLoadable<T>` by supplying a closure that
maps `C` into `AsyncLoadable<T>`. This is helpful if you want to chain loadables
without having to observe each one.

For example say you have `LoadableA` that upon success will load `LoadableB`
using a value in it's contents, `LoadableB` will be exposed to the users, since
that only contains valuable info for them. If `LoadableA` fails, we don't have
to try to load `LoadableB`.

If there is an error thrown in the callback, we use that as the new
`AsyncLoadable/error` and set it to failed.

**Please note** that unlike the map function, that doesn't take an async closure,
if the content is available, we don't map it directly, you will have to sync the
loadable again. The original loadable won't ever sync again if content is
available, you will have to call `sync` manually to do that.

**Example**
```swift
func fetchLoadableB() -> AsyncLoadable<BValue> {
	loadableA().flatMap { aVal in
		return LoadableB(identifier: aVal.identifier)
	}
}
```

#### Joined

`func joined<T>(_ transform: @escaping (C) async throws -> AsyncLoadable<T>) -> AsyncLoadable<(C, T)>`

Join two `AsyncLoadable`s together, from `AsyncLoadable<C>`` and `AsyncLoadable<T>`
to a `AsyncLoadable<(C, T)>`. This could come in useful when you want to grab
data from `C` to construct your loadable `T` without losing `C`.

This behaves the same as `AsyncLoadable/flatMap(_:)`.

**Example**
```swift
func fetchLoadableB() -> AsyncLoadable<(AValue, BValue)> {
  loadableA().joined { aVal in
    return LoadableB(identifier: aVal.identifier)
  }
}
```

### AsyncLoadableObserver

`MMMLoadableObserver` that supports an asynchronous closure as it's callback.

### AsyncLoadableStream

Listen to an `AsyncLoadable` by using an `AsyncStream`. This allows you to
iterate over the `AsyncLoadableStream/iterator`, this will stream a new
`AsyncLoadableStreamObject` on every change in the loadable.

For example:

```swift
class MyView: UIView {

	private let loadable: AsyncLoadable<MyData>

	// It's crucial that we call `finish()` somehow, this is also called upon
	// deinit, so storing it as a property is an easy way to accomplish this.
	private var stream: AsyncLoadableStream<MyData>?

	public init(loadable: AsyncLoadable<MyData>) {

		let stream = AsyncLoadableStream(loadable)

		self.loadable = loadable
		self.stream = stream

		for await obj in stream.iterator {
			// Do something with the stream object, e.g. update UI.
			updateUI()
		}
	}

	private func updateUI() {
		loader.isHidden = loadable.loadableState != .syncing
	}
}
```

**Please note** that due to the nature of `async/await` in swift it's crucial to
store the stream as a local (private) property to ensure that
`AsyncLoadableStream/finish()` get's called upon `deinit`. This stops the
stream. Otherwise your `Actor` will get blocked indefinitely, since it will keep
on waiting for new values, causing a memory leak.

## Ready for liftoff? 🚀

We're always looking for talent. Join one of the fastest-growing rocket ships in
the business. Head over to our [careers page](https://media.monks.com/careers)
for more info!
