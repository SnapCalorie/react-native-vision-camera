import { AlphaType, ColorType, Skia } from '@shopify/react-native-skia'
import { Buffer } from 'buffer'
import { Platform } from 'react-native'
import RNFS from 'react-native-fs'

/**
 * Define the jet color map for depth images.
 *  Code adapted from Matplotlib
 */
const jetData = {
  red: [
    { pos: 0.0, val: 0 },
    { pos: 0.35, val: 0 },
    { pos: 0.66, val: 1 },
    { pos: 0.89, val: 1 },
    { pos: 1.0, val: 0.5 },
  ],
  green: [
    { pos: 0.0, val: 0 },
    { pos: 0.125, val: 0 },
    { pos: 0.375, val: 1 },
    { pos: 0.64, val: 1 },
    { pos: 0.91, val: 0 },
    { pos: 1.0, val: 0 },
  ],
  blue: [
    { pos: 0.0, val: 0.5 },
    { pos: 0.11, val: 1 },
    { pos: 0.34, val: 1 },
    { pos: 0.65, val: 0 },
    { pos: 1.0, val: 0 },
  ],
}

/**
 * Interpolate a color value for a given position.
 */
export const interpolateColor = (data: { pos: number; val: number }[], x: number): number => {
  for (let i = 1; i < data.length; i += 1) {
    if (x <= data[i].pos) {
      const x0 = data[i - 1].pos
      const y0 = data[i - 1].val
      const x1 = data[i].pos
      const y1 = data[i].val
      const t = (x - x0) / (x1 - x0)
      const c = y0 + t * (y1 - y0)
      return Math.floor(c * 255)
    }
  }
  return data[data.length - 1].val * 255 // If x is outside the range
}

/**
 * Get the jet color for a given value.
 */
export const getJetRGBForValue = (value: number): [number, number, number] => {
  const red = interpolateColor(jetData.red, value)
  const green = interpolateColor(jetData.green, value)
  const blue = interpolateColor(jetData.blue, value)
  return [red, green, blue]
}

/**
 * Convert a binary array buffer that encodes 32-bit floats to a 2D matrix.
 */
export const convertF32BinToMatrix = (binData: ArrayBuffer, outDims: [number, number]): number[][] => {
  const view = new DataView(binData)
  const numFloats = binData.byteLength / 4
  const imgFlt: number[] = new Array<number>(numFloats)

  for (let i = 0; i < numFloats; i += 1) imgFlt[i] = view.getFloat32(i * 4, true)

  const [rows, cols] = outDims
  if (imgFlt.length !== rows * cols) throw new Error('The provided dimensions do not match the data length.')

  const matrix: number[][] = []
  for (let i = 0; i < rows; i += 1) matrix.push(imgFlt.slice(i * cols, (i + 1) * cols))

  return matrix
}

/**
 * Read a base64 encoded binary file from a local URI and convert it to a floating point array.
 */
export const base64DepthBin2Matrix = async (b64Uri: string, nRows: number, nCols: number) => {
  const b64Data = await getBase64FromUri(b64Uri)
  if (b64Data !== null) {
    const buffer = Buffer.from(b64Data, 'base64')
    // Convert the binary data to a 2D matrix
    const matrix = convertF32BinToMatrix(buffer.buffer, [nRows, nCols])
    return new Float32Array(matrix.flat())
  }
  return null
}

/**
 * Given a depth array, render a depth image using the jet color map with the Skia library.
 * If the depth array appears to be duplicated vertically (i.e., length is 2 * nRows * nCols),
 * only use the top half for rendering.
 */
export const renderDepthMatrix = (
  depthArray: Float32Array,
  nRows: number,
  nCols: number,
  upperPercentile = 0.1,
  lowerPercentile = 0.9,
): ReturnType<typeof Skia.Image.MakeImage> | null => {
  // If the depth array is duplicated vertically, slice to use only the top half
  let inputArray = depthArray
  if (depthArray.length === 2 * nRows * nCols) inputArray = depthArray.slice(0, nRows * nCols)

  const outWidth = nCols
  const outHeight = nRows
  const pixels = new Uint8Array(outWidth * outHeight * 4)
  pixels.fill(255)

  // Find upper and lower percentile values
  const sorted = Array.from(inputArray).sort((a, b) => a - b)
  const lower = sorted[Math.floor(sorted.length * upperPercentile)] ?? 0
  const upper = sorted[Math.floor(sorted.length * lowerPercentile)] ?? 1

  for (let row = 0; row < nRows; row++) {
    for (let col = 0; col < nCols; col++) {
      const srcIdx = row * nCols + col
      const dstIdx = row * nCols + col
      const depth = inputArray[srcIdx] ?? 0
      const norm = Math.max(0, Math.min(1, (depth - lower) / (upper - lower)))
      const jetRgb = getJetRGBForValue(norm)
      const pixelIdx = dstIdx * 4
      pixels[pixelIdx] = jetRgb[0]
      pixels[pixelIdx + 1] = jetRgb[1]
      pixels[pixelIdx + 2] = jetRgb[2]
      pixels[pixelIdx + 3] = 255
    }
  }

  const data = Skia.Data.fromBytes(pixels)
  const img = Skia.Image.MakeImage(
    {
      width: outWidth,
      height: outHeight,
      alphaType: AlphaType.Opaque,
      colorType: ColorType.RGBA_8888,
    },
    data,
    outWidth * 4, // rowBytes = width * 4
  )

  return img ?? null
}

/**
 * Convert HSV color representation to RGB
 */
export const hsvToRgb = (h: number, s: number, v: number): [number, number, number] => {
  let r = 0
  let g = 0
  let b = 0

  const i = Math.floor(h * 6)
  const f = h * 6 - i
  const p = v * (1 - s)
  const q = v * (1 - f * s)
  const t = v * (1 - (1 - f) * s)

  switch (i % 6) {
    case 0:
      r = v
      g = t
      b = p
      break
    case 1:
      r = q
      g = v
      b = p
      break
    case 2:
      r = p
      g = v
      b = t
      break
    case 3:
      r = p
      g = q
      b = v
      break
    case 4:
      r = t
      g = p
      b = v
      break
    case 5:
      r = v
      g = p
      b = q
      break
    default:
      break
  }

  return [r * 255, g * 255, b * 255]
}
/**
 * Reads a base64 string from a file URI.
 * Supports both Expo and React Native FS APIs.
 */
async function getBase64FromUri(b64Uri: string): Promise<string | null> {
  try {
    // If the URI is already a base64 string, just return the data part
    if (b64Uri.startsWith('data:')) {
      const base64 = b64Uri.split(',')[1]
      return base64 ?? null
    }

    // If not using Expo, try React Native FS (if available)
    if (Platform.OS !== 'web') {
      // Dynamically require to avoid breaking web builds
      const base64 = await RNFS.readFile(b64Uri, 'base64')
      return base64
    }

    return null
  } catch (e) {
    console.warn('Failed to read base64 from URI:', e)
    return null
  }
}
