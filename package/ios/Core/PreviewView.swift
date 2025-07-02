//
//  PreviewView.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 30.11.22.
//  Copyright © 2022 mrousavy. All rights reserved.
//

import AVFoundation
import Foundation
import UIKit

#if canImport(ARKit)
import ARKit
#endif

// MARK: - PreviewViewDelegate

protocol PreviewViewDelegate: AnyObject {
  func onPreviewStarted()
  func onPreviewStopped()
}

// MARK: - PreviewView

final class PreviewView: UIView {
  /**
   A delegate for listening to events of the Preview View.
   */
  weak var delegate: PreviewViewDelegate?

  /**
   Convenience wrapper to get layer as its statically known type.
   */
  var videoPreviewLayer: AVCaptureVideoPreviewLayer {
    // swiftlint:disable force_cast
    return layer as! AVCaptureVideoPreviewLayer
    // swiftlint:enable force_cast
  }

  /**
   Gets or sets the resize mode of the PreviewView.
   */
  var resizeMode: ResizeMode = .cover {
    didSet {
      switch resizeMode {
      case .cover:
        videoPreviewLayer.videoGravity = .resizeAspectFill
      case .contain:
        videoPreviewLayer.videoGravity = .resizeAspect
      }
    }
  }

  override public static var layerClass: AnyClass {
    return AVCaptureVideoPreviewLayer.self
  }

  func layerRectConverted(fromMetadataOutputRect rect: CGRect) -> CGRect {
    return videoPreviewLayer.layerRectConverted(fromMetadataOutputRect: rect)
  }

  func captureDevicePointConverted(fromLayerPoint point: CGPoint) -> CGPoint {
    return videoPreviewLayer.captureDevicePointConverted(fromLayerPoint: point)
  }

  private var isPreviewingObserver: NSKeyValueObservation?
  var arView: UIView?

  #if canImport(ARKit)
  @available(iOS 13.0, *)
  class VisionArView: ARSCNView, ARSCNViewDelegate, ARSessionDelegate {
    var isInitialized = false
    var isPaused = true
    var showWireframe: Bool = true
    var wireframeLinesColor: UIColor = .cyan
    var wireframeFillColor: UIColor = UIColor(red: 1, green: 0, blue: 1, alpha: 0.67)
    var cameraZFar: CGFloat = 1.0
    var wireframeMaterial = SCNMaterial()
    var wireframeFillMaterial = SCNMaterial()
    var occludeMaterial = SCNMaterial()

    // This method shouldn't create its own session
    func initializeSessionAndProps() {
      guard !isInitialized else { return }
      self.delegate = self
      // Don't set the session.delegate here, it's already set in CameraSession+ARKit
      
      self.pointOfView?.camera?.zFar = cameraZFar
      if showWireframe {
        self.debugOptions = [.showWireframe]

        // Configure the wireframe material
        wireframeMaterial.fillMode = .lines
        wireframeMaterial.diffuse.contents = wireframeLinesColor
        // Configure wireframe fill material
        wireframeFillMaterial.fillMode = .fill
        wireframeFillMaterial.diffuse.contents = wireframeFillColor
        // Configure the occlude material
        occludeMaterial.fillMode = .fill
        occludeMaterial.colorBufferWriteMask = []
        occludeMaterial.isDoubleSided = true
        occludeMaterial.writesToDepthBuffer = true
      }
      isInitialized = true
      isPaused = false
      VisionLogger.log(level: .info, message: "ARKit view initialized with mesh wireframe: \(showWireframe)")
    }
  }
  #endif

  // Standard preview initializer
  init(frame: CGRect, session: AVCaptureSession, enableMeshWireframe: Bool = false) {
    super.init(frame: frame)
    if enableMeshWireframe, #available(iOS 13.0, *) {
      #if canImport(ARKit)
      // Use VisionArView for AR mesh wireframe preview
      let arView = VisionArView(frame: frame)
      arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      arView.showWireframe = true
      // Don't initialize the session here - we'll use the existing one
      self.arView = arView
      addSubview(arView)
      // Notify delegate that preview started
      self.delegate?.onPreviewStarted()
      #endif
    } else {
      videoPreviewLayer.session = session
      videoPreviewLayer.videoGravity = .resizeAspectFill

      if #available(iOS 13.0, *) {
        isPreviewingObserver = videoPreviewLayer.observe(\.isPreviewing, changeHandler: { [weak self] layer, _ in
          guard let self else { return }
          if layer.isPreviewing {
            VisionLogger.log(level: .info, message: "Preview Layer started previewing.")
            self.delegate?.onPreviewStarted()
          } else {
            VisionLogger.log(level: .info, message: "Preview Layer stopped previewing.")
            self.delegate?.onPreviewStopped()
          }
        })
      }
    }
  }

  // ARKit mesh wireframe initializer (no AVCaptureSession)
  convenience init(frame: CGRect, enableMeshWireframe: Bool) {
    self.init(frame: frame, session: AVCaptureSession(), enableMeshWireframe: enableMeshWireframe)
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) is not implemented!")
  }

  override func removeFromSuperview() {
    // If AR mode, notify delegate that preview stopped
    if arView != nil {
      self.delegate?.onPreviewStopped()
    }
    super.removeFromSuperview()
  }
}