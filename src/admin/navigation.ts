import type { AdminLeg, AdminMark } from './types'

const earthRadiusNm = 3440.065

function radians(value: number) { return value * Math.PI / 180 }
function degrees(value: number) { return value * 180 / Math.PI }

export function distanceNm(from: AdminMark, to: AdminMark): number {
  const lat1 = radians(from.latitude)
  const lat2 = radians(to.latitude)
  const deltaLat = lat2 - lat1
  const deltaLon = radians(to.longitude - from.longitude)
  const a = Math.sin(deltaLat / 2) ** 2 + Math.cos(lat1) * Math.cos(lat2) * Math.sin(deltaLon / 2) ** 2
  return earthRadiusNm * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a))
}

export function bearingTrue(from: AdminMark, to: AdminMark): number {
  const fromLat = radians(from.latitude)
  const toLat = radians(to.latitude)
  const deltaLon = radians(to.longitude - from.longitude)
  const y = Math.sin(deltaLon) * Math.cos(toLat)
  const x = Math.cos(fromLat) * Math.sin(toLat) - Math.sin(fromLat) * Math.cos(toLat) * Math.cos(deltaLon)
  return (degrees(Math.atan2(y, x)) + 360) % 360
}

export function recalculateLegs(legs: AdminLeg[], marks: AdminMark[]) {
  let totalDistanceNm = 0
  const recalculated = legs.map((leg, index) => {
    if (index === 0) return leg
    const previous = marks.find((mark) => mark.id === legs[index - 1].markId)
    const current = marks.find((mark) => mark.id === leg.markId)
    if (!previous || !current) return { ...leg, bearing: '', distance: '' }
    const distance = distanceNm(previous, current)
    totalDistanceNm += distance
    return { ...leg, bearing: `${Math.round(bearingTrue(previous, current)).toString().padStart(3, '0')}° T`, distance: `${distance.toFixed(2)} nm` }
  })
  return { legs: recalculated, totalDistanceNm }
}
