import Foundation
import XCTest
@testable import NookClone

final class WeatherTests: XCTestCase {
    func testOpenMeteoDecodingAndSnapshot() throws {
        let json = #"{"current":{"temperature_2m":21.5,"apparent_temperature":20.1,"weather_code":2},"hourly":{"time":["2026-08-12T20:00","2026-08-12T21:00"],"temperature_2m":[21.5,20.0],"precipitation_probability":[10,20],"weather_code":[2,61]}}"#
        let response = try JSONDecoder().decode(OpenMeteoResponse.self, from: Data(json.utf8))
        let snapshot = try WeatherService.makeSnapshot(response: response, locationName: "Daegu", fetchedAt: Date(timeIntervalSinceReferenceDate: 10))
        XCTAssertEqual(snapshot.temperature, 21.5)
        XCTAssertEqual(snapshot.hourly.count, 2)
        XCTAssertEqual(snapshot.precipitationProbability, 10)
    }

    func testWMOCodeMapping() {
        XCTAssertEqual(WMOWeatherCode.condition(for: 0).symbol, "sun.max.fill")
        XCTAssertEqual(WMOWeatherCode.condition(for: 61).titleKey, "Rain")
        XCTAssertEqual(WMOWeatherCode.condition(for: 95).symbol, "cloud.bolt.rain.fill")
        XCTAssertEqual(WMOWeatherCode.condition(for: 999).titleKey, "Unknown weather")
    }

    func testWeatherCacheValidity() {
        let fetched = Date(timeIntervalSinceReferenceDate: 1_000)
        XCTAssertTrue(WeatherCachePolicy.isValid(fetchedAt: fetched, now: fetched.addingTimeInterval(1_799)))
        XCTAssertFalse(WeatherCachePolicy.isValid(fetchedAt: fetched, now: fetched.addingTimeInterval(1_800)))
    }
}
