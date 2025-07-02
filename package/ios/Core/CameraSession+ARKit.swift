import Foundation
import ARKit
import AVFoundation
import CoreImage

@available(iOS 13.0, *)
extension CameraSession {
  // Store ARSession as a property
  var arSession: ARSession? {
    get { objc_getAssociatedObject(self, &arSessionKey) as? ARSession }
    set { objc_setAssociatedObject(self, &arSessionKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
  }

  func configureARKitSession(configuration: CameraConfiguration) throws {
    VisionLogger.log(level: .info, message: "Configuring ARKit Session for Camera...")

    // Check if ARKit is supported on this device
    guard ARWorldTrackingConfiguration.isSupported else {
      throw CameraError.arKit(.arKitNotSupported)
    }

    // Clean up existing ARKit session if it exists
    if arSession != nil {
      arSession?.pause()
      arSession = nil
    }

    // Create a new ARSession
    let session = ARSession()
    session.delegate = self

    // Configure ARKit
    let arConfig = ARWorldTrackingConfiguration()

    // Enable depth data
    if ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth, .smoothedSceneDepth]) {
      arConfig.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
    }

    // Configure mesh wireframe if requested and supported
    if configuration.enableMeshWireframe == true {
      if ARWorldTrackingConfiguration.supportsSceneReconstruction(.mesh) {
        arConfig.sceneReconstruction = .mesh
        VisionLogger.log(level: .info, message: "ARKit mesh reconstruction enabled")
      } else {
        VisionLogger.log(level: .warning, message: "Device does not support ARKit mesh reconstruction")
      }
    }

    // Start ARKit session
    session.run(arConfig, options: [.resetTracking, .removeExistingAnchors])

    // Store the ARSession for later use
    self.arSession = session

    // Notify delegate that camera is initialized with ARKit
    delegate?.onSessionInitialized()

    VisionLogger.log(level: .info, message: "Successfully configured ARKit Session!")
  }
}

// Associated object key for arSession property
private var arSessionKey: UInt8 = 0

// Add ARSessionDelegate conformance
@available(iOS 13.0, *)
extension CameraSession: ARSessionDelegate {
  func session(_ session: ARSession, didUpdate frame: ARFrame) {
    // Add debug log to verify frame updates are occurring
    VisionLogger.log(level: .debug, message: "ARKit frame update received at timestamp: \(frame.timestamp)")

    // Handle ARKit frames
    // Pass frame data to delegates similar to how AVFoundation frames are handled

    guard let delegate = delegate else { return }
    let pixelBuffer = frame.capturedImage
    let timestamp = CMTime(seconds: frame.timestamp, preferredTimescale: 1_000_000_000)

    // Wrap pixelBuffer in a CMSampleBuffer for compatibility
    var sampleBufferOut: CMSampleBuffer?
    var timingInfo = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: timestamp, decodeTimeStamp: .invalid)
    var videoInfo: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescriptionOut: &videoInfo)
    if let videoInfo {
      CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pixelBuffer, formatDescription: videoInfo, sampleTiming: &timingInfo, sampleBufferOut: &sampleBufferOut)
    }

    // Process depth data if available
    var depthData: AVDepthData?
    if let depthMap = frame.sceneDepth?.depthMap {
      // Hardcoded metadata dictionary as per the provided example
      let hardcodedMetadata: [String: Any] = [
        "depthData:PixelSize": 0.002684,
        "depthData:LensDistortionCoefficients": [
          0,
          "0.6333219",
          "-0.04633136",
          "0.001448097",
          "1.053968e-05",
          "-1.697085e-06",
          "3.409289e-08",
          "-1.917946e-10"
        ],
        "depthData:Accuracy": "absolute",
        "depthData:IntrinsicMatrixReferenceHeight": 2160,
        "depthData:DepthDataVersion": 125537,
        "depthData:ExtrinsicMatrix": [
          1, 0, 0, 0,
          1, 0, 0, 0,
          1, 0, 0, 0
        ],
        "depthData:InverseLensDistortionCoefficients": [
          0,
          "-0.6520117",
          "0.05041073",
          "-0.001673263",
          "-9.52287e-06",
          "1.967966e-06",
          "-4.135257e-08",
          "2.367362e-10"
        ],
        "depthData:IntrinsicMatrix": [
          "2431.85", 0, 0,
          0, "2431.85", 0,
          "1916.577", "1073.387", 1
        ],
        "depthData:Quality": "high",
        "depthData:LensDistortionCenterOffsetX": 1918.1761047513282,
        "depthData:IntrinsicMatrixReferenceWidth": 3840,
        "depthData:LensDistortionCenterOffsetY": 1076.552988404801,
        "depthData:Filtered": false
      ]

      // Serialize the depthMap to Data (as required by kCGImageAuxiliaryDataInfoData)
      var depthMapData: Data?
      var bytesPerRow: Int = 0
      var width: Int = 0
      var height: Int = 0
      var pixelFormatType: OSType = kCVPixelFormatType_32BGRA
      do {
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        let baseAddress = CVPixelBufferGetBaseAddress(depthMap)
        let dataSize = CVPixelBufferGetDataSize(depthMap)
        if let baseAddress {
          depthMapData = Data(bytes: baseAddress, count: dataSize)
          bytesPerRow = CVPixelBufferGetBytesPerRow(depthMap)
          width = Int(CVPixelBufferGetWidth(depthMap))
          height = Int(CVPixelBufferGetHeight(depthMap))
          pixelFormatType = CVPixelBufferGetPixelFormatType(depthMap)
        }
        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)
      }

      // Hardcode the auxiliaryDataInfo dictionary
      var auxiliaryDataInfo: [CFString : Any] = [
        kCGImageAuxiliaryDataInfoData: depthMapData as Any,
        kCGImageAuxiliaryDataInfoDataDescription: [
          "BytesPerRow": bytesPerRow,
          "Height": height,
          "PixelFormat": pixelFormatType,
          "Width": width
        ],
//        kCGImageAuxiliaryDataInfoMetadata: hardcodedMetadata
      ]

      let dict = [
        kCGImageAuxiliaryDataTypeDepth: auxiliaryDataInfo
      ]

      do {
        depthData = try AVDepthData(fromDictionaryRepresentation: auxiliaryDataInfo)
        // Convert to disparity format if needed for consistency with AVFoundation depth
        if depthData?.depthDataType != kCVPixelFormatType_DisparityFloat32,
           depthData?.availableDepthDataTypes.contains(kCVPixelFormatType_DisparityFloat32) == true {
          depthData = depthData?.converting(toDepthDataType: kCVPixelFormatType_DisparityFloat32)
        }
      } catch {
        print("Failed to create depth data: \(error.localizedDescription)")
        VisionLogger.log(level: .error, message: "Failed to create depth data: \(error.localizedDescription)")
      }
    }

    // Get current orientation
    let orientation = orientationManager.outputOrientation
    let isMirrored = configuration?.isMirrored ?? false

    // Notify delegate about new frame
    if let sampleBuffer = sampleBufferOut {
      CameraQueues.videoQueue.async { [weak self] in
        guard let self = self, let delegate = self.delegate else { return }
        delegate.onFrame(sampleBuffer: sampleBuffer,
                         orientation: orientation,
                         isMirrored: isMirrored,
                         depthData: depthData)
      }
    }
  }

  func session(_ session: ARSession, didFailWithError error: Error) {
    // Handle ARKit errors
    delegate?.onError(.arKit(.sessionFailed(error: error as NSError)))
  }
}
