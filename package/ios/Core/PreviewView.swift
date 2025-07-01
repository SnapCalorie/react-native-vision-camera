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
  private var arView: UIView?

  // Standard preview initializer
  init(frame: CGRect, session: AVCaptureSession, enableMeshWireframe: Bool = false) {
    super.init(frame: frame)
    if enableMeshWireframe, #available(iOS 13.0, *) {
      #if canImport(ARKit)
      // Use ARSCNView for AR mesh wireframe preview
      if let ARSCNViewClass = NSClassFromString("ARSCNView") as? UIView.Type {
        let arView = ARSCNViewClass.init(frame: frame)
        arView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.arView = arView
        addSubview(arView)
        // Notify delegate that preview started
        self.delegate?.onPreviewStarted()
      }
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
