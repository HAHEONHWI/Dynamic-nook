import Foundation
import Observation
import CoreFoundation

struct SchoolClassPeriod: Identifiable, Equatable, Sendable {
    let weekday: Int
    let period: Int
    let subject: String
    let teacher: String?
    let isChanged: Bool

    var id: String { "\(weekday)-\(period)" }
}

struct SchoolTimetableDay: Identifiable, Equatable, Sendable {
    let weekday: Int
    let periods: [SchoolClassPeriod]

    var id: Int { weekday }
}

enum SchoolWeekday: Int, CaseIterable, Sendable {
    case monday = 1
    case tuesday
    case wednesday
    case thursday
    case friday

    var title: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        }
    }

    var shortTitle: String {
        switch self {
        case .monday: "Mon"
        case .tuesday: "Tue"
        case .wednesday: "Wed"
        case .thursday: "Thu"
        case .friday: "Fri"
        }
    }

    static func current(at date: Date = Date(), calendar: Calendar = .current) -> Self? {
        Self(rawValue: calendar.component(.weekday, from: date) - 1)
    }
}

@MainActor
@Observable
final class SchoolTimetableService {
    private(set) var days: [SchoolTimetableDay] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func refresh(grade: Int, classNumber: Int) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let data = try await ComciTimetableClient.fetchSchoolData()
            days = try ComciTimetableParser.parse(data: data, grade: grade, classNumber: classNumber)
            errorMessage = nil
        } catch {
            days = []
            errorMessage = error.localizedDescription
        }
    }

    func timetable(for weekday: Int) -> SchoolTimetableDay? {
        days.first { $0.weekday == weekday }
    }
}

enum ComciTimetableParser {
    static func parse(data: Data, grade: Int, classNumber: Int) throws -> [SchoolTimetableDay] {
        guard (1...3).contains(grade), classNumber > 0,
              let endIndex = data.lastIndex(of: UInt8(ascii: "}")) else {
            throw SchoolTimetableError.invalidData
        }

        let jsonData = Data(data[...endIndex])
        guard let root = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            throw SchoolTimetableError.invalidData
        }

        let fields = try timetableFields(from: root)
        let codes = fields.overrideCodes ?? fields.baseCodes
        guard let gradeRows = array(at: grade, in: codes),
              let classRows = array(at: classNumber, in: gradeRows) else {
            throw SchoolTimetableError.classNotFound
        }

        return (1...5).map { weekday in
            let rawPeriods = array(at: weekday, in: classRows)?.dropFirst() ?? []
            let periods = rawPeriods.enumerated().compactMap { offset, value in
                makePeriod(
                    value,
                    weekday: weekday,
                    period: offset + 1,
                    teachers: fields.teachers,
                    subjects: fields.subjects
                )
            }
            return SchoolTimetableDay(weekday: weekday, periods: periods)
        }
    }

    private static func timetableFields(from root: [String: Any]) throws -> TimetableFields {
        var teachers: [String]?
        var subjects: [String]?
        var baseCandidates: [([Any], Int)] = []
        var overrideCandidates: [([Any], Int)] = []

        for (key, value) in root where key.hasPrefix("자료") {
            guard let array = value as? [Any] else { continue }
            let strings = array.compactMap { $0 as? String }
            if array.count > 5, array.count < 60, Double(strings.count) / Double(array.count) > 0.7 {
                if strings.contains(where: { $0.contains("*") }) {
                    teachers = array.map { $0 as? String ?? "" }
                } else if subjects == nil {
                    subjects = array.map { $0 as? String ?? "" }
                }
                continue
            }

            guard let maximumGrade = integer(array.first), (1...3).contains(maximumGrade) else { continue }
            let score = lessonCodeCount(in: array)
            guard score > 0 else { continue }
            if containsOverride(in: array) {
                overrideCandidates.append((array, score))
            } else {
                baseCandidates.append((array, score))
            }
        }

        guard let teachers, let subjects,
              let baseCodes = baseCandidates.max(by: { $0.1 < $1.1 })?.0 else {
            throw SchoolTimetableError.formatChanged
        }
        let overrideCodes = overrideCandidates.max(by: { $0.1 < $1.1 })?.0
        return TimetableFields(
            teachers: teachers,
            subjects: subjects,
            baseCodes: baseCodes,
            overrideCodes: overrideCodes
        )
    }

    private static func makePeriod(
        _ rawValue: Any,
        weekday: Int,
        period: Int,
        teachers: [String],
        subjects: [String]
    ) -> SchoolClassPeriod? {
        let value: Int?
        if let number = integer(rawValue) {
            value = number
        } else if let string = rawValue as? String {
            value = Int(string.trimmingPrefix(">"))
        } else {
            value = nil
        }

        guard let value, value > 0 else { return nil }
        let subjectIndex = value / 1_000
        let teacherIndex = value % 1_000
        guard subjects.indices.contains(subjectIndex) else { return nil }
        let subject = subjects[subjectIndex].replacingOccurrences(of: "_", with: "")
        guard !subject.isEmpty else { return nil }
        let teacher = teachers.indices.contains(teacherIndex)
            ? maskedTeacherName(teachers[teacherIndex])
            : nil
        return SchoolClassPeriod(
            weekday: weekday,
            period: period,
            subject: subject,
            teacher: teacher,
            isChanged: (rawValue as? String)?.hasPrefix(">") == true
        )
    }

    private static func maskedTeacherName(_ rawName: String) -> String? {
        let name = rawName
            .replacingOccurrences(of: "*", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return "\(name)*"
    }

    private static func array(at index: Int, in array: [Any]) -> [Any]? {
        guard array.indices.contains(index) else { return nil }
        return array[index] as? [Any]
    }

    private static func integer(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue ?? (value as? String).flatMap(Int.init)
    }

    private static func containsOverride(in value: Any) -> Bool {
        if let string = value as? String { return string.hasPrefix(">") }
        if let array = value as? [Any] { return array.contains(where: containsOverride) }
        return false
    }

    private static func lessonCodeCount(in value: Any) -> Int {
        if let number = integer(value) { return number > 100 ? 1 : 0 }
        if let string = value as? String,
           let number = Int(string.trimmingPrefix(">")) { return number > 100 ? 1 : 0 }
        if let array = value as? [Any] { return array.reduce(0) { $0 + lessonCodeCount(in: $1) } }
        return 0
    }
}

