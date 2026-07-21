import { mkdirSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

const root = process.cwd()
const output = join(root, 'course-packs/bys-2025-2026')
mkdirSync(output, { recursive: true })

const fixed = [
  [1,'KBC - Club front (N, S, NW, SE)','8 nm',8,'BYS4 - BYS2 - BYS3 - BYS2 - BYS3 - BYS2 - BYS3 - BYS1(S)'],
  [2,'KBC - Club front (N, S, NW, SE)','7.8 nm',8,'BYS4 - BYS2 - BYS3(S) - BYS2(S) - BYS3(S) - BYS2(S) - BYS1(S)'],
  [3,'KBC - Club front (N, S, NW, SE)','6.9 nm',8,'BYS4 - BYS3(S) - BYS2(S) - BYS4(S) - BYS2(S) - BYS1(S)'],
  [4,'KBC - Club front (N, S, NW, SE)','8.9 nm',8,'BYS4* - So.10* - So.12* - BYS6(S) - BYS5(S) - BYS6(S) - BYS5(S) - BYS6(S) - BYS5(S) - So.10(S)* - BYS1(S)'],
  [5,'KBC - Capel Sound (N, S, SW)','7.1 nm',8,'BYS4 - So.10* - BYS5 - BYS6 - BYS5 - BYS6 - So.12(S)* - So.10(S)* - BYS1(S)'],
  [6,'KBC - Capel Sound (N, S, SW, NE)','8.4 nm',8,'BYS4* - So.10* - So.12* - BYS6(S) - SCh.13(S) - BYS5(S) - So.10(S)* - BYS1(S)'],
  [7,'KBC - Capel Sound (N, S, SW, SE)','7.1 nm',8,'BYS4* - So.10* - So.12* - BYS6(S) - BYS5(S) - BYS6(S) - BYS5(S) - So.10(S)* - BYS1(S)'],
  [8,'KBC - Capel Sound (E, W)','7.6 nm',8,'BYS4* - So.10* - BYS5 - So.10(S)* - BYS4 - So.10 - BYS5 - So.10(S)* - BYS4 - BYS1(S)'],
  [9,'KBC - Capel Sound (N, S, SW, NE)','7.2 nm',8,'BYS4* - So.10* - BYS5 - BYS6 - BYS5 - BYS6 - So.12(S)* - So.10(S)* - BYS1(S)'],
  [45,'KBC - Capel Sound (EW, NW, SW, NE)','8.8 nm',8,'BYS4* - So.10* - So.12* - BYS6(S) - CS laid mark(S) - BYS5(S) - BYS6 - So.12(S)* - So.10(S)* - BYS1(S)'],
  [46,'KBC - Capel Sound (EW, NW, SW, NE)','12.1 nm',8,'BYS4* - So.10* - BYS5 - CS laid mark - BYS6 - So.12(S)* - So.10(S)* - BYS4 - BYS5 - BYS6 - So.12(S)* - So.10(S)* - BYS1(S)'],
  [12,'Division A - N, S, NW, SE','10.2 nm',9,'BYS4 - BYS2 - BYS3 - BYS2 - BYS3 - BYS2 - BYS3 - BYS2 - BYS3 - BYS1(S)','div-a'],
  [12,'Division B - N, S, NW, SE','8 nm',9,'BYS4 - BYS2 - BYS3 - BYS2 - BYS3 - BYS2 - BYS3 - BYS1(S)','div-b'],
  [13,'Division A - N, S, NW, SE','9.8 nm',9,'BYS4 - BYS3(S) - BYS2(S) - BYS4(S) - BYS2(S) - BYS4(S) - BYS2(S) - BYS4(S) - BYS2(S) - BYS1(S)','div-a'],
  [13,'Division B - N, S, NW, SE','7.6 nm',9,'BYS4 - BYS3(S) - BYS2(S) - BYS4(S) - BYS2(S) - BYS4(S) - BYS2(S) - BYS1(S)','div-b'],
  [14,'Division A - N, S','10.8 nm',9,'BYS4 - BYS2(S) - SCh.7(S) - BYS2(S)* - BYS3(S) - BYS2(S) - BYS3(S) - BYS2(S) - BYS3(S) - BYS2(S) - BYS1(S)','div-a'],
  [14,'Division B - N, S','6.4 nm',9,'BYS4 - BYS2(S) - SCh.7(S) - BYS2(S) - BYS3(S) - BYS2(S) - BYS1(S)','div-b'],
  [15,'Division A - N, S, SW, NE','9.8 nm',9,'BYS4* - So.10* - So.12* - BYS6(S) - BYS5(S) - BYS6(S) - BYS5(S) - BYS6(S) - BYS5(S) - So.10(S)* - BYS1(S)','div-a'],
  [15,'Division B - N, S, SW, NE','7.6 nm',9,'BYS4* - So.10* - So.12* - BYS6(S) - BYS5(S) - BYS6(S) - BYS5(S) - So.10(S)* - BYS1(S)','div-b'],
  [16,'Division A - E, W','12 nm',9,'BYS4* - So.10* - BYS5 - So.10(S)* - BYS4 - So.10* - BYS5 - So.10(S)* - BYS3 - So.10* - BYS5 - So.10(S)* - BYS3 - BYS4(S) - BYS1(S)','div-a'],
  [16,'Division B - E, W','6.8 nm',9,'BYS4* - So.10* - BYS5 - So.10(S)* - BYS4 - So.10* - BYS5 - So.10(S)* - BYS4(S)* - BYS1(S)','div-b'],
  [17,'Division A - N, S, SW, NE','8.2 nm',9,'BYS4* - So.10* - BYS5 - BYS6 - BYS5 - BYS6 - BYS5 - BYS6 - So.12(S)* - So.10(S)* - BYS1(S)','div-a'],
  [17,'Division B - N, S, SW, NE','6.8 nm',9,'BYS4* - So.10* - BYS5 - So.10(S)* - BYS4 - So.10* - BYS5 - So.10(S)* - BYS4(S)* - BYS1(S)','div-b'],
  [18,'Division A - N, S','8.6 nm',9,'BYS4 - BYS2(S) - SCh.7(S) - BYS2(S)* - BYS3 - BYS2(S) - BYS3 - BYS2(S) - BYS1(S)','div-a'],
  [18,'Division B - N, S','5.2 nm',9,'BYS4 - BYS2(S) - SCh.7(S) - BYS3 - BYS1(S)','div-b'],
  [19,'KBC Spry - E, W','32.2 nm',11,'BYS3(S) - BYS2(S) - SCh.7(P) - SCh.1(P)¥ - SCh.7(S) - BYS2(P)* - BYS3(P) - So.10(P)* - BYS5(P) - SCh.13(P)¥ - BYS5(P) - SCh.11(P)¥ - BYS5(P) - BYS6(P) - So.12(S)* - So.10(S)* - BYS4(P)* - BYS3(S) - BYS2(S) - BYS4(P) - BYS5(P) - So.10(S)* - BYS1(S)'],
  [20,'KBC Spry - E, W','29.3 nm',11,'So.10(P)* - So.12(P)* - SCh.Light(S) - BYS6(P) - SCh.13(S)¥ - BYS5(S) - SCh.13(S)¥ - BYS5(S) - So.10(S)* - BYS4(S) - BYS2(S) - SCh.7(P) - SCh.1(P)¥ - So.1(S) - So.2(P)* - So.4(P)* - So.6(P)* - So.8(P)* - So.3(S) - BYS3(P) - BYS4(S) - So.10(P)* - BYS5(S) - So.10(S)* - BYS1(S)'],
  [21,'John Medley Trophy - to Queenscliff','7.8 nm',11,'BYS3(S) - So.3(P) - So.8(S)* - So.6(S)* - So.4(S)* - So.2(S)* - PpeEyeLght(S)¥ - Cut Outer Pile - Finish at southern end of QCYC'],
  [22,'William Buckley Trophy - from Queenscliff','7.8 nm',11,'Start at QCYC - Cut Outer Pile - PpeEyeLght(P)¥ - So.2(P)* - So.4(P)* - So.6(P)* - So.8(P)* - So.3(S) - BYS3(P) - BYS0(S)* - BYS1(S)'],
  [23,'Ross Crow - around the sands anti-clockwise','41.2 nm',11,'So.10(P)* - SCh.19(P)¥ - SCh.21(P)* - R1(P)¥ - BYB(P)*¥ - WCh.Pile(P)¥ - WCh.7(P)* - WCh.6(S)* - WCh.5(P)* - WCh.3(P)* - WCh.1(P)¥ - So.1(S) - So.2(P)*¥ - So.4(P)* - So.6(P)* - So.8(P)* - So.3(S) - BYS3(P) - BYS2(S) - BYS4(P) - So.10(P)* - So.12(P)* - BYS6(S) - BYS5(S) - So.10(S)* - BYS1(S)'],
  [24,'Ross Crow - around the sands anti-clockwise','35.1 nm',11,'So.10(P)* - SCh.19(P)¥ - HovPile(P)* - BYB(P) - SymCh.Pile(S) - WCh.Pile(P)¥ - WCh.7(P) - WCh.6(S)* - WCh.5(P)* - WCh.3(P)* - WCh.1(P)¥ - So.1(S) - So.2(P)*¥ - So.4(P)* - So.6(P)* - So.8(P)* - So.3(S) - BYS3(P) - BYS4(P) - BYS5(P) - So.10(S)* - BYS1(S)'],
  [25,'Ross Crow - around the sands clockwise','37.7 nm',11,'BYS3(S) - So.3(P) - So.8(S)* - So.6(S)* - So.4(S)* - So.2(S)* - So.1(P) - SCh.2(S) - WCh.1(S)¥ - WCh.3(S)* - WCh.2(P)* - WCh.5(S)* - WCh.6(P)* - WCh.7(S)* - WCh.Pile(S)¥ - BYB(S)¥ - R1(S)¥ - SCh.21(S) - SCh.19(S)¥ - So.10(S)* - BYS3(S) - BYS2(S) - BYS4(S) - BYS1(S)'],
  [26,'Ross Crow - around the sands clockwise','33.4 nm',12,'BYS3(S) - So.3(P) - So.8(S)* - So.6(S)* - So.4(S)* - So.2(S)* - So.1(P) - SCh.2(S) - WCh.1(S)¥ - WCh.3(S)* - WCh.2(P)* - WCh.5(S)* - WCh.6(P) - WCh.7(S)* - WCh.Pile(S)¥ - SymCh.Pile(P) - BYB(S) - HovPile(S)* - SCh.19(S)¥ - So.10(S)* - BYS4(S) - BYS3(S) - BYS2(S) - BYS1(S)'],
  [27,'Pinto Long - east','59.7 nm',12,'So.10(P)* - BYS5(P) - SCh.19(P)¥ - SCh.21(P) - AquaCult3(S) - AquaCult1(S) - AquaCult2(S) - BYB(S)¥ - MMFNW(S) - MMFNE(S) - MMFSE(S) - R1(S)¥ - SCh.21(S) - R1(S) - SCh.21(S)¥ - BYS6(P) - BYS5(S) - So.10(S)* - BYS4(P) - BYS3(S) - BYS2(S) - BYS4(P) - BYS5(P) - BYS6(P) - So.12(S)* - So.10(S)* - BYS4(P) - BYS3(S) - BYS2(S) - BYS1(S)'],
  [28,'Pinto Short - east','48.6 nm',12,'So.10(P)* - BYS5(P) - SCh.19(P)¥ - SCh.21(P) - AquaCult3(S) - AquaCult1(S) - AquaCult2(S) - BYB(S)¥ - MMFNW(S) - MMFNE(S) - MMFSE(S) - R1(S)¥ - SCh.21(S)¥ - BYS6(P) - So.12(S)* - So.10(S)* - BYS4(P) - BYS5(P) - BYS6(P) - So.12(S)* - So.10(S)* - BYS4(P) - BYS3(S) - BYS2(S) - BYS1(S)'],
  [29,'Pinto Long - west','50 nm',12,'BYS3(S) - Old.SCh.6(P) - SCh.2(S) - WCh.1(S) - WCh.2(P) - CoCh.Light1(S)* - CoCh.3(S)* - CoCh.5(S)* - CoCh.7(S) - WCh.Pile(P)¥ - PrcGrgBnkLt(S) - WCh.Pile(S)¥ - WCh.7(P)* - WCh.6(S)* - WCh.5(P)* - WCh.3(P)* - WCh.1(P)* - PpsEyeLght(P)¥ - SCh.1(P) - SCh.3(S) - So.1(S)* - So.2(P)* - So.4(P)* - So.6(P)* - So.8(P)* - So.3(S) - BYS3(P) - BYS0(S)* - BYS4(S) - So.10(P)* - So.12(P)* - SCh.13(S)¥ - BYS5(S) - So.10(S)* - BYS4(S) - BYS2(P) - BYS1(S)'],
  [30,'Pinto Short - west','44 nm',12,'BYS3(S) - SCh.7(P) - SCh.2(S) - WCh.1(S) - WCh.2(P) - CoCh.Light1(S)* - CoCh.3(S)* - CoCh.5(S)* - CoCh.7(S) - WCh.13(S)¥ - WCh.11(P)* - WCh.7(P)* - WCh.6(S)* - WCh.5(P)* - WCh.3(P)* - WCh.1(P)* - PpsEyeLght(P)¥ - SCh.1(P) - SCh.3(S) - So.1(S) - So.2(P)* - So.4(P)* - So.6(P)* - So.8(P)* - So.3(S) - BYS3(P) - BYS2(S) - BYS4(P) - So.10(P)* - So.12(P)* - SCh.13(S)¥ - BYS5(S) - So.10(S)* - BYS4(P) - So.10(P)* - So.12(P)* - BYS6(S) - BYS5(S) - BYS4(P)* - BYS1(S)'],
  [31,'Figure 8, Spry, club front area','27 nm',12,'BYS3(S) - BYS2(S) - SCh.7(P) - SCh.3(P)¥ - So.1(S) - So.2(P)* - So.4(P)* - So.6(P)* - So.8(P)* - So.3(S) - BYS3(P) - BYS0(S)* - BYS4(S) - So.10(P)* - So.12(P)* - BYS6(S) - SCh.13(S)¥ - BYS5(S) - BYS6(S) - BYS5(S) - So.10(S)* - BYS4(S) - BYS2(P) - BYS3(P) - So.10(P)* - BYS5(S) - BYS1(S)'],
  [32,'Figure 8, Spry, club front east area','20 nm',13,'BYS3(S) - BYS2(S) - SCh.7(P) - SCh.3(P)¥ - So.1(S) - So.2(P)* - So.4(P)* - So.6(P)* - So.8(P)* - So.3(S) - BYS3(P) - BYS0(S)* - BYS4(S) - So.10(P)* - So.12(P)* - BYS6(S) - SCh.19(S)¥ - BYS6(P) - BYS5(S) - So.10(S)* - BYS4(S)* - BYS1(S)'],
  [33,'Around sands navigation race','32 nm',13,'BYS4(P) - { SCh.19(P) or WCh.1(S) } - Virtual mark 38°10.000\'S 144°49.000\'E - { SCh.19(P) or WCh.1(S) } - BYS1(S)'],
  [35,'Special course - refer to Official Notice Board','',13,'Course published on Official Notice Board'],
  [40,'Twilight - E, W short course','4.2 nm',13,'BYS4* - So.10* - BYS5 - BYS4 - BYS1(S)'],
  [41,'Twilight - NW, SE club front','7.1 nm',13,'BYS4 - BYS2 - BYS3 - BYS14 - BYS2 - BYS1(S)'],
  [42,'Twilight - N, S, E, W','6.0 nm',13,'BYS4 - BYS2 - BYS3(S) - BYS2(S) - BYS1(S)'],
  [43,'Twilight - E, W','5.2 nm',13,'BYS4* - BYS5 - BYS4(S)* - BYS3 - BYS1(S)'],
  [44,'Twilight - N, S, E, W (OTB clash at BYS14)','4.2 nm',13,'BYS4 - BYS2 - BYS3 - BYS14(S) - BYS1(S)'],
  [50,'Division A - on-the-wind start, east','12.4 nm',14,'Turning mark(S) - BYS4 - So.10* - So.12* - BYS6(S) - BYS5(S) - BYS4 - BYS3(S) - BYS4 - BYS5(S) - BYS1(S)','div-a'],
  [50,'Division B - on-the-wind start, east','9.0 nm',14,'Turning mark(S) - BYS4 - So.10* - So.12* - BYS6(S) - BYS5(S) - BYS4 - BYS5(S) - BYS1(S)','div-b'],
  [51,'Division A - on-the-wind start, west','12.4 nm',14,'Turning mark - BYS3 - BYS4 - So.10* - So.12* - BYS6(S) - BYS5(S) - BYS4 - BYS3(S) - BYS4 - BYS5(S) - BYS1(S)','div-a'],
  [51,'Division B - on-the-wind start, west','10.9 nm',14,'Turning mark - BYS3 - BYS4 - So.10* - So.12* - BYS6(S) - BYS5(S) - BYS4 - BYS5(S) - BYS1(S)','div-b'],
  [52,'Division A - on-the-wind start, north','10.3 nm',14,'Turning mark(S) - BYS4 - BYS2 - BYS3 - BYS2 - BYS3 - BYS4 - BYS2 - BYS1(S)','div-a'],
  [52,'Division B - on-the-wind start, north','7.4 nm',14,'Turning mark(S) - BYS4 - BYS2 - BYS3 - BYS2 - BYS3 - BYS14(S) - BYS1(S)','div-b'],
  [53,'Division A - on-the-wind start, south','10.3 nm',14,'Turning mark - BYS4 - BYS2 - BYS3 - BYS2 - BYS3 - BYS4 - BYS2 - BYS1(S)','div-a'],
  [53,'Division B - on-the-wind start, south','7.1 nm',14,'Turning mark - BYS4 - BYS2 - BYS3 - BYS2 - BYS3 - BYS14(S) - BYS1(S)','div-b'],
]

const laid = [
  [10,'Division A - Aggregate','Start - 1 - 1A - 3 - 1 - 3 - 1 - 3 - 1 - 3 - Finish','div-a'],
  [10,'Division B - Aggregate','Start - 1 - 1A - 3 - 1 - 3 - 1 - 3 - Finish','div-b'],
  [11,'Division A - Aggregate, upwind finish','Start - 1 - 1A - 3 - 1 - 3 - 1 - 3 - 1 - 3 - Finish','div-a'],
  [11,'Division B - Aggregate, upwind finish','Start - 1 - 1A - 3 - 1 - 3 - 1 - 3 - Finish','div-b'],
]

function sideFor(token, defaultSide = 'port') {
  if (/^Start/i.test(token)) return 'start'
  if (/Finish/i.test(token)) return 'finish'
  const parts = [token.includes('(S)') ? 'starboard' : token.includes('(P)') ? 'port' : defaultSide]
  if (token.includes('*')) parts.push('passing-mark')
  if (token.includes('¥')) parts.push('radio-report')
  return parts.join('-')
}

function cleanMark(token) {
  return token.replace(/\([PS]\)/g, '').replace(/[\*¥]/g, '').trim()
}

function rows(route, defaultSide = 'port') {
  const tokens = route.split(/\s+-\s+/)
  if (!/^Start/i.test(tokens[0])) tokens.unshift('Start')
  if (!/Finish/i.test(tokens.at(-1))) tokens.push('Finish')
  return tokens.map((token) => ({
    mark: cleanMark(token), side: sideFor(token, defaultSide), bearing: '', distance: '',
  }))
}

const fixedCourses = fixed.map(([courseNumber, route, totalDistance, sourcePage, sequence, identitySuffix]) => ({
  courseNumber, ...(identitySuffix ? { identitySuffix } : {}), route,
  groupId: identitySuffix ? `fixed-${identitySuffix}` : 'fixed-kbc',
  passInstruction: sourcePage >= 11 && sourcePage <= 13
    ? 'Round or pass to port or starboard as shown. A passing mark is labelled in the table; radio-report marks require a position report.'
    : 'Round or pass marks to port unless shown as starboard. A passing mark is labelled in the table.',
  rows: rows(sequence), totalDistance, chartImage: '', chartAlt: '',
  dataStatus: 'verified-from-official-pdf-v2', sourcePage,
  comparableCourseNote: courseNumber === 35 ? 'Route is race-day data published on the Official Notice Board.' : null,
}))

const laidCourses = laid.map(([courseNumber, route, sequence, identitySuffix]) => ({
  courseNumber, identitySuffix, route, groupId: 'laid',
  passInstruction: 'All laid marks are rounded to port. Mark positions and start/finish lines are set on the water.',
  rows: rows(sequence), totalDistance: '', chartImage: '', chartAlt: '',
  dataStatus: 'verified-from-official-pdf-v2-race-day-positions-required', sourcePage: 10,
  comparableCourseNote: courseNumber === 11 ? 'Finish is upwind of Mark 1.' : null,
}))

writeFileSync(join(output, 'fixed-courses.json'), `${JSON.stringify(fixedCourses, null, 2)}\n`)
writeFileSync(join(output, 'laid-courses.json'), `${JSON.stringify(laidCourses, null, 2)}\n`)
console.log(`Wrote ${fixedCourses.length} fixed/hybrid variants and ${laidCourses.length} laid variants.`)
