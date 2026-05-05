import Foundation

public struct Phase0OutputProfileDTO: Codable, Equatable, Hashable, Sendable {
    public let longEdge: Int
    public let fps: Int
    public let codec: String
    public let container: String
    public let preserveAudio: Bool

    public init(
        longEdge: Int,
        fps: Int,
        codec: String,
        container: String,
        preserveAudio: Bool
    ) {
        self.longEdge = longEdge
        self.fps = fps
        self.codec = codec
        self.container = container
        self.preserveAudio = preserveAudio
    }
}
