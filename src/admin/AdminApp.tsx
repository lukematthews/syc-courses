import { useEffect, useMemo, useRef, useState } from 'react'
import { hasAdminApi, loadRemotePack, publishRemotePack, saveRemotePack } from './api'
import { recalculateLegs } from './navigation'
import { loadAdminPack, markCourseDraft, saveAdminPack, validatePack } from './store'
import type { AdminCourse, AdminLeg, AdminMark, AdminPack, AdminRole, NoticeToCompetitors } from './types'
import { useAdminIdentity } from './AdminIdentity'
import './admin.css'

type Page = 'overview' | 'courses' | 'marks' | 'notices' | 'publish' | 'administrators'

export default function AdminApp() {
  const [pack, setPack] = useState(loadAdminPack)
  const [page, setPage] = useState<Page>('overview')
  const [editingCourseId, setEditingCourseId] = useState<string>()
  const [editingNoticeId, setEditingNoticeId] = useState<string>()
  const [query, setQuery] = useState('')
  const identity = useAdminIdentity()
  const getAccessToken = identity.getAccessToken
  const [remoteReady, setRemoteReady] = useState(false)
  const [syncStatus, setSyncStatus] = useState(hasAdminApi ? 'Connecting…' : 'Local preview')
  const revision = useRef<number | null>(null)
  const lastSaved = useRef('')
  const issues = useMemo(() => validatePack(pack), [pack])
  const drafts = pack.courses.filter((course) => course.status === 'draft')

  useEffect(() => { saveAdminPack(pack) }, [pack])

  useEffect(() => {
    if (!hasAdminApi || !getAccessToken) return
    let cancelled = false
    void getAccessToken().then(loadRemotePack).then((remote) => {
      if (cancelled) return
      revision.current = remote.revision
      lastSaved.current = JSON.stringify(remote.pack)
      setPack(remote.pack); setRemoteReady(true); setSyncStatus('Saved to club workspace')
    }).catch((error: Error & { status?: number }) => {
      if (cancelled) return
      if (error.status === 404) { setRemoteReady(true); setSyncStatus('New club workspace') }
      else setSyncStatus(error.message)
    })
    return () => { cancelled = true }
  }, [getAccessToken])

  useEffect(() => {
    if (!remoteReady || !getAccessToken) return
    const serialized = JSON.stringify(pack)
    if (serialized === lastSaved.current) return
    const timer = window.setTimeout(() => {
      setSyncStatus('Saving…')
      void getAccessToken().then((token) => saveRemotePack(token, pack, revision.current)).then((remote) => {
        revision.current = remote.revision; lastSaved.current = serialized; setSyncStatus('Saved to club workspace')
      }).catch((error: Error) => setSyncStatus(error.message))
    }, 650)
    return () => window.clearTimeout(timer)
  }, [pack, remoteReady, getAccessToken])

  const updateCourse = (course: AdminCourse) => {
    const next = markCourseDraft(course)
    setPack((current) => ({
      ...current,
      courses: current.courses.map((candidate) => candidate.id === next.id ? next : candidate),
      audit: [{ id: crypto.randomUUID(), item: `Course ${next.courseNumber}`, change: 'Course draft updated', editor: identity.name, at: new Date().toISOString() }, ...current.audit].slice(0, 50),
    }))
  }

  const editingCourse = pack.courses.find((course) => course.id === editingCourseId)
  if (editingCourse) return <CourseEditor course={editingCourse} marks={pack.marks} groups={pack.courseGroups} onBack={() => setEditingCourseId(undefined)} onSave={updateCourse} />
  const editingNotice = pack.notices.find((notice) => notice.id === editingNoticeId)
  if (editingNotice) return <NoticeEditor notice={editingNotice} onBack={() => setEditingNoticeId(undefined)} onSave={(notice) => setPack((current) => ({ ...current, notices: current.notices.map((candidate) => candidate.id === notice.id ? { ...notice, status: 'draft', updatedAt: new Date().toISOString() } : candidate), audit: [{ id: crypto.randomUUID(), item: `NTC ${notice.noticeNumber}`, change: 'Notice draft updated', editor: identity.name, at: new Date().toISOString() }, ...current.audit] }))} />

  return (
    <div className="admin-shell">
      <header className="admin-topbar">
        <div className="admin-brand"><img src="/app-icon.png" alt="" /><div><strong>SYC Courses</strong><span>Club administration</span></div></div>
        <div className="admin-user"><div><strong>{pack.organiser}</strong><span>{identity.name} · {syncStatus}</span></div>{identity.isDevelopment && <b>DEV</b>}{identity.logout && <button onClick={identity.logout}>Sign out</button>}</div>
      </header>
      <div className="admin-layout">
        <aside className="admin-sidebar">
          <AdminNav page={page} onChange={setPage} />
        </aside>
        <main className="admin-main">
          {page === 'overview' && <Overview pack={pack} drafts={drafts.length} onNavigate={setPage} />}
          {page === 'courses' && <Courses pack={pack} query={query} setQuery={setQuery} onEdit={setEditingCourseId} onNew={() => {
            const course = newCourse(pack)
            setPack((current) => ({ ...current, courses: [course, ...current.courses] }))
            setEditingCourseId(course.id)
          }} />}
          {page === 'marks' && <Marks pack={pack} onChange={setPack} />}
          {page === 'notices' && <Notices pack={pack} onEdit={setEditingNoticeId} onNew={() => {
            const notice = newNotice()
            setPack((current) => ({ ...current, notices: [notice, ...current.notices] }))
            setEditingNoticeId(notice.id)
          }} />}
          {page === 'publish' && <Publish pack={pack} issues={issues} onPublish={async () => {
            const version = new Date().toISOString().slice(0, 10).replaceAll('-', '.')
            const published = { ...pack, courses: pack.courses.map((course) => ({ ...course, status: 'published' as const })), notices: pack.notices.map((notice) => ({ ...notice, status: 'published' as const })), publishedAt: new Date().toISOString(), publishedVersion: version, audit: [{ id: crypto.randomUUID(), item: 'Course pack', change: `Published version ${version}`, editor: identity.name, at: new Date().toISOString() }, ...pack.audit] }
            if (hasAdminApi && getAccessToken) {
              try {
                setSyncStatus('Publishing…')
                const token = await getAccessToken()
                const saved = await saveRemotePack(token, published, revision.current)
                revision.current = saved.revision; lastSaved.current = JSON.stringify(published)
                await publishRemotePack(token, version)
                setSyncStatus(`Published ${version}`)
              } catch (error) { setSyncStatus(error instanceof Error ? error.message : 'Publishing failed'); return }
            }
            setPack(published)
          }} />}
          {page === 'administrators' && <Administrators pack={pack} onChange={setPack} />}
        </main>
      </div>
    </div>
  )
}

