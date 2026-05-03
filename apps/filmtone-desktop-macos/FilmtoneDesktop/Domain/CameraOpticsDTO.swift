import Foundation

struct CameraOpticsDTO: Codable {
    let source: String
    let fxPx: Double?
    let fyPx: Double?
    let cxPx: Double?
    let cyPx: Double?
    let fovXDeg: Double?
    let fovYDeg: Double?
    let focalLength35mm: Double?
    let lensModel: String?
    let cameraMake: String?
    let cameraModel: String?
}
