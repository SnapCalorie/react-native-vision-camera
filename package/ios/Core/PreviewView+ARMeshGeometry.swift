import Foundation
import ARKit
import SceneKit

@available(iOS 14.0, *)
extension SCNGeometry {
  static func createGeometryFromAnchor(meshAnchor: ARMeshAnchor) -> SCNGeometry {
    let meshGeometry = meshAnchor.geometry
    let vertices = meshGeometry.vertices
    let normals = meshGeometry.normals
    let faces = meshGeometry.faces

    let vertexSource = SCNGeometrySource(
      buffer: vertices.buffer,
      vertexFormat: vertices.format,
      semantic: .vertex,
      vertexCount: vertices.count,
      dataOffset: vertices.offset,
      dataStride: vertices.stride
    )

    let normalsSource = SCNGeometrySource(
      buffer: normals.buffer,
      vertexFormat: normals.format,
      semantic: .normal,
      vertexCount: normals.count,
      dataOffset: normals.offset,
      dataStride: normals.stride
    )

    let faceData = Data(bytes: faces.buffer.contents(), count: faces.buffer.length)
    let geometryElement = SCNGeometryElement(
      data: faceData,
      primitiveType: {
        switch faces.primitiveType {
        case .triangle: return .triangles
        default: fatalError("Unknown primitive type")
        }
      }(),
      primitiveCount: faces.count,
      bytesPerIndex: faces.bytesPerIndex
    )

    return SCNGeometry(sources: [vertexSource, normalsSource], elements: [geometryElement])
  }
}
