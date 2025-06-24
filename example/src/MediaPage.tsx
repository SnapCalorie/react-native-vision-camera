import React, { useCallback, useMemo, useState } from 'react'
import type { ImageLoadEventData, NativeSyntheticEvent } from 'react-native'
import { StyleSheet, View, ActivityIndicator, PermissionsAndroid, Platform, Image, Text } from 'react-native'
import type { OnVideoErrorData, OnLoadData } from 'react-native-video'
import Video from 'react-native-video'
import { SAFE_AREA_PADDING } from './Constants'
import { useIsForeground } from './hooks/useIsForeground'
import { PressableOpacity } from 'react-native-pressable-opacity'
import IonIcon from 'react-native-vector-icons/Ionicons'
import { Alert } from 'react-native'
import { CameraRoll } from '@react-native-camera-roll/camera-roll'
import { StatusBarBlurBackground } from './views/StatusBarBlurBackground'
import type { NativeStackScreenProps } from '@react-navigation/native-stack'
import type { Routes } from './Routes'
import { useIsFocused } from '@react-navigation/core'
import Share from 'react-native-share'
import { renderDepthMatrix, base64DepthBin2Matrix } from './depthUtils'
import type { SkImage } from '@shopify/react-native-skia'
import { Canvas, Image as SkiaImage } from '@shopify/react-native-skia'

const requestSavePermission = async (): Promise<boolean> => {
  // On Android 13 and above, scoped storage is used instead and no permission is needed
  if (Platform.OS !== 'android' || Platform.Version >= 33) return true

  const permission = PermissionsAndroid.PERMISSIONS.WRITE_EXTERNAL_STORAGE
  if (permission == null) return false
  let hasPermission = await PermissionsAndroid.check(permission)
  if (!hasPermission) {
    const permissionRequestResult = await PermissionsAndroid.request(permission)
    hasPermission = permissionRequestResult === 'granted'
  }
  return hasPermission
}

type OnLoadImage = NativeSyntheticEvent<ImageLoadEventData>
const isVideoOnLoadEvent = (event: OnLoadData | OnLoadImage): event is OnLoadData => 'duration' in event && 'naturalSize' in event