private struct TimetableFields {
    let teachers: [String]
    let subjects: [String]
    let baseCodes: [Any]
    let overrideCodes: [Any]?
}

private enum ComciTimetableClient {
    private static let schoolCode = 20_999
    private static let homeURL = URL(string: "http://xn--s39aj90b0nb2xw6xh.kr")!
    private static let koreanEUC = String.Encoding(
        rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(0x0940))
    )

    static func fetchSchoolData() async throws -> Data {
        let homeData = try await request(homeURL)
        let homeSource = String(decoding: homeData, as: UTF8.self)
        guard let frameAddress = firstCapture(
            #"(?i)<frame[^>]*src=['\"]([^'\"]+)['\"]"#,
            in: homeSource
        ), let frameURL = URL(string: frameAddress, relativeTo: homeURL)?.absoluteURL else {
            throw SchoolTimetableError.formatChanged
        }

        let frameData = try await request(frameURL)
        guard let frameSource = String(data: frameData, encoding: koreanEUC),
              let endpoint = firstCapture(#"school_ra\(sc\)[\s\S]*?url:\s*['\"]\./(\d+)\?"#, in: frameSource),
              let schoolPrefix = firstCapture(#"sc_data\('([^']+)'\s*,[^,]+,\s*\d+"#, in: frameSource),
              let requestRound = firstCapture(#"sc_data\('[^']+'\s*,[^,]+,\s*(\d+)"#, in: frameSource) else {
            throw SchoolTimetableError.formatChanged
        }

        let payload = "\(schoolPrefix)\(schoolCode)_0_\(requestRound)"
        guard let origin = URL(string: "/", relativeTo: frameURL)?.absoluteURL,
              let url = URL(string: "\(endpoint)?\(Data(payload.utf8).base64EncodedString())", relativeTo: origin)?.absoluteURL else {
            throw SchoolTimetableError.invalidRequest
        }
        return try await request(url)
    }

    private static func request(_ url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw SchoolTimetableError.invalidResponse
        }
        return data
    }

    private static func firstCapture(_ pattern: String, in source: String) -> String? {
        guard let expression = try? NSRegularExpression(pattern: pattern),
              let match = expression.firstMatch(in: source, range: NSRange(source.startIndex..., in: source)),
              let range = Range(match.range(at: 1), in: source) else { return nil }
        return String(source[range])
    }
}

private enum SchoolTimetableError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case invalidData
    case classNotFound
    case formatChanged

    var errorDescription: String? {
        switch self {
        case .invalidRequest: String(localized: "The timetable request could not be created.")
        case .invalidResponse: String(localized: "The timetable server returned an invalid response.")
        case .invalidData: String(localized: "The timetable data is invalid.")
        case .classNotFound: String(localized: "The selected class timetable was not found.")
        case .formatChanged: String(localized: "The timetable server format has changed.")
        }
    }
}

private extension String {
    func trimmingPrefix(_ prefix: Character) -> String {
        first == prefix ? String(dropFirst()) : self
    }

    var nilIfEmpty: String? { isEmpty ? nil : self }
}
