import Foundation

/// Main coordinator actor for image caching.
/// Orchestrates memory cache, disk cache, and network downloads.
public actor ImageCacheActor {
    /// Shared singleton instance.
    public static let shared = ImageCacheActor()
    
    private let memoryCache = MemoryCache.shared
    private let diskCache = DiskCache.shared
    private let session: URLSession
    
    /// In-flight download tasks to coalesce concurrent requests.
    private var inFlightTasks: [URL: Task<PlatformImage, Error>] = [:]
    
    /// Creates an image cache with default configuration.
    public init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = URLSession(configuration: config)
    }
    
    // MARK: - Public API
    
    /// Fetches an image from cache or downloads it.
    /// - Parameter url: The URL of the image to fetch.
    /// - Returns: The loaded image.
    /// - Throws: An error if the image cannot be loaded.
    public func image(for url: URL) async throws -> PlatformImage {
        // 1. Check memory cache (synchronous, fast)
        if let cachedImage = memoryCache.image(for: url) {
            return cachedImage
        }
        
        // 2. Check if there's already a download in progress
        if let existingTask = inFlightTasks[url] {
            return try await existingTask.value
        }
        
        // 3. Create a new download task
        let task = Task<PlatformImage, Error> {
            // Check disk cache
            if let cachedData = await diskCache.loadImage(for: url) {
                if let image = PlatformImage(data: cachedData.imageData) {
                    // Populate memory cache
                    memoryCache.setImage(image, for: url)
                    return image
                }
            }
            
            // Download from network
            let (data, response) = try await session.data(from: url)
            
            // Validate response
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw ImageCacheError.invalidResponse
            }
            
            // Create image
            guard let image = PlatformImage(data: data) else {
                throw ImageCacheError.invalidImageData
            }
            
            // Save to caches
            memoryCache.setImage(image, for: url)
            try? await diskCache.saveImage(data, for: url)
            
            return image
        }
        
        // Store task for coalescing
        inFlightTasks[url] = task
        
        // Clean up after completion
        defer { inFlightTasks[url] = nil }
        
        return try await task.value
    }
    
    /// Prefetches images for the given URLs.
    /// - Parameter urls: The URLs to prefetch.
    public func prefetch(urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = try? await self.image(for: url)
                }
            }
        }
    }
    
    /// Removes a cached image.
    /// - Parameter url: The URL of the image to remove.
    public func removeImage(for url: URL) async {
        memoryCache.removeImage(for: url)
        await diskCache.removeImage(for: url)
    }
    
    /// Clears all cached images from memory and disk.
    public func clearAll() async throws {
        memoryCache.removeAll()
        try await diskCache.clearAll()
    }
    
    /// Removes expired images from disk cache.
    /// - Returns: The number of expired items removed.
    @discardableResult
    public func cleanupExpired() async -> Int {
        return await diskCache.cleanupExpired()
    }
    
    /// Returns the total size of the disk cache in bytes.
    public func diskCacheSize() async -> Int64 {
        return await diskCache.totalSize()
    }
}

// MARK: - Public Typealiases

/// Convenience typealias for the shared cache instance.
public typealias ImageCache = ImageCacheActor

// MARK: - Errors

/// Errors that can occur during image caching.
public enum ImageCacheError: Error, LocalizedError {
    case invalidResponse
    case invalidImageData
    case downloadFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid server response"
        case .invalidImageData:
            return "Unable to decode image data"
        case .downloadFailed(let error):
            return "Download failed: \(error.localizedDescription)"
        }
    }
}
