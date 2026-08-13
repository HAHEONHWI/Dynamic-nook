import Foundation
import Observation

enum SchoolMealPeriod: String, CaseIterable, Sendable {
    case breakfast
    case lunch
    case dinner

    var title: String {
        switch self {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        }
    }

    var code: String {
        switch self {
        case .breakfast: "1"
        case .lunch: "2"
        case .dinner: "3"
        }
    }

    static func current(at date: Date, calendar: Calendar = .current) -> Self {
        let hour = calendar.component(.hour, from: date)
        if hour < 8 { return .breakfast }
        if hour < 14 { return .lunch }
        return .dinner
    }

    static func upcomingPair(at date: Date, calendar: Calendar = .current) -> [(period: Self, date: Date)] {
        let today = calendar.startOfDay(for: date)
        switch current(at: date, calendar: calendar) {
        case .breakfast:
            return [(.breakfast, today), (.lunch, today)]
        case .lunch:
            return [(.lunch, today), (.dinner, today)]
        case .dinner:
            let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
            return [(.dinner, today), (.breakfast, tomorrow)]
        }
    }
}

struct SchoolMeal: Identifiable, Equatable, Sendable {
    let date: Date
    let period: SchoolMealPeriod
    let dishes: [String]
    let calories: String?

    var id: String { "\(date.timeIntervalSinceReferenceDate)-\(period.rawValue)" }
}

struct SchoolScheduleItem: Identifiable, Equatable, Sendable {
    let date: Date
    let title: String
    let details: String?

    var id: String { "\(date.timeIntervalSinceReferenceDate)-\(title)" }
}

struct SchoolSearchResult: Identifiable, Equatable, Sendable {
    let educationOfficeCode: String
    let schoolCode: String
    let name: String
    let address: String

    var id: String { "\(educationOfficeCode)-\(schoolCode)" }
}

@MainActor
@Observable
final class SchoolService {
    private(set) var meals: [SchoolMeal] = []
    private(set) var schedules: [SchoolScheduleItem] = []
    private(set) var searchResults: [SchoolSearchResult] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func refresh(apiKey: String, educationOfficeCode: String, schoolCode: String, date: Date = Date()) async {
        guard !educationOfficeCode.isEmpty, !schoolCode.isEmpty else {
            meals = []
            schedules = []
            errorMessage = nil
            return
        }

        isLoading = true
        defer { isLoading = false }
        do {
            async let mealEnvelope: NEISMealEnvelope = request(
                endpoint: "mealServiceDietInfo",
                query: baseQuery(apiKey: apiKey, educationOfficeCode: educationOfficeCode, schoolCode: schoolCode) + [
                    URLQueryItem(name: "MLSV_FROM_YMD", value: Self.apiDate(date)),
                    URLQueryItem(name: "MLSV_TO_YMD", value: Self.apiDate(Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date))
                ],
                envelope: NEISMealEnvelope.self
            )
            let endDate = Calendar.current.date(byAdding: .day, value: 30, to: date) ?? date
            async let scheduleEnvelope: NEISScheduleEnvelope = request(
                endpoint: "SchoolSchedule",
                query: baseQuery(apiKey: apiKey, educationOfficeCode: educationOfficeCode, schoolCode: schoolCode) + [
                    URLQueryItem(name: "AA_FROM_YMD", value: Self.apiDate(date)),
                    URLQueryItem(name: "AA_TO_YMD", value: Self.apiDate(endDate))
                ],
                envelope: NEISScheduleEnvelope.self
            )

            let (mealsResult, schedulesResult) = try await (mealEnvelope, scheduleEnvelope)
            let mealResponse = mealsResult.mealServiceDietInfo?.flatMap { $0.row ?? [] } ?? []
            let scheduleResponse = schedulesResult.schoolSchedule?.flatMap { $0.row ?? [] } ?? []
            meals = mealResponse.compactMap(Self.makeMeal)
            schedules = scheduleResponse.compactMap(Self.makeSchedule).sorted { $0.date < $1.date }
            errorMessage = nil
        } catch {
            meals = []
            schedules = []
            errorMessage = error.localizedDescription
        }
    }

