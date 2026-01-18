# CachedAsyncImage

A lightweight, production-ready image caching library for SwiftUI using Swift's native concurrency.

[![Swift 6.0](https://img.shields.io/badge/Swift-6.0-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2015%20|%20macOS%2012%20|%20tvOS%2015%20|%20watchOS%208-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

- **Two-layer caching** — Fast in-memory cache backed by persistent disk storage
- **Swift concurrency** — Built entirely with `actor` and `async/await`
- **Request coalescing** — Concurrent requests for the same URL share one download
- **Automatic expiration** — 30-day TTL with configurable policy
- **Zero dependencies** — No Combine, no third-party libraries

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/iamducnhat/CachedAsyncImage.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** → paste the repository URL.

## Usage

### SwiftUI View

```swift
import CachedAsyncImage

struct ContentView: View {
    var body: some View {
        CachedAsyncImage(url: URL(string: "https://example.com/image.jpg")) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure:
                Image(systemName: "photo")
            }
        }
    }
}
```

### Direct API

```swift
// Fetch image
let image = try await ImageCache.shared.image(for: url)

// Prefetch
await ImageCache.shared.prefetch(urls: [url1, url2, url3])

// Clear cache
try await ImageCache.shared.clearAll()

// Cleanup expired
await ImageCache.shared.cleanupExpired()
```

## Architecture

```
Request → Memory Cache → Disk Cache → Network
              ↓              ↓
           (hit)          (hit + valid)
              ↓              ↓
           Return ←──────────┘
```

| Component | Description |
|-----------|-------------|
| `MemoryCache` | `NSCache` wrapper with auto-eviction |
| `DiskCache` | Actor-protected `FileManager` storage |
| `ImageCacheActor` | Coordinator with request coalescing |
| `CachePolicy` | 30-day expiration logic |

## Requirements

- iOS 15.0+ / macOS 12.0+ / tvOS 15.0+ / watchOS 8.0+
- Swift 6.0+

## License

MIT License. See [LICENSE](LICENSE) for details.
