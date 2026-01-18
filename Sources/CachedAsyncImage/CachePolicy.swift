import Foundation

/// Cache policy defining expiration rules for cached images.
public struct CachePolicy: Sendable {
    /// Maximum age in seconds before a cached item expires.
    public let maxAge: TimeInterval
    
    /// Default policy with 30-day expiration.
    public static let `default` = CachePolicy(maxAge: 30 * 24 * 60 * 60)
    
    /// Creates a cache policy with the specified maximum age.
    /// - Parameter maxAge: Maximum age in seconds.
    public init(maxAge: TimeInterval) {
        self.maxAge = maxAge
    }
    
    /// Checks if a cached item has expired.
    /// - Parameter cachedAt: The date when the item was cached.
    /// - Returns: `true` if the item has expired, `false` otherwise.
    public func isExpired(cachedAt: Date) -> Bool {
        return Date().timeIntervalSince(cachedAt) > maxAge
    }
}

/// Metadata stored alongside cached image data.
struct CacheMetadata: Codable, Sendable {
    let cachedAt: Date
    let urlString: String
}

/// Container for cached image data and metadata.
public struct CachedImageData: Sendable {
    let imageData: Data
    let metadata: CacheMetadata
}
