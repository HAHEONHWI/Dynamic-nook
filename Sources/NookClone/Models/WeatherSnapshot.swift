import Foundation

struct WeatherHour: Identifiable, Equatable, Sendable {
    let date: Date
    let temperature: Double
    let precipitationProbability: Int
    let weatherCode: Int
    var id: Date { date }
}

struct WeatherSnapshot: Equatable, Sendable {
    let locationName: String
    let temperature: Double
    let apparentTemperature: Double
    let weatherCode: Int
    let precipitationProbability: Int
    let hourly: [WeatherHour]
    let fetchedAt: Date
}

struct WeatherCondition: Equatable, Sendable {
    let symbol: String
    let titleKey: String
}

enum WMOWeatherCode {
    static func condition(for code: Int) -> WeatherCondition {
        switch code {
        case 0: WeatherCondition(symbol: "sun.max.fill", titleKey: "Clear sky")
        case 1: WeatherCondition(symbol: "sun.min.fill", titleKey: "Mainly clear")
        case 2: WeatherCondition(symbol: "cloud.sun.fill", titleKey: "Partly cloudy")
        case 3: WeatherCondition(symbol: "cloud.fill", titleKey: "Overcast")
        case 45, 48: WeatherCondition(symbol: "cloud.fog.fill", titleKey: "Fog")
        case 51, 53, 55, 56, 57: WeatherCondition(symbol: "cloud.drizzle.fill", titleKey: "Drizzle")
        case 61, 63, 65, 66, 67, 80, 81, 82: WeatherCondition(symbol: "cloud.rain.fill", titleKey: "Rain")
        case 71, 73, 75, 77, 85, 86: WeatherCondition(symbol: "cloud.snow.fill", titleKey: "Snow")
        case 95, 96, 99: WeatherCondition(symbol: "cloud.bolt.rain.fill", titleKey: "Thunderstorm")
        default: WeatherCondition(symbol: "cloud.fill", titleKey: "Unknown weather")
        }
    }
}

enum WeatherCachePolicy {
    static let lifetime: TimeInterval = 30 * 60
    static func isValid(fetchedAt: Date, now: Date = Date()) -> Bool {
        now.timeIntervalSince(fetchedAt) >= 0 && now.timeIntervalSince(fetchedAt) < lifetime
    }
}

struct OpenMeteoResponse: Decodable, Equatable {
    let current: Current
    let hourly: Hourly

    struct Current: Decodable, Equatable {
        let temperature: Double
        let apparentTemperature: Double
        let weatherCode: Int
        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case apparentTemperature = "apparent_temperature"
            case weatherCode = "weather_code"
        }
    }

    struct Hourly: Decodable, Equatable {
        let time: [String]
        let temperature: [Double]
        let precipitationProbability: [Int]
        let weatherCode: [Int]
        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case precipitationProbability = "precipitation_probability"
            case weatherCode = "weather_code"
        }
    }
}
