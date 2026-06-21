import Nuke

/// The shared Nuke pipeline for poster/backdrop artwork. Adds an on-disk
/// `DataCache` on top of Nuke's in-memory cache for high poster throughput, and
/// exposes a cache-clear used on sign-out (shared family device).
public enum PosterImagePipeline {
  /// Install the poster pipeline as `ImagePipeline.shared`. Call once at launch.
  public static func configure() {
    let pipeline = ImagePipeline {
      $0.dataCache = try? DataCache(name: "dev.jatassi.slipstream.posters")
      $0.dataCachePolicy = .automatic
    }
    ImagePipeline.shared = pipeline
  }

  /// Drop all cached artwork (memory + disk). Called when the session ends.
  public static func clearImageCache() {
    ImagePipeline.shared.cache.removeAll()
  }
}
