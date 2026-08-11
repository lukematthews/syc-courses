export type AdminRole = 'owner' | 'publisher' | 'editor'

export type AdminMark = {
  id: string
  name: string
  aliases: string[]
  latitude: number
  longitude: number
  description?: string
}

export type AdminLeg = {
  id: string
  markId: string
  markName: string
  side: string
  bearing: string
  distance: string
}

export type AdminCourse = {
  id: string
  kind: 'fixed' | 'laid'
  groupId: string
  courseNumber: number
  route?: string
  passInstruction: string
  legs: AdminLeg[]
  totalDistanceNm: number
  chartImage?: string
  chartFileName?: string
  chartAlt: string
  status: 'published' | 'draft'
  updatedAt: string
}

export type AdminMember = {
  id: string
  name: string
  email: string
  role: AdminRole
  status: 'active' | 'invited'
}

export type PackAuditEntry = {
  id: string
  item: string
  change: string
  editor: string
  at: string
}

export type NoticeSection = { id: string; heading?: string; body: string }

export type NoticeToCompetitors = {
  id: string
  noticeNumber: string
  title: string
  series: string
  appliesTo: string
  issueDate: string
  summary: string
  warningSignals: string[]
  sections: NoticeSection[]
  issuerName: string
  issuerRole: string
  revision: number
  pdfFileName?: string
  pdfDataUrl?: string
  status: 'published' | 'draft'
  updatedAt: string
}

export type AdminPack = {
  schemaVersion: 1
  packId: string
  name: string
  shortName: string
  organiser: string
  version: string
  courseGroups: Array<{ id: string; name: string; kind: 'fixed' | 'laid' }>
  courses: AdminCourse[]
  marks: AdminMark[]
  members: AdminMember[]
  notices: NoticeToCompetitors[]
  audit: PackAuditEntry[]
  publishedAt?: string
  publishedVersion?: string
}

export type ValidationIssue = {
  id: string
  severity: 'error' | 'warning'
  message: string
  courseId?: string
  markId?: string
}
