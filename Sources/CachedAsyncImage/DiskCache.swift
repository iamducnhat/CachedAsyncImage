import Foundation
import CryptoKit

/// Actor-protected disk cache for persistent image storage.
public actor DiskCache {
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let policy: CachePolicy
    
    /// Shared instance with default cache policy.
    public static let shared = DiskCache(policy: .default)
    
    /// Creates a disk cache with the specified policy.
    /// - Parameter policy: The cache policy to use for expiration.
    public init(policy: CachePolicy) {
        self.policy = policy
        
        // Use Caches directory for automatic cleanup by system
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        self.cacheDirectory = cachesURL.appendingPathComponent("ImageCache", isDirectory: true)
        
        // Create directory if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public API
    
    /// Loads an image from disk cache.
    /// - Parameter url: The URL of the original image.
    /// - Returns: The cached image data and metadata, or `nil` if not found or expired.
    public func loadImage(for url: URL) -> CachedImageData? {
        let fileURL = fileURL(for: url)
        let metadataURL = metadataURL(for: url)
        
        // Check if files exist
        guard fileManager.fileExists(atPath: fileURL.path),
              fileManager.fileExists(atPath: metadataURL.path) else {
            return nil
        }
        
        do {
            // Load and decode metadata
            let metadataData = try Data(contentsOf: metadataURL)
            let metadata = try JSONDecoder().decode(CacheMetadata.self, from: metadataData)
            
            // Check expiration
            if policy.isExpired(cachedAt: metadata.cachedAt) {
                // Delete expired files
                try? fileManager.removeItem(at: fileURL)
                try? fileManager.removeItem(at: metadataURL)
                return nil
            }
            
            // Load image data
            let imageData = try Data(contentsOf: fileURL)
            return CachedImageData(imageData: imageData, metadata: metadata)
            
        } catch {
            // Clean up corrupted files
            try? fileManager.removeItem(at: fileURL)
            try? fileManager.removeItem(at: metadataURL)
            return nil
        }
    }
    
    /// Saves an image to disk cache.
    /// - Parameters:
    ///   - data: The image data to cache.
    ///   - url: The URL of the original image.
    public func saveImage(_ data: Data, for url: URL) throws {
        let fileURL = fileURL(for: url)
        let metadataURL = metadataURL(for: url)
        
        // Create metadata
        let metadata = CacheMetadata(cachedAt: Date(), urlString: url.absoluteString)
        let metadataData = try JSONEncoder().encode(metadata)
        
        // Write atomically to prevent corruption
        try data.write(to: fileURL, options: .atomic)
        try metadataData.write(to: metadataURL, options: .atomic)
    }
    
    /// Removes a cached image from disk.
    /// - Parameter url: The URL of the image to remove.
    public func removeImage(for url: URL) {
        let fileURL = fileURL(for: url)
        let metadataURL = metadataURL(for: url)
        
        try? fileManager.removeItem(at: fileURL)
        try? fileManager.removeItem(at: metadataURL)
    }
    
    /// Clears all cached images from disk.
    public func clearAll() throws {
        let contents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
        for item in contents {
            try fileManager.removeItem(at: item)
        }
    }
    
    /// Removes all expired images from disk.
    /// - Returns: The number of expired items removed.
    @discardableResult
    public func cleanupExpired() -> Int {
        var removedCount = 0
        
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
            return 0
        }
        
        // Process metadata files only
        let metadataFiles = contents.filter { $0.pathExtension == "meta" }
        
        for metadataURL in metadataFiles {
            do {
                let metadataData = try Data(contentsOf: metadataURL)
                let metadata = try JSONDecoder().decode(CacheMetadata.self, from: metadataData)
                
                if policy.isExpired(cachedAt: metadata.cachedAt) {
                    // Remove both metadata and image files
                    let imageURL = metadataURL.deletingPathExtension()
                    try? fileManager.removeItem(at: metadataURL)
                    try? fileManager.removeItem(at: imageURL)
                    removedCount += 1
                }
            } catch {
                // Remove corrupted metadata
                try? fileManager.removeItem(at: metadataURL)
            }
        }
        
        return removedCount
    }
    
    /// Returns the total size of the disk cache in bytes.
    public func totalSize() -> Int64 {
        guard let contents = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        return contents.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }
    
    // MARK: - Private Helpers
    
    /// Generates a safe filename from a URL using SHA256.
    private func hash(for url: URL) -> String {
        let data = Data(url.absoluteString.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    /// Returns the file URL for cached image data.
    private func fileURL(for url: URL) -> URL {
        return cacheDirectory.appendingPathComponent(hash(for: url))
    }
    
    /// Returns the file URL for cached metadata.
    private func metadataURL(for url: URL) -> URL {
        return cacheDirectory.appendingPathComponent(hash(for: url) + ".meta")
    }
}