function AdminNav({ page, onChange }: { page: Page; onChange: (page: Page) => void }) {
  const item = (id: Page, label: string) => <button className={page === id ? 'active' : ''} onClick={() => onChange(id)}>{label}</button>
  return <nav aria-label="Administration"><span>Workspace</span>{item('overview', 'Overview')}<span>Course pack</span>{item('courses', 'Courses')}{item('marks', 'Marks')}{item('notices', 'Notices to competitors')}{item('publish', 'Review & publish')}<span>Club</span>{item('administrators', 'Administrators')}</nav>
}

function Overview({ pack, drafts, onNavigate }: { pack: AdminPack; drafts: number; onNavigate: (page: Page) => void }) {
  return <><PageHeading title="Course pack" subtitle="Current app content and pending club changes." action={<button className="admin-primary-button" onClick={() => onNavigate('courses')}>Manage courses</button>} />
    <div className="admin-stats"><Stat label="Published courses" value={pack.courses.length - drafts} detail="Fixed and laid courses" /><Stat label="Marks" value={pack.marks.length} detail="Shared navigation marks" /><Stat label="Unpublished changes" value={drafts} detail={drafts ? 'Ready for review' : 'Course pack is current'} /></div>
    <section className="admin-panel"><div className="admin-panel-heading"><div><h2>Recent changes</h2><p>Changes remain private until the course pack is published.</p></div><button onClick={() => onNavigate('publish')}>Review changes</button></div>
      {pack.audit.length ? <table><thead><tr><th>Item</th><th>Change</th><th>Editor</th><th>Time</th></tr></thead><tbody>{pack.audit.slice(0, 8).map((entry) => <tr key={entry.id}><td><strong>{entry.item}</strong></td><td>{entry.change}</td><td>{entry.editor}</td><td>{formatDate(entry.at)}</td></tr>)}</tbody></table> : <Empty text="No administrative changes yet." />}
    </section></>
}

