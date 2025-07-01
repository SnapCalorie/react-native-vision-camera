//
//  Frame.m
//  VisionCamera
//
//  Created by Marc Rousavy on 08.06.21.
//  Copyright © 2021 mrousavy. All rights reserved.
//

#import "Frame.h"
#import <CoreMedia/CMSampleBuffer.h>
#import <Foundation/Foundation.h>

@implementation Frame {
  CMSampleBufferRef _Nonnull _buffer;
  UIImageOrientation _orientation;
  BOOL _isMirrored;
  NSData *_depthDataMap;
  BOOL _depthDataMapValid;
  size_t _depthWidth;
  size_t _depthHeight;
}

- (instancetype)initWithBuffer:(CMSampleBufferRef)buffer
                   orientation:(UIImageOrientation)orientation
                    isMirrored:(BOOL)isMirrored
                     depthData:(AVDepthData *)depthData {
  self = [super init];
  if (self) {
    _buffer = buffer;
    _orientation = orientation;
    _isMirrored = isMirrored;
    if (depthData != nil) {
      CVPixelBufferRef depthBuffer = depthData.depthDataMap;
      CVPixelBufferLockBaseAddress(depthBuffer, kCVPixelBufferLock_ReadOnly);
      void *baseAddress = CVPixelBufferGetBaseAddress(depthBuffer);
      size_t dataSize = CVPixelBufferGetDataSize(depthBuffer);
      _depthDataMap = [NSData dataWithBytes:baseAddress length:dataSize];
      _depthWidth = CVPixelBufferGetWidth(depthBuffer);
      _depthHeight = CVPixelBufferGetHeight(depthBuffer);
      CVPixelBufferUnlockBaseAddress(depthBuffer, kCVPixelBufferLock_ReadOnly);
      _depthDataMapValid = YES;
    } else {
      _depthDataMap = nil;
      _depthDataMapValid = NO;
      _depthWidth = 0;
      _depthHeight = 0;
    }
    NSLog(@"[Frame] Allocated: %p, buffer: %p, buffer retain count: %ld", self, buffer, (long)CFGetRetainCount(buffer));
  }
  return self;
}

- (void)incrementRefCount {
  CFRetain(_buffer);
  NSLog(@"[Frame] incrementRefCount: %p, buffer: %p, buffer retain count: %ld", self, _buffer, (long)CFGetRetainCount(_buffer));
}

- (void)decrementRefCount {
  CFRelease(_buffer);
  NSLog(@"[Frame] decrementRefCount: %p, buffer: %p, buffer retain count: %ld", self, _buffer, (long)CFGetRetainCount(_buffer));
}

- (void)dealloc {
  NSLog(@"[Frame] Deallocated: %p, buffer: %p", self, _buffer);
  _depthDataMap = nil;
  _depthDataMapValid = NO;
  _depthWidth = 0;
  _depthHeight = 0;
}

- (CMSampleBufferRef)buffer {
  NSLog(@"[Frame] buffer accessed: %p, buffer: %p, buffer retain count: %ld", self, _buffer, (long)CFGetRetainCount(_buffer));
  if (!self.isValid) {
    @throw [[NSException alloc] initWithName:@"capture/frame-invalid"
                                      reason:@"Trying to access an already closed Frame! "
                                              "Are you trying to access the Image data outside of a Frame Processor's lifetime?\n"
                                              "- If you want to use `console.log(frame)`, use `console.log(frame.toString())` instead.\n"
                                              "- If you want to do async processing, use `runAsync(...)` instead.\n"
                                              "- If you want to use runOnJS, increment it's ref-count: `frame.incrementRefCount()`"
                                    userInfo:nil];
  }
  return _buffer;
}

- (BOOL)isValid {
  return _buffer != nil && CFGetRetainCount(_buffer) > 0 && CMSampleBufferIsValid(_buffer);
}

- (UIImageOrientation)orientation {
  return _orientation;
}

- (NSString*)pixelFormat {
  CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(self.buffer);
  FourCharCode mediaType = CMFormatDescriptionGetMediaSubType(format);
  switch (mediaType) {
    case kCVPixelFormatType_32BGRA:
    case kCVPixelFormatType_Lossy_32BGRA:
      return @"rgb";
    case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
    case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
    case kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
    case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
    case kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarFullRange:
    case kCVPixelFormatType_Lossy_420YpCbCr8BiPlanarVideoRange:
    case kCVPixelFormatType_Lossy_420YpCbCr10PackedBiPlanarVideoRange:
      return @"yuv";
    default:
      return @"unknown";
  }
}

- (BOOL)isMirrored {
  return _isMirrored;
}

- (size_t)width {
  CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(self.buffer);
  return CVPixelBufferGetWidth(imageBuffer);
}

- (size_t)height {
  CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(self.buffer);
  return CVPixelBufferGetHeight(imageBuffer);
}

- (double)timestamp {
  CMTime timestamp = CMSampleBufferGetPresentationTimeStamp(self.buffer);
  return CMTimeGetSeconds(timestamp) * 1000.0;
}

- (size_t)bytesPerRow {
  CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(self.buffer);
  return CVPixelBufferGetBytesPerRow(imageBuffer);
}

- (size_t)planesCount {
  CVPixelBufferRef imageBuffer = CMSampleBufferGetImageBuffer(self.buffer);
  return CVPixelBufferGetPlaneCount(imageBuffer);
}

- (BOOL)hasDepth {
  if (!self.isValid || !_depthDataMapValid) {
    return NO;
  }
  return (_depthDataMap != nil);
}

// Returns a copy of the depth data map, or nil if not available or not valid
- (NSData *)depthDataMap {
  if (!self.isValid || !_depthDataMapValid) {
    return nil;
  }
  return _depthDataMap;
}

// Optionally, add a method to explicitly invalidate the depth map if needed
- (void)invalidateDepthDataMap {
  _depthDataMap = nil;
  _depthDataMapValid = NO;
  // Do NOT reset _depthWidth/_depthHeight here, so metadata is still available after invalidation
}

// Always return dimensions if they were ever set, even if frame is invalid or depth data is released
- (NSDictionary *)depthDims {
  if (_depthWidth == 0 || _depthHeight == 0) {
    NSLog(@"[Frame] depthDims has invalid dimensions: %zu x %zu", _depthWidth, _depthHeight);
    return nil;
  }
  NSLog(@"[Frame] depthDims returning dimensions: %zu x %zu", _depthWidth, _depthHeight);
  return @{
    @"width": @(_depthWidth),
    @"height": @(_depthHeight)
  };
}

@end
