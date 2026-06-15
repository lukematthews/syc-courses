import { useCallback, useState } from 'react'

export type CurrentPositionState = {
  position: GeolocationPosition | null
  status: 'idle' | 'loading' | 'success' | 'error'
  errorMessage: string
}

function getGeolocationErrorMessage(error: GeolocationPositionError) {
  if (error.code === error.PERMISSION_DENIED) {
    return 'GPS permission denied.'
  }
  if (error.code === error.POSITION_UNAVAILABLE) {
    return 'Location unavailable.'
  }
  if (error.code === error.TIMEOUT) {
    return 'GPS timed out. Try refresh.'
  }

  return error.message || 'Could not get location.'
}

export function useCurrentPosition() {
  const [state, setState] = useState<CurrentPositionState>({
    position: null,
    status: 'idle',
    errorMessage: '',
  })

  const requestPosition = useCallback(() => {
    if (!('geolocation' in navigator)) {
      setState({
        position: null,
        status: 'error',
        errorMessage: 'GPS is not supported in this browser.',
      })
      return
    }

    setState((current) => ({ ...current, status: 'loading', errorMessage: '' }))

    navigator.geolocation.getCurrentPosition(
      (position) => {
        setState({ position, status: 'success', errorMessage: '' })
      },
      (error) => {
        setState((current) => ({
          position: current.position,
          status: 'error',
          errorMessage: getGeolocationErrorMessage(error),
        }))
      },
      {
        enableHighAccuracy: true,
        maximumAge: 5000,
        timeout: 12000,
      },
    )
  }, [])

  return { ...state, requestPosition }
}