type Props = NativeStackScreenProps<Routes, 'MediaPage'>
export function MediaPage({ navigation, route }: Props): React.ReactElement {
  const { path, type, depthPath, depthDims } = route.params
  const [hasMediaLoaded, setHasMediaLoaded] = useState(false)
  const isForeground = useIsForeground()
  const isScreenFocused = useIsFocused()
  const isVideoPaused = !isForeground || !isScreenFocused
  const [savingState, setSavingState] = useState<'none' | 'saving' | 'saved'>('none')
  const [depthSavingState, setDepthSavingState] = useState<'none' | 'saving' | 'saved'>('none')
  const [showDepth, setShowDepth] = useState(false)
  const [depthImage, setDepthImage] = useState<SkImage | null>(null)
  const [depthError, setDepthError] = useState<string | null>(null)

  // Load and render depth image when toggled
  React.useEffect(() => {
    let cancelled = false
    const loadDepth = async (): Promise<void> => {
      setDepthError(null)
      if (
        showDepth &&
        depthPath != null &&
        depthDims != null &&
        typeof depthDims.width === 'number' &&
        depthDims.width > 0 &&
        typeof depthDims.height === 'number' &&
        depthDims.height > 0
      ) {
        try {
          const nRows = depthDims.height
          const nCols = depthDims.width
          const depthArray = await base64DepthBin2Matrix(depthPath, nRows, nCols)
          if (!cancelled && depthArray != null) {
            const img = renderDepthMatrix(depthArray, nRows, nCols)
            setDepthImage(img)
          } else if (!cancelled) {
            setDepthImage(null)
            setDepthError('Failed to decode depth data.')
          }
        } catch (e) {
          if (!cancelled) {
            setDepthImage(null)
            setDepthError(e instanceof Error ? e.message : 'Unknown error')
          }
        }
      } else {
        setDepthImage(null)
      }
    }
    loadDepth()
    return () => {
      cancelled = true
    }
  }, [showDepth, depthPath, depthDims])

  const onMediaLoad = useCallback((event: OnLoadData | OnLoadImage) => {
    if (isVideoOnLoadEvent(event)) {
      console.log(
        `Video loaded. Size: ${event.naturalSize.width}x${event.naturalSize.height} (${event.naturalSize.orientation}, ${event.duration} seconds)`,
      )
    } else {
      const source = event.nativeEvent.source
      console.log(`Image loaded. Size: ${source.width}x${source.height}`)
    }
  }, [])
  const onMediaLoadEnd = useCallback(() => {
    console.log('media has loaded.')
    setHasMediaLoaded(true)
  }, [])
  const onMediaLoadError = useCallback((error: OnVideoErrorData) => {
    console.error(`failed to load media: ${JSON.stringify(error)}`)
  }, [])

  const onSavePressed = useCallback(async () => {
    try {
      setSavingState('saving')

      const hasPermission = await requestSavePermission()
      if (!hasPermission) {
        Alert.alert('Permission denied!', 'Vision Camera does not have permission to save the media to your camera roll.')
        return
      }
      await CameraRoll.save(`file://${path}`, {
        type: type,
      })
      setSavingState('saved')
    } catch (e) {
      const message = e instanceof Error ? e.message : JSON.stringify(e)
      setSavingState('none')
      Alert.alert('Failed to save!', `An unexpected error occured while trying to save your ${type}. ${message}`)
    }
  }, [path, type])

  const onSaveDepthPressed = useCallback(async () => {
    if (depthPath == null) return
    try {
      setDepthSavingState('saving')
      await Share.open({
        url: depthPath,
        type: 'application/octet-stream',
        failOnCancel: false,
        showAppsToView: true,
        title: 'Share Depth File',
      })
      setDepthSavingState('saved')
    } catch (e) {
      setDepthSavingState('none')
      const message = e instanceof Error ? e.message : JSON.stringify(e)
      Alert.alert('Failed to share depth!', `An unexpected error occurred while trying to share the depth file. ${message}`)
    }
  }, [depthPath])

  const source = useMemo(() => ({ uri: `file://${path}` }), [path])

  const screenStyle = useMemo(() => ({ opacity: hasMediaLoaded ? 1 : 0 }), [hasMediaLoaded])

  return (
    <View style={[styles.container, screenStyle]}>
      {type === 'photo' && (
        <Image source={source} style={StyleSheet.absoluteFill} resizeMode="cover" onLoadEnd={onMediaLoadEnd} onLoad={onMediaLoad} />
      )}
      {type === 'video' && (
        <Video
          source={source}
          style={StyleSheet.absoluteFill}
          paused={isVideoPaused}
          resizeMode="cover"
          posterResizeMode="cover"
          allowsExternalPlayback={false}
          automaticallyWaitsToMinimizeStalling={false}
          disableFocus={true}
          repeat={true}
          useTextureView={false}
          controls={false}
          playWhenInactive={true}
          ignoreSilentSwitch="ignore"
          onReadyForDisplay={onMediaLoadEnd}
          onLoad={onMediaLoad}
          onError={onMediaLoadError}
        />
      )}

      <PressableOpacity style={styles.closeButton} onPress={navigation.goBack}>
        <IonIcon name="close" size={35} color="white" style={styles.icon} />
      </PressableOpacity>

      <PressableOpacity style={styles.saveButton} onPress={onSavePressed} disabled={savingState !== 'none'}>
        {savingState === 'none' && <IonIcon name="download" size={35} color="white" style={styles.icon} />}
        {savingState === 'saved' && <IonIcon name="checkmark" size={35} color="white" style={styles.icon} />}
        {savingState === 'saving' && <ActivityIndicator color="white" />}
      </PressableOpacity>
      {type === 'photo' && depthPath != null && (
        <>
          <PressableOpacity
            style={[styles.saveButton, { left: SAFE_AREA_PADDING.paddingLeft + 50 }]}
            onPress={onSaveDepthPressed}
            disabled={depthSavingState !== 'none'}>
            {depthSavingState === 'none' && <IonIcon name="download" size={35} color="#00eaff" style={styles.icon} />}
            {depthSavingState === 'saved' && <IonIcon name="checkmark" size={35} color="#00eaff" style={styles.icon} />}
            {depthSavingState === 'saving' && <ActivityIndicator color="#00eaff" />}
          </PressableOpacity>
          <PressableOpacity
            style={[styles.saveButton, { left: SAFE_AREA_PADDING.paddingLeft + 100 }]}
            onPress={() => setShowDepth((v) => !v)}>
            <IonIcon name={showDepth ? 'eye-off' : 'eye'} size={35} color="#00eaff" style={styles.icon} />
          </PressableOpacity>
        </>
      )}
      {showDepth && (
        <View style={styles.depthPreviewContainer}>
          {depthImage != null && depthDims != null ? (
            (() => {
              const aspect = depthDims.width / depthDims.height
              const maxWidth = 300
              const maxHeight = 200
              let width = maxWidth
              let height = Math.round(maxWidth / aspect)
              if (height > maxHeight) {
                height = maxHeight
                width = Math.round(maxHeight * aspect)
              }
              return (
                <Canvas style={{ width, height, borderRadius: 8, borderWidth: 2, borderColor: '#00eaff', backgroundColor: '#222' }}>
                  <SkiaImage image={depthImage} x={0} y={0} width={width} height={height} fit="contain" />
                </Canvas>
              )
            })()
          ) : depthError != null ? (
            <View style={styles.depthPreviewError}>
              <IonIcon name="alert-circle" size={30} color="#ff5555" />
              <>
                <Text style={styles.depthPreviewErrorText}>{depthError}</Text>
              </>
            </View>
          ) : (
            <View style={styles.depthPreviewLoading}>
              <ActivityIndicator color="#00eaff" />
            </View>
          )}
        </View>
      )}

      <StatusBarBlurBackground />
    </View>
  )
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'white',
  },
  closeButton: {
    position: 'absolute',
    top: SAFE_AREA_PADDING.paddingTop,
    left: SAFE_AREA_PADDING.paddingLeft,
    width: 40,
    height: 40,
  },
  saveButton: {
    position: 'absolute',
    bottom: SAFE_AREA_PADDING.paddingBottom,
    left: SAFE_AREA_PADDING.paddingLeft,
    width: 40,
    height: 40,
  },
  icon: {
    textShadowColor: 'black',
    textShadowOffset: {
      height: 0,
      width: 0,
    },
    textShadowRadius: 1,
  },
  depthPreviewContainer: {
    position: 'absolute',
    top: 80,
    left: 0,
    right: 0,
    alignItems: 'center',
    zIndex: 20,
  },
  depthPreview: {
    width: 300,
    height: 200,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#00eaff',
    backgroundColor: '#222',
  },
  depthPreviewError: {
    width: 300,
    height: 200,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#00eaff',
    backgroundColor: '#222',
    justifyContent: 'center',
    alignItems: 'center',
  },
  depthPreviewErrorText: {
    color: '#fff',
    marginTop: 8,
    textAlign: 'center',
  },
  depthPreviewLoading: {
    width: 300,
    height: 200,
    borderRadius: 8,
    borderWidth: 2,
    borderColor: '#00eaff',
    backgroundColor: '#222',
    justifyContent: 'center',
    alignItems: 'center',
  },
})