    func searchSchools(name: String, apiKey: String) async {
        let query = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let envelope: NEISSchoolEnvelope = try await request(
                endpoint: "schoolInfo",
                query: commonQuery(apiKey: apiKey) + [URLQueryItem(name: "SCHUL_NM", value: query)],
                envelope: NEISSchoolEnvelope.self
            )
            searchResults = (envelope.schoolInfo?.flatMap { $0.row ?? [] } ?? []).map {
                SchoolSearchResult(
                    educationOfficeCode: $0.educationOfficeCode,
                    schoolCode: $0.schoolCode,
                    name: $0.name,
                    address: $0.address ?? ""
                )
            }
            errorMessage = nil
        } catch {
            searchResults = []
            errorMessage = error.localizedDescription
        }
    }

    func meal(for period: SchoolMealPeriod, on date: Date = Date()) -> SchoolMeal? {
        meals.first { $0.period == period && Calendar.current.isDate($0.date, inSameDayAs: date) }
    }


    func upcomingMeals(at date: Date = Date(), calendar: Calendar = .current) -> [(period: SchoolMealPeriod, date: Date, meal: SchoolMeal?)] {
        SchoolMealPeriod.upcomingPair(at: date, calendar: calendar).map { slot in
            (slot.period, slot.date, meal(for: slot.period, on: slot.date))
        }
    }

    private func commonQuery(apiKey: String) -> [URLQueryItem] {
        var result = [
            URLQueryItem(name: "Type", value: "json"),
            URLQueryItem(name: "pIndex", value: "1"),
            URLQueryItem(name: "pSize", value: "100")
        ]
        if !apiKey.isEmpty { result.append(URLQueryItem(name: "KEY", value: apiKey)) }
        return result
    }

    private func baseQuery(apiKey: String, educationOfficeCode: String, schoolCode: String) -> [URLQueryItem] {
        commonQuery(apiKey: apiKey) + [
            URLQueryItem(name: "ATPT_OFCDC_SC_CODE", value: educationOfficeCode),
            URLQueryItem(name: "SD_SCHUL_CODE", value: schoolCode)
        ]
    }

    private func request<T: Decodable>(endpoint: String, query: [URLQueryItem], envelope: T.Type) async throws -> T {
        var components = URLComponents(string: "https://open.neis.go.kr/hub/\(endpoint)")!
        components.queryItems = query
        guard let url = components.url else { throw SchoolServiceError.invalidRequest }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw SchoolServiceError.invalidResponse
        }
        if let failure = try? JSONDecoder().decode(NEISFailureEnvelope.self, from: data),
           failure.result.code != "INFO-000" {
            if failure.result.code == "INFO-200" { return try JSONDecoder().decode(T.self, from: Data("{}".utf8)) }
            throw SchoolServiceError.api(failure.result.message)
        }
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func apiDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: date)
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter.date(from: value)
    }

    private static func makeMeal(_ row: NEISMealRow) -> SchoolMeal? {
        guard let date = parseDate(row.date),
              let period = SchoolMealPeriod.allCases.first(where: { $0.code == row.mealCode }) else { return nil }
        let dishes = row.dishes
            .replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
            .components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: "\\s*\\([0-9.]+\\)\\s*$", with: "", options: .regularExpression) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return SchoolMeal(date: date, period: period, dishes: dishes, calories: row.calories)
    }

    private static func makeSchedule(_ row: NEISScheduleRow) -> SchoolScheduleItem? {
        guard let date = parseDate(row.date) else { return nil }
        return SchoolScheduleItem(date: date, title: row.title, details: row.details)
    }
}

private enum SchoolServiceError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case api(String)

    var errorDescription: String? {
        switch self {
        case .invalidRequest: "The NEIS request could not be created."
        case .invalidResponse: "NEIS returned an invalid response."
        case .api(let message): message
        }
    }
}

private struct NEISFailureEnvelope: Decodable {
    let result: NEISResult
    enum CodingKeys: String, CodingKey { case result = "RESULT" }
}

private struct NEISResult: Decodable {
    let code: String
    let message: String
    enum CodingKeys: String, CodingKey { case code = "CODE"; case message = "MESSAGE" }
}

private struct NEISMealEnvelope: Decodable {
    let mealServiceDietInfo: [NEISMealSection]?
}

private struct NEISMealSection: Decodable { let row: [NEISMealRow]? }
private struct NEISMealRow: Decodable {
    let mealCode: String
    let date: String
    let dishes: String
    let calories: String?
    enum CodingKeys: String, CodingKey {
        case mealCode = "MMEAL_SC_CODE"; case date = "MLSV_YMD"; case dishes = "DDISH_NM"; case calories = "CAL_INFO"
    }
}

private struct NEISScheduleEnvelope: Decodable {
    let schoolSchedule: [NEISScheduleSection]?
    enum CodingKeys: String, CodingKey { case schoolSchedule = "SchoolSchedule" }
}

private struct NEISScheduleSection: Decodable { let row: [NEISScheduleRow]? }
private struct NEISScheduleRow: Decodable {
    let date: String
    let title: String
    let details: String?
    enum CodingKeys: String, CodingKey { case date = "AA_YMD"; case title = "EVENT_NM"; case details = "EVENT_CNTNT" }
}

private struct NEISSchoolEnvelope: Decodable {
    let schoolInfo: [NEISSchoolSection]?
}

private struct NEISSchoolSection: Decodable { let row: [NEISSchoolRow]? }
private struct NEISSchoolRow: Decodable {
    let educationOfficeCode: String
    let schoolCode: String
    let name: String
    let address: String?
    enum CodingKeys: String, CodingKey {
        case educationOfficeCode = "ATPT_OFCDC_SC_CODE"; case schoolCode = "SD_SCHUL_CODE"; case name = "SCHUL_NM"; case address = "ORG_RDNMA"
    }
}
