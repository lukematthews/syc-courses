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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    ForEach(0...9, id: \.self) { digit in
                        Button {
                            if digits.count < 2 {
                                digits.append(String(digit))
                            }
                        } label: {
                            VStack(spacing: 4) {
                                PennantView(digit: Character(String(digit)), width: 110, height: 42)
                                Text("\(digit)")
                                    .font(.headline)
                            }
                            .frame(maxWidth: .infinity, minHeight: 76)
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
