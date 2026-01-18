import Foundation

#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

/// Thread-safe in-memory cache using NSCache.
final class MemoryCache: @unchecked Sendable {
    private let cache = NSCache<NSString, PlatformImage>()
    
    /// Shared instance for app-wide memory caching.
    static let shared = MemoryCache()
    
    private init() {
        // Configure cache limits based on available memory
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }
    
    /// Retrieves an image from the memory cache.
    /// - Parameter url: The URL used as the cache key.
    /// - Returns: The cached image, or `nil` if not found.
    func image(for url: URL) -> PlatformImage? {
        let key = url.absoluteString as NSString
        return cache.object(forKey: key)
    }
    
    /// Stores an image in the memory cache.
    /// - Parameters:
    ///   - image: The image to cache.
    ///   - url: The URL to use as the cache key.
    func setImage(_ image: PlatformImage, for url: URL) {
        let key = url.absoluteString as NSString
        let cost = estimateCost(for: image)
        cache.setObject(image, forKey: key, cost: cost)
    }
    
    /// Removes an image from the memory cache.
    /// - Parameter url: The URL of the cached image to remove.
    func removeImage(for url: URL) {
        let key = url.absoluteString as NSString
        cache.removeObject(forKey: key)
    }
    
    /// Clears all images from the memory cache.
    func removeAll() {
        cache.removeAllObjects()
    }
    
    /// Estimates the memory cost of an image.
    private func estimateCost(for image: PlatformImage) -> Int {
        #if canImport(UIKit)
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
        #elseif canImport(AppKit)
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
        #endif
    }
}
