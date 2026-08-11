import { allCourses, courseGroups, coursePack, marks } from '../data/bundledCoursePack'
import type { AdminCourse, AdminPack, ValidationIssue } from './types'

const storageKey = `syc-course-admin:${coursePack.packId}:draft`

function seedPack(): AdminPack {
  return {
    schemaVersion: 1,
    packId: coursePack.packId,
    name: coursePack.name,
    shortName: coursePack.shortName,
    organiser: coursePack.organiser,
    version: coursePack.version,
    courseGroups,
    marks: marks.map((mark) => ({ id: mark.id, name: mark.name, aliases: mark.aliases, latitude: mark.latitude, longitude: mark.longitude, description: mark.description })),
    courses: allCourses.map((course) => ({
      id: course.id,
      kind: course.kind,
      groupId: course.groupId ?? course.kind,
      courseNumber: course.courseNumber,
      route: course.route,
      passInstruction: course.passInstruction,
      legs: course.rows.filter((row) => row.mark !== 'TOTAL').map((row, index) => {
        const mark = marks.find((candidate) => [candidate.name, ...candidate.aliases].some((name) => name.toLowerCase() === row.mark.toLowerCase()))
        return { id: `${course.id}:leg-${index + 1}`, markId: mark?.id ?? '', markName: row.mark, side: row.side, bearing: row.bearing, distance: row.distance }
      }),
      totalDistanceNm: Number.parseFloat(course.totalDistance) || 0,
      chartImage: course.chartImage,
      chartAlt: course.chartAlt,
      status: 'published',
      updatedAt: new Date(0).toISOString(),
    })),
    members: [{ id: 'local-owner', name: 'Local administrator', email: 'developer@localhost', role: 'owner', status: 'active' }],
    notices: [{
      id: 'syc-ntc-2026-sat-wint-1', noticeNumber: '2026_Sat_Wint_1', title: 'Notice to Competitors',
      series: 'Saturday Winter Series 2026', appliesTo: 'SYC Alan Shiels Race 2', issueDate: '2026-07-25',
      summary: 'Club Course boat start, amended warning signals and replacement courses 1-2.',
      warningSignals: ['Division 1 - Code Flag W - no earlier than 1155', 'Division 2 - Code Flag E - no earlier than 1200'],
      sections: [
        { id: '1', body: 'This will be a Club Course boat start event, per SI Appendix A.1.' },
        { id: '2', body: 'Courses 1-2 of the SYC Sailing Instructions Appendix A.1 are replaced by the courses in this notice. This amends SI 13.2. The Gate will be laid up to 1.0 nm to windward from the start line.\n\nCourse 1: Start - Gate - 5 (Port) - MMYC #4 (Starboard) - 5 - 6 - 3 - 4 - 6 - 3 - 4 - 2 - 3 - Finish. Approx. 23.5 nm.\n\nCourse 2: Start - Gate - 5 (Port) - MMYC #4 (Starboard) - 5 - 6 - 3 - 4 - 2 - 3 - Finish. Approx. 19.5 nm.' },
        { id: '3', body: "The following mark is added to SI 14.3: MMYC, yellow conical, 38° 00.777'S, 145° 03.604'E." },
      ],
      issuerName: 'Nick Disney', issuerRole: 'SYC Club Captain - Sail', revision: 0,
      pdfFileName: 'NTC_2026_Sat_Winter_1_Alan_Shiels_Race_2_Rev_0.pdf', status: 'published', updatedAt: '2026-07-25T00:00:00Z',
    }],
    audit: [],
    publishedVersion: coursePack.version,
  }
}

export function loadAdminPack(): AdminPack {
  try {
    const stored = localStorage.getItem(storageKey)
    if (stored) {
      const seed = seedPack()
      const parsed = JSON.parse(stored) as Partial<AdminPack>
      return { ...seed, ...parsed, notices: parsed.notices ?? seed.notices, members: parsed.members ?? seed.members, audit: parsed.audit ?? [] }
    }
  } catch { /* fall back to bundled data */ }
  return seedPack()
}

export function saveAdminPack(pack: AdminPack) {
  localStorage.setItem(storageKey, JSON.stringify(pack))
}

export function resetAdminPack() {
  localStorage.removeItem(storageKey)
  return seedPack()
}

export function validatePack(pack: AdminPack): ValidationIssue[] {
  const issues: ValidationIssue[] = []
  const markIds = new Set(pack.marks.map((mark) => mark.id))
  const identities = new Set<string>()
  for (const mark of pack.marks) {
    if (!Number.isFinite(mark.latitude) || mark.latitude < -90 || mark.latitude > 90 || !Number.isFinite(mark.longitude) || mark.longitude < -180 || mark.longitude > 180) {
      issues.push({ id: `coordinate:${mark.id}`, severity: 'error', markId: mark.id, message: `${mark.name} has invalid coordinates.` })
    }
  }
  for (const course of pack.courses) {
    const identity = `${course.groupId}:${course.courseNumber}`
    if (identities.has(identity)) issues.push({ id: `duplicate:${course.id}`, severity: 'error', courseId: course.id, message: `Course ${course.courseNumber} is duplicated in its course group.` })
    identities.add(identity)
    if (course.legs.length < 2) issues.push({ id: `legs:${course.id}`, severity: 'error', courseId: course.id, message: `Course ${course.courseNumber} needs at least two legs.` })
    course.legs.forEach((leg, index) => {
      if (leg.markId && !markIds.has(leg.markId)) issues.push({ id: `mark:${course.id}:${index}`, severity: 'error', courseId: course.id, message: `Course ${course.courseNumber}, leg ${index + 1} points to a missing mark.` })
      if (!leg.markName.trim()) issues.push({ id: `unresolved:${course.id}:${index}`, severity: 'error', courseId: course.id, message: `Course ${course.courseNumber}, leg ${index + 1} does not have a mark selected.` })
    })
  }
  for (const notice of pack.notices) {
    if (!notice.noticeNumber.trim() || !notice.series.trim() || !notice.appliesTo.trim() || !notice.issueDate) {
      issues.push({ id: `notice-metadata:${notice.id}`, severity: 'error', message: `Notice ${notice.noticeNumber || '(untitled)'} is missing required event metadata.` })
    }
    if (!notice.pdfFileName && !notice.pdfDataUrl) issues.push({ id: `notice-pdf:${notice.id}`, severity: 'warning', message: `Notice ${notice.noticeNumber || '(untitled)'} has no authoritative PDF attached.` })
    if (!notice.sections.some((section) => section.body.trim())) issues.push({ id: `notice-content:${notice.id}`, severity: 'error', message: `Notice ${notice.noticeNumber || '(untitled)'} has no readable in-app content.` })
  }
  return issues
}

export function markCourseDraft(course: AdminCourse): AdminCourse {
  return { ...course, status: 'draft', updatedAt: new Date().toISOString() }
}
