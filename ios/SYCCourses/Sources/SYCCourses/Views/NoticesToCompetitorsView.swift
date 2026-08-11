import SwiftUI

struct NoticesToCompetitorsView: View {
    private let notices = CourseDataLoader.noticesToCompetitors()

    var body: some View {
        List(notices) { notice in
            NavigationLink(value: notice) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(notice.series).font(.headline)
                    Text(notice.appliesTo).foregroundStyle(.secondary)
                    HStack {
                        Text("NTC \(notice.noticeNumber)")
                        Spacer()
                        Text(notice.issueDate)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 5)
            }
        }
        .navigationTitle("Notices to Competitors")
        .noticeNavigationTitle()
        .navigationDestination(for: NoticeToCompetitors.self) { notice in
            NoticeToCompetitorsDetailView(notice: notice)
        }
    }
}

private struct NoticeToCompetitorsDetailView: View {
    let notice: NoticeToCompetitors

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("NTC \(notice.noticeNumber) · Rev \(notice.revision)")
                        .font(.caption.bold()).foregroundStyle(.secondary)
                    Text(notice.series).font(.title2.bold()).foregroundStyle(HomeColors.navy)
                    Text("Applicable to: \(notice.appliesTo)").font(.headline)
                    Text("Issued \(notice.issueDate)").foregroundStyle(.secondary)
                }

                Text(notice.summary).font(.body)

                if !notice.warningSignals.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Warning signals").font(.headline)
                        ForEach(notice.warningSignals, id: \.self) { signal in
                            Text(signal).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12).background(Color.accentColor.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                ForEach(notice.sections, id: \.number) { section in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(section.number).").font(.headline).frame(width: 26, alignment: .trailing)
                        VStack(alignment: .leading, spacing: 6) {
                            if let heading = section.heading, !heading.isEmpty { Text(heading).font(.headline) }
                            Text(section.body)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(notice.issuerName).fontWeight(.semibold)
                    Text(notice.issuerRole)
                }

                if let pdfURL {
                    ShareLink(item: pdfURL) {
                        Label("Open or share original PDF", systemImage: "doc.richtext")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HomeColors.navy)
                }
            }
            .padding()
        }
        .background(HomeColors.background)
        .navigationTitle("Notice to Competitors")
        .noticeNavigationTitle()
    }

    private var pdfURL: URL? {
        guard let pdfFile = notice.pdfFile else { return nil }
        let url = URL(fileURLWithPath: pdfFile)
        return CourseResourceLocator.url(forResource: url.deletingPathExtension().lastPathComponent, withExtension: url.pathExtension)
    }
}

private extension View {
    @ViewBuilder
    func noticeNavigationTitle() -> some View {
        #if canImport(UIKit)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}