function Courses({ pack, query, setQuery, onEdit, onNew }: { pack: AdminPack; query: string; setQuery: (value: string) => void; onEdit: (id: string) => void; onNew: () => void }) {
  const filtered = pack.courses.filter((course) => `${course.courseNumber} ${course.route ?? ''} ${course.legs.map((leg) => leg.markName).join(' ')}`.toLowerCase().includes(query.toLowerCase()))
  return <><PageHeading title="Courses" subtitle="Edit course tables and preview their app presentation." action={<button className="admin-primary-button" onClick={onNew}>New course</button>} /><div className="admin-tools"><input aria-label="Search courses" placeholder="Search by course number or mark" value={query} onChange={(event) => setQuery(event.target.value)} /></div>
    <section className="admin-panel admin-table-wrap"><table><thead><tr><th>Course</th><th>Group</th><th>First mark</th><th>Distance</th><th>Status</th></tr></thead><tbody>{filtered.map((course) => <tr key={course.id} onClick={() => onEdit(course.id)}><td><strong>{course.courseNumber}</strong></td><td>{pack.courseGroups.find((group) => group.id === course.groupId)?.name ?? course.groupId}</td><td>{course.legs[0]?.markName ?? '—'}</td><td>{course.totalDistanceNm.toFixed(2)} nm</td><td><Status value={course.status} /></td></tr>)}</tbody></table></section></>
}

