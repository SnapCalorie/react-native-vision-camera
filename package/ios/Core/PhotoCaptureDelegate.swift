//
//  PhotoCaptureDelegate.swift
//  mrousavy
//
//  Created by Marc Rousavy on 15.12.20.
//  Copyright © 2020 mrousavy. All rights reserved.
//

import AVFoundation

// MARK: - PhotoCaptureDelegate

class PhotoCaptureDelegate: GlobalReferenceHolder, AVCapturePhotoCaptureDelegate {
  private let promise: Promise
  private let enableShutterSound: Bool
  private let cameraSessionDelegate: CameraSessionDelegate?
  private let metadataProvider: MetadataProvider
  private let path: URL

  required init(promise: Promise,
                enableShutterSound: Bool,
                metadataProvider: MetadataProvider,
                path: URL,
                cameraSessionDelegate: CameraSessionDelegate?) {
    self.promise = promise
    self.enableShutterSound = enableShutterSound
    self.metadataProvider = metadataProvider
    self.path = path
    self.cameraSessionDelegate = cameraSessionDelegate
    super.init()
    makeGlobal()
  }

  func photoOutput(_: AVCapturePhotoOutput, willCapturePhotoFor _: AVCaptureResolvedPhotoSettings) {
    if !enableShutterSound {
      // disable system shutter sound (see https://stackoverflow.com/a/55235949/5281431)
      AudioServicesDisposeSystemSoundID(1108)
    }

    // onShutter(..) event
    cameraSessionDelegate?.onCaptureShutter(shutterType: .photo)
  }

  func photoOutput(_: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
    defer {
      removeGlobal()
    }
    if let error = error as NSError? {
      promise.reject(error: .capture(.unknown(message: error.description)), cause: error)
      return
    }

    do {
      try FileUtils.writePhotoToFile(photo: photo,
                                     metadataProvider: metadataProvider,
                                     file: path)
      
      let exif = photo.metadata["{Exif}"] as? [String: Any]
      let width = exif?["PixelXDimension"]
      let height = exif?["PixelYDimension"]
      let exifOrientation = photo.metadata[String(kCGImagePropertyOrientation)] as? UInt32 ?? CGImagePropertyOrientation.up.rawValue
      let cgOrientation = CGImagePropertyOrientation(rawValue: exifOrientation) ?? CGImagePropertyOrientation.up
      let orientation = getOrientation(forExifOrientation: cgOrientation)
      let isMirrored = getIsMirrored(forExifOrientation: cgOrientation)
      
      // NEW: Capture and write depth data to a separate bin file if available
      var depthFilePath: String? = nil
      var depthDims: [String: Int]? = nil
      if let depthData = photo.depthData {
        // Create new URL for the depth data file (e.g., change extension to "depth.bin")
        let depthFileURL = path.deletingPathExtension().appendingPathExtension("depth.bin")
        // Write the raw depth data, rotated to match the output orientation
        try FileUtils.writeDepthToFile(depthData: depthData, file: depthFileURL, orientation: cgOrientation)
        depthFilePath = depthFileURL.absoluteString
        // Get depth dimensions from the rotated depthDataMap (matching orientation)
        let dims = FileUtils.getDepthDimensions(depthData: depthData, orientation: cgOrientation)
        depthDims = [
          "width": dims.width,
          "height": dims.height
        ]
      }
      
      promise.resolve([
        "path": path.absoluteString,
        "width": width as Any,
        "height": height as Any,
        "orientation": orientation,
        "isMirrored": isMirrored,
        "isRawPhoto": photo.isRawPhoto,
        "metadata": photo.metadata,
        "thumbnail": photo.embeddedThumbnailPhotoFormat as Any,
        "depthPath": depthFilePath as Any,
        "depthDims": depthDims as Any
      ])
    } catch let error as CameraError {
      promise.reject(error: error)
    } catch {
      promise.reject(error: .capture(.unknown(message: "An unknown error occured while capturing the photo!")), cause: error as NSError)
    }
  }

  func photoOutput(_: AVCapturePhotoOutput, didFinishCaptureFor _: AVCaptureResolvedPhotoSettings, error: Error?) {
    defer {
      removeGlobal()
    }
    if let error = error as NSError? {
      if error.code == -11807 {
        promise.reject(error: .capture(.insufficientStorage), cause: error)
      } else {
        promise.reject(error: .capture(.unknown(message: error.description)), cause: error)
      }
      return
    }
  }

  private func getOrientation(forExifOrientation exifOrientation: CGImagePropertyOrientation) -> String {
    switch exifOrientation {
    case .up, .upMirrored:
      return "portrait"
    case .down, .downMirrored:
      return "portrait-upside-down"
    case .left, .leftMirrored:
      return "landscape-left"
    case .right, .rightMirrored:
      return "landscape-right"
    default:
      return "portrait"
    }
  }

  private func getIsMirrored(forExifOrientation exifOrientation: CGImagePropertyOrientation) -> Bool {
    switch exifOrientation {
    case .upMirrored, .rightMirrored, .downMirrored, .leftMirrored:
      return true
    default:
      return false
    }
  }
  
  // Helper to convert output orientation string to CGImagePropertyOrientation
  private func cgImagePropertyOrientation(from orientation: String) -> CGImagePropertyOrientation {
    switch orientation {
    case "portrait": return .up
    case "portrait-upside-down": return .down
    case "landscape-left": return .left
    case "landscape-right": return .right
    default: return .up
    }
  }
}
