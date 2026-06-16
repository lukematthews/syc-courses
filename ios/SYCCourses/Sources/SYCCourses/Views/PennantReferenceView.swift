import SwiftUI

struct PennantReferenceView: View {
    private let fixedCourses = CourseDataLoader.fixedCourses()
    private let laidCourses = CourseDataLoader.laidCourses()
    @State private var digits = ""

    private var courses: [Course] {
        fixedCourses + laidCourses
    }

    var matchedCourse: Course? {
        guard let number = Int(digits) else { return nil }
        return courses.first { $0.courseNumber == number }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 86), spacing: 12)], spacing: 12) {
                    ForEach(0...9, id: \.self) { digit in
                        Button {
                            if digits.count < 2 {
                                digits.append(String(digit))
                            }
                        } label: {
                            VStack(spacing: 8) {
                                PennantView(digit: Character(String(digit)))
                                    .frame(width: 86, height: 32)
                                Text("\(digit)")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity, minHeight: 96)
                            .background(.background)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Course Lookup")
                            .font(.headline)
                        Spacer()
                        Button("Clear") {
                            digits = ""
                        }
                        .disabled(digits.isEmpty)
                    }

                    Text(digits.isEmpty ? "Tap pennants to enter a course number." : digits)
                        .font(.system(size: digits.isEmpty ? 24 : 44, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let matchedCourse {
                        NavigationLink(value: matchedCourse) {
                            CourseCardView(course: matchedCourse)
                        }
                        .buttonStyle(.plain)
                    } else if !digits.isEmpty {
                        Text("No course \(digits).")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
        }
        .background(AppColors.groupedBackground)
        .navigationTitle("Flags")
    }
}