function CourseEditor({ course, marks, groups, onBack, onSave }: { course: AdminCourse; marks: AdminMark[]; groups: AdminPack['courseGroups']; onBack: () => void; onSave: (course: AdminCourse) => void }) {
  const [draft, setDraft] = useState(course)
  const modifyLegs = (legs: AdminLeg[]) => setDraft((current) => ({ ...current, ...recalculateLegs(legs, marks) }))
  const setLegMark = (index: number, markName: string) => {
    const normalized = markName.trim().toLowerCase()
    const mark = marks.find((candidate) => [candidate.name, ...candidate.aliases].some((name) => name.toLowerCase() === normalized))
    modifyLegs(draft.legs.map((leg, legIndex) => legIndex === index ? { ...leg, markId: mark?.id ?? '', markName } : leg))
  }
  const move = (index: number, offset: number) => { const next = [...draft.legs]; const [leg] = next.splice(index, 1); next.splice(index + offset, 0, leg); modifyLegs(next) }
  const uploadChart = (file?: File) => {
    if (!file) return
    if (file.size > 4 * 1024 * 1024) return alert('Course graphics must be 4 MB or smaller.')
    const reader = new FileReader()
    reader.onload = () => setDraft((current) => ({ ...current, chartImage: String(reader.result), chartFileName: file.name }))
    reader.readAsDataURL(file)
  }
  return <div className="admin-shell"><header className="admin-topbar"><div className="admin-brand"><img src="/app-icon.png" alt="" /><div><strong>SYC Courses</strong><span>Course editor</span></div></div><Status value="draft" /></header><main className="admin-editor-page"><button className="admin-back" onClick={onBack}>← Courses</button><div className="admin-editor-grid"><section className="admin-panel admin-form"><PageHeading title={`Edit course ${draft.courseNumber}`} subtitle="Changes are saved as a private draft." action={<button className="admin-primary-button" onClick={() => { onSave(draft); onBack() }}>Save draft</button>} />
    <div className="admin-field-grid"><label>Course number<input type="number" value={draft.courseNumber} onChange={(event) => setDraft({ ...draft, courseNumber: Number(event.target.value) })} /></label><label>Course group<select value={draft.groupId} onChange={(event) => setDraft({ ...draft, groupId: event.target.value })}>{groups.map((group) => <option key={group.id} value={group.id}>{group.name}</option>)}</select></label><label>Total distance<input readOnly value={`${draft.totalDistanceNm.toFixed(2)} nm`} /><small>Calculated automatically from resolved mark coordinates.</small></label><label>Passing instruction<input value={draft.passInstruction} onChange={(event) => setDraft({ ...draft, passInstruction: event.target.value })} /></label></div>
    <label className="admin-upload"><span className="admin-chart-thumb">{draft.chartImage ? <img src={draft.chartImage} alt="Course chart thumbnail" /> : 'Chart'}</span><span><strong>Course chart or layout</strong><small>{draft.chartFileName ?? (draft.chartImage ? 'Existing course chart' : 'PNG, JPEG, WebP or SVG up to 4 MB')}</small><span className="admin-file-button">Choose graphic</span></span><input type="file" accept="image/png,image/jpeg,image/webp,image/svg+xml" onChange={(event) => uploadChart(event.target.files?.[0])} /></label>
    <datalist id="admin-mark-suggestions">{marks.map((mark) => <option key={mark.id} value={mark.name} />)}</datalist>
    <div className="admin-leg-heading"><h2>Course legs</h2><button onClick={() => modifyLegs([...draft.legs, { id: crypto.randomUUID(), markId: '', markName: '', side: 'Port', bearing: '', distance: '' }])}>Add leg</button></div><div className="admin-table-wrap"><table className="admin-legs"><thead><tr><th>Leg</th><th>Mark or instruction</th><th>Side</th><th>Bearing</th><th>Distance</th><th>Order</th></tr></thead><tbody>{draft.legs.map((leg, index) => <tr key={leg.id}><td>{index + 1}</td><td><input list="admin-mark-suggestions" placeholder="Enter a mark or instruction" value={leg.markName} onChange={(event) => setLegMark(index, event.target.value)} /></td><td><select value={leg.side} onChange={(event) => modifyLegs(draft.legs.map((candidate, legIndex) => legIndex === index ? { ...candidate, side: event.target.value } : candidate))}><option>Port</option><option>Starboard</option><option>Pass</option><option>—</option></select></td><td>{leg.bearing || '—'}</td><td>{leg.distance || '—'}</td><td><span className="admin-order"><button disabled={index === 0} aria-label={`Move leg ${index + 1} up`} onClick={() => move(index, -1)}>↑</button><button disabled={index === draft.legs.length - 1} aria-label={`Move leg ${index + 1} down`} onClick={() => move(index, 1)}>↓</button><button aria-label={`Delete leg ${index + 1}`} onClick={() => modifyLegs(draft.legs.filter((candidate) => candidate.id !== leg.id))}>×</button></span></td></tr>)}</tbody></table></div>
    </section><AppPreview course={draft} /></div></main></div>
}

function AppPreview({ course }: { course: AdminCourse }) { return <aside className="admin-panel admin-preview"><h2>App preview</h2><p>Course table and uploaded chart.</p><div className="admin-phone"><header>SYC Courses</header><div className="admin-phone-title"><strong>Course {course.courseNumber}</strong><span>{course.totalDistanceNm.toFixed(2)} nm</span></div><table><thead><tr><th>Mark</th><th>Side</th><th>Brg</th><th>Dist</th></tr></thead><tbody>{course.legs.map((leg) => <tr key={leg.id}><td>{leg.markName || 'Mark not selected'}</td><td>{leg.side}</td><td>{leg.bearing || '—'}</td><td>{leg.distance || '—'}</td></tr>)}</tbody></table>{course.chartImage && <img className="admin-phone-chart" src={course.chartImage} alt={course.chartAlt || `Course ${course.courseNumber} layout`} />}</div></aside> }

