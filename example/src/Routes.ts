export type Routes = {
  PermissionsPage: undefined
  CameraPage: undefined
  CodeScannerPage: undefined
  MediaPage: {
    path: string
    type: 'video' | 'photo'
    depthPath?: string
    depthDims?: { width: number; height: number }
  }
  Devices: undefined
}
