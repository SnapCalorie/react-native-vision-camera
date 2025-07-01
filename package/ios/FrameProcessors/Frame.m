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
  AVDepthData* _Nullable _depth;
}

- (instancetype)initWithBuffer:(CMSampleBufferRef)buffer
                   orientation:(UIImageOrientation)orientation
                    isMirrored:(BOOL)isMirrored
                     depthData:(nullable AVDepthData*)depth {
  self = [super init];
  if (self) {
    _buffer = buffer;
    _orientation = orientation;
    _isMirrored = isMirrored;
    _depth = depth;
    NSLog(@"[Frame] Allocated: %p, buffer: %p, depth: %p, buffer retain count: %ld", self, buffer, depth, (long)CFGetRetainCount(buffer));
    if (_depth) {
      NSLog(@"[Frame] Allocated depth retain count: %p, depth: %p, depth retain count: %ld", self, _depth, (long)CFGetRetainCount((__bridge CFTypeRef)(_depth)));
    }
  }
  return self;
}

- (void)incrementRefCount {
  CFRetain(_buffer);
  if (_depth) {
    CFRetain((__bridge CFTypeRef)(_depth));
    NSLog(@"[Frame] Incremented depth retain count: %p, depth: %p, depth retain count: %ld", self, _depth, (long)CFGetRetainCount((__bridge CFTypeRef)(_depth)));
  }

  NSLog(@"[Frame] incrementRefCount: %p, buffer: %p, buffer retain count: %ld", self, _buffer, (long)CFGetRetainCount(_buffer));
}

- (void)decrementRefCount {
  CFRelease(_buffer);
  if (_depth) {
    CFRelease((__bridge CFTypeRef)(_depth));
    NSLog(@"[Frame] Decremented depth retain count: %p, depth: %p, depth retain count: %ld", self, _depth, (long)CFGetRetainCount((__bridge CFTypeRef)(_depth)));
  }

  NSLog(@"[Frame] decrementRefCount: %p, buffer: %p, buffer retain count: %ld", self, _buffer, (long)CFGetRetainCount(_buffer));
}

- (void)dealloc {
  NSLog(@"[Frame] Deallocated: %p, buffer: %p, depth: %p", self, _buffer, _depth);
  _depth = nil; // Release depth data
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

- (BOOL)depthIsValid {
  if (_depth == nil) return NO;
  return CFGetRetainCount((__bridge CFTypeRef)(_depth)) > 0;
}

- (nullable AVDepthData*)depth {
  NSLog(@"[Frame] depth accessed: %p, depth: %p, depth retain count: %ld", self, _depth, (long)(_depth ? CFGetRetainCount((__bridge CFTypeRef)(_depth)) : 0));
  if (!self.isValid) {
    @throw [[NSException alloc] initWithName:@"capture/depth-invalid"
                                      reason:@"Trying to access an already closed Frame's depth data!\n- If you want to use depth data outside of a Frame Processor's lifetime, use runAsync(...) or incrementRefCount()."
                                    userInfo:nil];
  }
  if (_depth && ![self depthIsValid]) {
    @throw [[NSException alloc] initWithName:@"capture/depth-invalid"
                                      reason:@"Trying to access an already released depth data object!\n- If you want to use depth data outside of a Frame Processor's lifetime, use runAsync(...) or incrementRefCount()."
                                    userInfo:nil];
  }
  return _depth;
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

@end