function Marks({ pack, onChange }: { pack: AdminPack; onChange: (pack: AdminPack) => void }) {
  const update = (id: string, field: keyof AdminMark, value: string) => onChange({ ...pack, marks: pack.marks.map((mark) => mark.id === id ? { ...mark, [field]: field === 'latitude' || field === 'longitude' ? Number(value) : value } : mark) })
  return <><PageHeading title="Marks" subtitle="Shared names and coordinates used to calculate course legs." action={<button className="admin-primary-button" onClick={() => onChange({ ...pack, marks: [{ id: crypto.randomUUID(), name: 'New mark', aliases: [], latitude: 0, longitude: 0 }, ...pack.marks] })}>New mark</button>} /><section className="admin-panel admin-table-wrap"><table><thead><tr><th>Name</th><th>Latitude</th><th>Longitude</th><th>Used by</th></tr></thead><tbody>{pack.marks.map((mark) => <tr key={mark.id}><td><input value={mark.name} onChange={(event) => update(mark.id, 'name', event.target.value)} /></td><td><input type="number" step="0.000001" value={mark.latitude} onChange={(event) => update(mark.id, 'latitude', event.target.value)} /></td><td><input type="number" step="0.000001" value={mark.longitude} onChange={(event) => update(mark.id, 'longitude', event.target.value)} /></td><td>{pack.courses.filter((course) => course.legs.some((leg) => leg.markId === mark.id)).length} courses</td></tr>)}</tbody></table></section></>
}

function Notices({ pack, onEdit, onNew }: { pack: AdminPack; onEdit: (id: string) => void; onNew: () => void }) {
  return <><PageHeading title="Notices to competitors" subtitle="Publish race amendments with a readable in-app version and the original PDF." action={<button className="admin-primary-button" onClick={onNew}>New notice</button>} /><section className="admin-panel admin-table-wrap"><table><thead><tr><th>Notice</th><th>Series</th><th>Applies to</th><th>Issued</th><th>Status</th></tr></thead><tbody>{pack.notices.map((notice) => <tr key={notice.id} onClick={() => onEdit(notice.id)}><td><strong>{notice.noticeNumber}</strong></td><td>{notice.series}</td><td>{notice.appliesTo}</td><td>{notice.issueDate}</td><td><Status value={notice.status} /></td></tr>)}</tbody></table></section></>
}

