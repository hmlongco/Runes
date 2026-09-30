![](https://github.com/hmlongco/Runes/blob/main/Logo.png?raw=true)

# Runes 1.0.0

Runes is a collection of common Swift and SwiftUI extensions, modifiers, and other secret and arcane spells I've found useful over the years.

Three of them do most of the heavy lifting: `SharedAsyncStream` for sharing async state, `Toasts` for transient messages, and `SceneGeometry` for layout that knows where it actually lives.

## Installation

Add Runes with Swift Package Manager.

```swift
.package(url: "https://github.com/hmlongco/Runes", branch: "main")
```

Runes requires Swift 6.1 and targets iOS 17, macOS 14, tvOS 17, watchOS 10, and visionOS 1. Toasts are unavailable on macOS.

## SharedAsyncStream

Most services hold a value that several parts of the app care about. `SharedAsyncStream` owns that value, loads it once on first subscription, and broadcasts every change to every subscriber. Late subscribers immediately see the latest value.

```swift
@MainActor
class TestService {
    lazy var integers: SharedAsyncStream<Int> = .init { [weak self] in
        try await safe(self).load()
    }

    func load() async throws -> Int {
        try await Task.sleep(nanoseconds: 3_000_000_000)
        return 2
    }
}
```

The `lazy` matters. Nothing loads until someone subscribes, and the loader can safely reference the service that owns it.

Consumers see an `Element`, which is `.loading`, `.value`, `.error`, or `.cancelled`. Loading and failure are part of the stream instead of something you bolt on beside it.

```swift
.task {
    for await next in service.integers.stream {
        self.value = next.value // nil unless next is a value
    }
}
```

If you'd rather have errors thrown, use `values`. If you only want the answer, await it.

```swift
for try await value in service.integers.values { ... }

let value = try await service.integers.asyncValue()
```

Pushing new state is one call, and everyone sees it.

```swift
service.integers.send(42)
service.integers.fail(with: error)
service.integers.reload()
service.integers.cancel()
```

Not everything is a `for await` loop. View models can assign straight into a property, observe with a closure, or bridge to Combine. Observers are removed automatically when the observing object goes away.

```swift
service.integers.assign(\.assigned, on: self, defaultValue: 0)

service.integers.addObserver(self) { [weak self] element in
    self?.double = element.optionalValue()
}

.onReceive(service.integers.publisher) { element in ... }
```

Behavior is tuned with options: `.loadOnInit`, `.reloadOnActive`, `.reloadsSilently`, and `.throwsCancellationErrors`.

```swift
lazy var integers: SharedAsyncStream<Int> = .init(options: [.reloadOnActive]) { [networking] in
    try await networking.load()
}
```

There's also `init(initialValue:)` for streams with no loader, where the value is simply set and sent.

## Toasts

A toast is a short message that appears at the top of the scene, waits a couple of seconds, and leaves. Toasts queue, so two calls in a row show one after the other. A tap or a drag dismisses the current one.

Install the overlay once at the root of your scene. Without it, toast calls do nothing.

```swift
ContentView()
    .overlayRoot()
```

Then read `toasts` from the environment and call it.

```swift
struct SaveView: View {
    @Environment(\.toasts) private var toasts

    var body: some View {
        Button("Save") {
            toasts.toast("Saved", icon: "checkmark.circle.fill")
        }
    }
}

toasts.toast(error: "Something went wrong.")
toasts.toast(error: someError)
```

Errors get a warning icon, white text, a red background, and a slightly longer stay. Standard toasts pick up `Toast.defaultForegroundColor` and `Toast.defaultBackgroundColor`, so you can theme them once.

Toasts also bind to state. Assigning a value presents the toast and resets the binding to `nil`, so the same message can fire again.

```swift
@State private var message: String?
@State private var error: Error?

Button("Go") { message = "Done" }
    .toast($message)
    .toast(error: $error)
```

For your own designs, conform a type to `ToastViews`. An enum works well, since each case carries its own content.

```swift
enum MyToasts: ToastViews {
    case message(String)
    case error(String)

    var body: some View {
        switch self {
        case .message(let message): Toast(message)
        case .error(let error): Toast(error: error)
        }
    }
}

@State private var toast: MyToasts?

List { ... }
    .toast($toast)

toast = .message("This was a bound toast message.")
toasts.toast(MyToasts.error("Nope."))
```

The same overlay root also provides `blocking`, a full-scene blocking overlay for work that shouldn't be interrupted.

```swift
.blocking(isLoading)
```

## SceneGeometry

`GeometryReader` tells you about a view. `SceneGeometry` tells you about the scene: its size, its safe area, and its size classes, observable from anywhere below the root. It also reports each safe area on devices the system divides, like a folded Surface Duo, so you can lay content out per screen.

Apply the root modifier once.

```swift
ContentView()
    .sceneGeometryRoot()
```

Then read the environment value. `SceneGeometry` is `@Observable`, so a view re-evaluates only when the properties it reads change.

```swift
struct DetailView: View {
    @Environment(\.sceneGeometry) private var sceneGeometry

    var body: some View {
        if sceneGeometry.isHorizontalRegular {
            TwoColumnLayout()
        } else {
            SingleColumnLayout()
        }
    }
}
```

The available values cover what layout code usually needs.

```swift
sceneGeometry.size                  // full scene, including the safe area
sceneGeometry.safeAreaSize          // scene minus the safe area
sceneGeometry.sizes                 // one safe area size per screen when folded
sceneGeometry.safeAreaInsets        // top, leading, bottom, trailing
sceneGeometry.horizontalSizeClass
sceneGeometry.verticalSizeClass
sceneGeometry.isPortrait            // also isLandscape
sceneGeometry.isHorizontalCompact   // also isHorizontalRegular, isVerticalCompact, isVerticalRegular
sceneGeometry.hasTop                // also hasBottom, hasLeading, hasTrailing, hasSafeAreas
```

Two caveats. Orientation comes from the scene's shape, not the hardware, so a split-view iPad app can report portrait while the device is landscape. And the size classes describe the root of the scene, so a sheet or popover may differ.

## Demo

`RunesDemo` is an Xcode project that exercises each of these. Look at `AsyncDemoView`, `ToastsDemoView`, and `SceneDemoView` in `RunesDemo/RunesDemo/Demos`.

## License

Runes is available under the MIT license. See [LICENSE](LICENSE).
