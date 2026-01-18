import SwiftUI

/// A view that asynchronously loads and displays an image with caching.
public struct CachedAsyncImage<Content: View>: View {
    private let url: URL?
    private let content: (AsyncImagePhase) -> Content
    
    @State private var phase: AsyncImagePhase = .empty
    
    /// Creates a cached async image with custom content.
    /// - Parameters:
    ///   - url: The URL of the image to display.
    ///   - content: A closure that returns the view for each phase.
    public init(
        url: URL?,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.content = content
    }
    
    public var body: some View {
        content(phase)
            .task(id: url) {
                await loadImage()
            }
    }
    
    private func loadImage() async {
        guard let url = url else {
            phase = .empty
            return
        }
        
        do {
            let image = try await ImageCache.shared.image(for: url)
            #if canImport(UIKit)
            phase = .success(Image(uiImage: image))
            #elseif canImport(AppKit)
            phase = .success(Image(nsImage: image))
            #endif
        } catch {
            phase = .failure(error)
        }
    }
}

// MARK: - Convenience Initializers

extension CachedAsyncImage {
    /// Creates a cached async image with default placeholder and error views.
    /// - Parameter url: The URL of the image to display.
    public init(url: URL?) where Content == _ConditionalContent<_ConditionalContent<ProgressView<EmptyView, EmptyView>, Image>, Image> {
        self.init(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
            case .success(let image):
                image
            case .failure:
                Image(systemName: "photo")
            @unknown default:
                Image(systemName: "photo")
            }
        }
    }
}

// MARK: - AsyncImagePhase

/// The current phase of an async image loading operation.
public enum AsyncImagePhase: Sendable {
    /// No image is loaded.
    case empty
    /// An image successfully loaded.
    case success(Image)
    /// The image failed to load with an error.
    case failure(Error)
    
    /// The loaded image, if any.
    public var image: Image? {
        if case .success(let image) = self {
            return image
        }
        return nil
    }
    
    /// The error that occurred, if any.
    public var error: Error? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}