function NoticeEditor({ notice, onBack, onSave }: { notice: NoticeToCompetitors; onBack: () => void; onSave: (notice: NoticeToCompetitors) => void }) {
  const [draft, setDraft] = useState(notice)
  const uploadPdf = (file?: File) => {
    if (!file) return
    if (file.type !== 'application/pdf') return alert('Select a PDF document.')
    if (file.size > 8 * 1024 * 1024) return alert('Notice PDFs must be 8 MB or smaller.')
    const reader = new FileReader()
    reader.onload = () => setDraft((current) => ({ ...current, pdfFileName: file.name, pdfDataUrl: String(reader.result) }))
    reader.readAsDataURL(file)
  }
  return <div className="admin-shell"><header className="admin-topbar"><div className="admin-brand"><img src="/app-icon.png" alt="" /><div><strong>SYC Courses</strong><span>Notice editor</span></div></div><Status value="draft" /></header><main className="admin-editor-page"><button className="admin-back" onClick={onBack}>← Notices</button><div className="admin-editor-grid"><section className="admin-panel admin-form"><PageHeading title={draft.noticeNumber ? `Edit NTC ${draft.noticeNumber}` : 'New notice to competitors'} subtitle="The structured version is readable offline; the signed source PDF is retained." action={<button className="admin-primary-button" onClick={() => { onSave(draft); onBack() }}>Save draft</button>} />
    <div className="admin-field-grid"><label>Notice number<input value={draft.noticeNumber} onChange={(event) => setDraft({ ...draft, noticeNumber: event.target.value })} /></label><label>Revision<input type="number" min="0" value={draft.revision} onChange={(event) => setDraft({ ...draft, revision: Number(event.target.value) })} /></label><label>Series<input value={draft.series} onChange={(event) => setDraft({ ...draft, series: event.target.value })} /></label><label>Applicable to<input value={draft.appliesTo} onChange={(event) => setDraft({ ...draft, appliesTo: event.target.value })} /></label><label>Issue date<input type="date" value={draft.issueDate} onChange={(event) => setDraft({ ...draft, issueDate: event.target.value })} /></label><label>Title<input value={draft.title} onChange={(event) => setDraft({ ...draft, title: event.target.value })} /></label></div>
    <label className="admin-long-field">Summary<textarea rows={3} value={draft.summary} onChange={(event) => setDraft({ ...draft, summary: event.target.value })} /></label>
    <label className="admin-upload"><span className="admin-chart-thumb">PDF</span><span><strong>Original notice PDF</strong><small>{draft.pdfFileName ?? 'PDF up to 8 MB'}</small><span className="admin-file-button">Choose PDF</span></span><input type="file" accept="application/pdf" onChange={(event) => uploadPdf(event.target.files?.[0])} /></label>
    <div className="admin-leg-heading"><h2>Warning signals</h2><button onClick={() => setDraft({ ...draft, warningSignals: [...draft.warningSignals, ''] })}>Add signal</button></div>{draft.warningSignals.map((signal, index) => <div className="admin-repeater" key={index}><input value={signal} onChange={(event) => setDraft({ ...draft, warningSignals: draft.warningSignals.map((value, valueIndex) => valueIndex === index ? event.target.value : value) })} /><button onClick={() => setDraft({ ...draft, warningSignals: draft.warningSignals.filter((_, valueIndex) => valueIndex !== index) })}>×</button></div>)}
    <div className="admin-leg-heading"><h2>Notice sections</h2><button onClick={() => setDraft({ ...draft, sections: [...draft.sections, { id: crypto.randomUUID(), body: '' }] })}>Add section</button></div>{draft.sections.map((section, index) => <div className="admin-section-editor" key={section.id}><strong>{index + 1}</strong><input placeholder="Optional heading" value={section.heading ?? ''} onChange={(event) => setDraft({ ...draft, sections: draft.sections.map((value) => value.id === section.id ? { ...value, heading: event.target.value } : value) })} /><textarea rows={5} value={section.body} onChange={(event) => setDraft({ ...draft, sections: draft.sections.map((value) => value.id === section.id ? { ...value, body: event.target.value } : value) })} /><button onClick={() => setDraft({ ...draft, sections: draft.sections.filter((value) => value.id !== section.id) })}>Remove</button></div>)}
    <div className="admin-field-grid"><label>Issuer name<input value={draft.issuerName} onChange={(event) => setDraft({ ...draft, issuerName: event.target.value })} /></label><label>Issuer role<input value={draft.issuerRole} onChange={(event) => setDraft({ ...draft, issuerRole: event.target.value })} /></label></div>
    </section><NoticePreview notice={draft} /></div></main></div>
}

function NoticePreview({ notice }: { notice: NoticeToCompetitors }) { return <aside className="admin-panel admin-preview"><h2>App preview</h2><p>Structured notice shown on iOS and Android.</p><div className="admin-phone admin-notice-preview"><header>Notice to Competitors</header><div><span className="admin-status draft">NTC {notice.noticeNumber || 'Draft'}</span><h3>{notice.series || 'Series'}</h3><strong>{notice.appliesTo || 'Applicable race'}</strong><p>{notice.summary}</p>{notice.warningSignals.map((signal) => <div className="admin-signal" key={signal}>{signal}</div>)}{notice.sections.map((section, index) => <section key={section.id}><b>{index + 1}. {section.heading}</b><p>{section.body}</p></section>)}</div></div></aside> }

