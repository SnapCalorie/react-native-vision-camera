//
//  PreviewView+SceneRendererDelegate.swift
//  VisionCamera
//
//  Created by Copilot on 2024-06-11.
//

import Foundation
import ARKit
import SceneKit

@available(iOS 13.0, *)
extension PreviewView.VisionArView {
  // Attach this delegate in initializeSessionAndProps if mesh wireframe is enabled

  public func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
    guard #available(iOS 14.0, *),
          ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh),
          showWireframe == true,
          let meshAnchor = anchor as? ARMeshAnchor else {
      return nil
    }

    // Create a parent node to attach the wireframe + occlusion mask
    let node = SCNNode()

    // Use the new Metal-buffer-based geometry creation
    let geometry = SCNGeometry.createGeometryFromAnchor(meshAnchor: meshAnchor)
    let wireNode = SCNNode()
    wireNode.name = "wireframe"
    wireNode.geometry = geometry
    wireNode.geometry?.firstMaterial = wireframeMaterial
    // Add a fill using the same wireframe geom
    let wireFillNode = SCNNode()
    wireFillNode.name = "wireframeFill"
    wireFillNode.geometry = geometry.copy() as? SCNGeometry
    wireFillNode.geometry?.firstMaterial = wireframeFillMaterial
    // Create an occlusion geometry that sits just under the wireframe
    let occludeNode = SCNNode()
    occludeNode.name = "occluder"
    occludeNode.geometry = geometry.copy() as? SCNGeometry
    occludeNode.geometry?.firstMaterial = occludeMaterial
    occludeNode.renderingOrder = -1

    node.addChildNode(wireNode)
    node.addChildNode(wireFillNode)
    node.addChildNode(occludeNode)

    return node
  }

  public func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    guard #available(iOS 14.0, *),
          ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh),
          showWireframe == true,
          let meshAnchor = anchor as? ARMeshAnchor else {
      return
    }

    let geometry = SCNGeometry.createGeometryFromAnchor(meshAnchor: meshAnchor)

    guard let wireNode = node.childNode(withName: "wireframe", recursively: true),
          let wireFillNode = node.childNode(withName: "wireframeFill", recursively: true),
          let occludeNode = node.childNode(withName: "occluder", recursively: true)
    else {
      return
    }

    wireNode.geometry = geometry
    wireNode.geometry?.firstMaterial = wireframeMaterial

    wireFillNode.geometry = geometry.copy() as? SCNGeometry
    wireFillNode.geometry?.firstMaterial = wireframeFillMaterial

    occludeNode.geometry = geometry.copy() as? SCNGeometry
    occludeNode.geometry?.firstMaterial = occludeMaterial
  }
}
