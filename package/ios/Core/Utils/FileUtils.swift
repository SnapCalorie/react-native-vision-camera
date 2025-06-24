//
//  FileUtils.swift
//  VisionCamera
//
//  Created by Marc Rousavy on 26.02.24.
//  Copyright © 2024 mrousavy. All rights reserved.
//

import AVFoundation
import CoreLocation
import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum FileUtils {
  /**
   Writes Data to a temporary file.
   */
  private static func writeDataToFile(data: Data, file: URL) throws {
    do {
      if file.isFileURL {
        try data.write(to: file)
      } else {
        guard let url = URL(string: "file://\(file.absoluteString)") else {
          throw CameraError.capture(.createTempFileError(message: "Cannot create URL with file:// prefix!"))
        }
        try data.write(to: url)
      }
    } catch {
      throw CameraError.capture(.fileError(cause: error))
    }
  }

  static func writePhotoToFile(photo: AVCapturePhoto, metadataProvider: MetadataProvider, file: URL) throws {
    guard let data = photo.fileDataRepresentation(with: metadataProvider) else {
      throw CameraError.capture(.imageDataAccessError)
    }
    try writeDataToFile(data: data, file: file)
  }

  static func writeUIImageToFile(image: UIImage, file: URL, compressionQuality: CGFloat = 1.0) throws {
    guard let data = image.jpegData(compressionQuality: compressionQuality) else {
      throw CameraError.capture(.imageDataAccessError)
    }
    try writeDataToFile(data: data, file: file)
  }

  static func writeDepthToFile(depthData: AVDepthData, file: URL, orientation: CGImagePropertyOrientation? = nil) throws {
    // Apply EXIF orientation if provided
    var orientedDepthData = depthData
    if let orientation = orientation {
      orientedDepthData = orientedDepthData.applyingExifOrientation(orientation)
    }
    // Always convert to DepthFloat32 for consistency
    if orientedDepthData.depthDataType != kCVPixelFormatType_DepthFloat32 {
      orientedDepthData = orientedDepthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
    }
    let pixelBuffer = orientedDepthData.depthDataMap

    // Check pixel format is DepthFloat32
    let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
    guard format == kCVPixelFormatType_DepthFloat32 else {
      throw CameraError.capture(.imageDataAccessError)
    }
    // Check for planarity (depth buffers should not be planar)
    guard !CVPixelBufferIsPlanar(pixelBuffer) else {
      throw CameraError.capture(.imageDataAccessError)
    }
    // Check for extended pixels (should be 0 for depth, but warn if not)
    var extraLeft = 0, extraRight = 0, extraTop = 0, extraBottom = 0
    CVPixelBufferGetExtendedPixels(pixelBuffer, &extraLeft, &extraRight, &extraTop, &extraBottom)
    if extraLeft != 0 || extraRight != 0 || extraTop != 0 || extraBottom != 0 {
      print("[FileUtils] Warning: Depth pixel buffer has extended pixels (padding): left=\(extraLeft), right=\(extraRight), top=\(extraTop), bottom=\(extraBottom)")
    }
    CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
    let validBytesPerRow = width * MemoryLayout<Float32>.size
    guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
      throw CameraError.capture(.imageDataAccessError)
    }
    // Write only the valid part of each row (skip padding)
    // Each row in the pixel buffer may have extra padding bytes at the end (bytesPerRow > validBytesPerRow).
    // We only want to write the actual depth data, which is width * sizeof(Float32) bytes per row.
    // This avoids duplicating or misaligning the buffer when reading it back.
    var depthDataBuffer = Data(capacity: validBytesPerRow * height)
    for row in 0..<height {
      let rowStart = baseAddress.advanced(by: row * bytesPerRow)
      // Only append the valid data, not the padding.
      depthDataBuffer.append(rowStart.assumingMemoryBound(to: UInt8.self), count: validBytesPerRow)
    }
    try writeDataToFile(data: depthDataBuffer, file: file)
  }
  
  // Helper to get the true depth data dimensions (excluding any row padding), matching the orientation if provided
  static func getDepthDimensions(depthData: AVDepthData, orientation: CGImagePropertyOrientation? = nil) -> (width: Int, height: Int, validBytesPerRow: Int) {
    var orientedDepthData = depthData
    if let orientation = orientation {
      orientedDepthData = orientedDepthData.applyingExifOrientation(orientation)
    }
    if orientedDepthData.depthDataType != kCVPixelFormatType_DepthFloat32 {
      orientedDepthData = orientedDepthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
    }
    let pixelBuffer = orientedDepthData.depthDataMap
    let width = CVPixelBufferGetWidth(pixelBuffer)
    let height = CVPixelBufferGetHeight(pixelBuffer)
    let validBytesPerRow = width * MemoryLayout<Float32>.size
    // validBytesPerRow is the number of bytes per row in the written file (no padding)
    return (width, height, validBytesPerRow)
  }

  static var tempDirectory: URL {
    return FileManager.default.temporaryDirectory
  }

  static func createRandomFileName(withExtension fileExtension: String) -> String {
    return UUID().uuidString + "." + fileExtension
  }

  static func getFilePath(directory: URL, fileExtension: String) throws -> URL {
    // Random UUID filename
    let filename = createRandomFileName(withExtension: fileExtension)
    return directory.appendingPathComponent(filename)
  }

  static func getFilePath(customDirectory: String, fileExtension: String) throws -> URL {
    // Prefix with file://
    let prefixedDirectory = customDirectory.starts(with: "file:") ? customDirectory : "file://\(customDirectory)"
    // Create URL
    guard let url = URL(string: prefixedDirectory) else {
      throw CameraError.capture(.invalidPath(path: customDirectory))
    }
    return try getFilePath(directory: url, fileExtension: fileExtension)
  }

  static func getFilePath(fileExtension: String) throws -> URL {
    return try getFilePath(directory: tempDirectory, fileExtension: fileExtension)
  }
}
