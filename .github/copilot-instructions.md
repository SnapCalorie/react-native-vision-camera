# Copilot Instructions for react-native-vision-camera

## Project Overview
This project is a high-performance, cross-platform React Native camera library called **react-native-vision-camera**. It provides advanced camera features for React Native apps, including real-time frame processing, depth data, and support for both Android and iOS platforms.

## Key Directories and Files
- **package/**: The main library source code, including platform-specific code for Android (`android/`) and iOS (`ios/`).
- **example/**: Example React Native app for testing and development.
- **docs/**: Documentation site (Docusaurus).
- **python/**: Contains Jupyter notebooks for debugging or prototyping.

## Notable Features
- **Frame Processors**: Real-time frame processing plugins, with native code in both Android (Kotlin/C++) and iOS (Swift/Obj-C++).
- **Depth Data**: Support for capturing and saving depth data (see iOS `PhotoCaptureDelegate.swift`).
- **Expo Plugin**: Custom Expo config plugin for permissions and native setup.
- **Highly Configurable**: Many camera options (HDR, FPS, flash, night mode, etc.) are exposed to the JS/TS API.

## Platform-Specific Details
### iOS
- Native code in Swift, Objective-C, and Objective-C++.
- Frame processors and depth data handling in `ios/FrameProcessors/` and `ios/Core/`.
- Podspec (`VisionCamera.podspec`) controls subspecs for frame processors.
- Example workspace: `example/ios/VisionCameraExample.xcworkspace`.

### Android
- Native code in Kotlin and C++.
- Frame processor integration in `android/src/main/cpp/frameprocessors/` and `android/src/main/java/com/mrousavy/camera/react/`.
- Uses CMake for native code and Gradle for build configuration.

## Development & Linting
- Run `yarn check-ios` or `yarn check-android` for platform-specific linting and formatting.
- Run `yarn check-all` to lint/format all code (JS, iOS, Android, C++).
- Example app can be started from the `example/` directory.

## Useful Scripts
- `bootstrap`: Installs all dependencies and sets up pods.
- `check-ios`, `check-android`, `check-js`, `check-cpp`: Lint/format for each platform/language.
- `clean-ios`, `clean-android`, `clean-js`: Clean build artifacts.

## Permissions
- Camera, microphone, and location permissions are handled via the Expo config plugin and native code.

## Frame Processor Plugins
- iOS: Register plugins using `VISION_EXPORT_FRAME_PROCESSOR` or `VISION_EXPORT_SWIFT_FRAME_PROCESSOR` macros.
- Android: Frame processor plugins are implemented in C++/JNI and registered via the native bridge.

## Example Usage
- See `example/src/CameraPage.tsx` for a comprehensive example of camera usage, including frame processors and depth data handling.

## Additional Notes
- The project supports both the old and new React Native architectures (see Gradle and CMake configs).
- Depth data is saved as a separate `.depth.bin` file on iOS if available.
- The codebase is modular and designed for extensibility, especially for custom frame processors.

---
This file is intended for Copilot and other AI assistants to provide context and guidance for future code generation and support requests in this repository.