function Publish({ pack, issues, onPublish }: { pack: AdminPack; issues: ReturnType<typeof validatePack>; onPublish: () => void | Promise<void> }) {
  const errors = issues.filter((issue) => issue.severity === 'error')
  return <><PageHeading title="Review & publish" subtitle="Validate the complete pack before making it available to app users." /><div className="admin-publish-grid"><section className="admin-panel"><div className="admin-panel-heading"><h2>Validation</h2><Status value={errors.length ? 'blocked' : 'ready'} /></div>{issues.length ? <ul className="admin-issues">{issues.slice(0, 30).map((issue) => <li key={issue.id} className={issue.severity}><strong>{issue.severity === 'error' ? 'Error' : 'Warning'}</strong><span>{issue.message}</span></li>)}</ul> : <div className="admin-validation-ok">✓ Course references, mark coordinates and numbering are valid.</div>}</section><aside className="admin-panel admin-publish-box"><h2>{errors.length ? 'Resolve errors first' : 'Ready to publish'}</h2><p>{pack.courses.filter((course) => course.status === 'draft').length} course drafts will be included in the next immutable version.</p><button className="admin-primary-button" disabled={Boolean(errors.length)} onClick={onPublish}>Publish course pack</button><button onClick={() => downloadPack(pack)}>Download JSON preview</button><small>Current version: {pack.publishedVersion ?? 'Never published'}</small></aside></div></>
}

function Administrators({ pack, onChange }: { pack: AdminPack; onChange: (pack: AdminPack) => void }) {
  const invite = () => { const email = prompt('Administrator email'); if (!email) return; onChange({ ...pack, members: [...pack.members, { id: crypto.randomUUID(), name: email.split('@')[0], email, role: 'editor', status: 'invited' }] }) }
  const role = (id: string, value: AdminRole) => onChange({ ...pack, members: pack.members.map((member) => member.id === id ? { ...member, role: value } : member) })
  return <><PageHeading title="Administrators" subtitle="Auth0 handles identity. Club roles and publishing authority are managed here." action={<button className="admin-primary-button" onClick={invite}>Invite administrator</button>} /><section className="admin-panel admin-table-wrap"><table><thead><tr><th>Name</th><th>Email</th><th>Role</th><th>Status</th></tr></thead><tbody>{pack.members.map((member) => <tr key={member.id}><td><strong>{member.name}</strong></td><td>{member.email}</td><td><select value={member.role} onChange={(event) => role(member.id, event.target.value as AdminRole)}><option value="owner">Owner</option><option value="publisher">Publisher</option><option value="editor">Editor</option></select></td><td><Status value={member.status} /></td></tr>)}</tbody></table></section></>
}

function PageHeading({ title, subtitle, action }: { title: string; subtitle: string; action?: React.ReactNode }) { return <div className="admin-page-heading"><div><h1>{title}</h1><p>{subtitle}</p></div>{action}</div> }
function Stat({ label, value, detail }: { label: string; value: number; detail: string }) { return <div className="admin-stat"><span>{label}</span><strong>{value}</strong><small>{detail}</small></div> }
function Status({ value }: { value: string }) { return <span className={`admin-status ${value}`}>{value}</span> }
function Empty({ text }: { text: string }) { return <div className="admin-empty">{text}</div> }
function formatDate(value: string) { return new Intl.DateTimeFormat(undefined, { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value)) }
function newCourse(pack: AdminPack): AdminCourse { const number = Math.max(0, ...pack.courses.map((course) => course.courseNumber)) + 1; return { id: `${pack.packId}/fixed/course-${number}`, kind: 'fixed', groupId: pack.courseGroups[0]?.id ?? 'fixed', courseNumber: number, passInstruction: 'Marks to port', legs: [], totalDistanceNm: 0, chartAlt: `Course ${number} layout`, status: 'draft', updatedAt: new Date().toISOString() } }
function newNotice(): NoticeToCompetitors { return { id: crypto.randomUUID(), noticeNumber: '', title: 'Notice to Competitors', series: '', appliesTo: '', issueDate: new Date().toISOString().slice(0, 10), summary: '', warningSignals: [], sections: [{ id: crypto.randomUUID(), body: '' }], issuerName: '', issuerRole: '', revision: 0, status: 'draft', updatedAt: new Date().toISOString() } }
function downloadPack(pack: AdminPack) { const url = URL.createObjectURL(new Blob([JSON.stringify(pack, null, 2)], { type: 'application/json' })); const anchor = document.createElement('a'); anchor.href = url; anchor.download = `${pack.packId}-preview.json`; anchor.click(); URL.revokeObjectURL(url) }
