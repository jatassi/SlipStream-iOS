/// Storage seam for the JWT. `load()` is async because the real implementation prompts for Face ID.
public protocol TokenStore: Sendable {
    func save(_ token: String) throws
    func load() async throws -> String?
    func delete() throws
}
