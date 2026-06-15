export const MAGNETIC_VARIATION_DEGREES: number | null = null

const EARTH_RADIUS_NM = 3440.065

function toRadians(degrees: number) {
  return (degrees * Math.PI) / 180
}

function toDegrees(radians: number) {
  return (radians * 180) / Math.PI
}

export function normalizeDegrees(value: number) {
  return ((value % 360) + 360) % 360
}

export function calculateBearingTrue(
  fromLat: number,
  fromLon: number,
  toLat: number,
  toLon: number,
) {
  const fromLatRad = toRadians(fromLat)
  const toLatRad = toRadians(toLat)
  const deltaLonRad = toRadians(toLon - fromLon)
  const y = Math.sin(deltaLonRad) * Math.cos(toLatRad)
  const x =
    Math.cos(fromLatRad) * Math.sin(toLatRad) -
    Math.sin(fromLatRad) * Math.cos(toLatRad) * Math.cos(deltaLonRad)

  return normalizeDegrees(toDegrees(Math.atan2(y, x)))
}

export function calculateDistanceNm(
  fromLat: number,
  fromLon: number,
  toLat: number,
  toLon: number,
) {
  const deltaLat = toRadians(toLat - fromLat)
  const deltaLon = toRadians(toLon - fromLon)
  const fromLatRad = toRadians(fromLat)
  const toLatRad = toRadians(toLat)
  const a =
    Math.sin(deltaLat / 2) ** 2 +
    Math.cos(fromLatRad) * Math.cos(toLatRad) * Math.sin(deltaLon / 2) ** 2
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))

  return EARTH_RADIUS_NM * c
}

export function applyMagneticVariation(trueBearing: number, variationDegrees: number) {
  return normalizeDegrees(trueBearing - variationDegrees)
}

export function formatBearing(value: number) {
  return `${Math.round(normalizeDegrees(value)).toString().padStart(3, '0')}°`
}

export function formatDistanceNm(value: number) {
  if (value < 1) {
    return `${value.toFixed(2)} nm`
  }

  return `${value.toFixed(1)} nm`
}
