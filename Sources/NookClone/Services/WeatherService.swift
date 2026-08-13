import AppKit
import CoreLocation
import Foundation
import Observation

enum WeatherLocationState: Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

enum WeatherServiceError: LocalizedError {
    case locationNeeded
    case locationFailed
    case invalidResponse
    case invalidData

    var errorDescription: String? {
        switch self {
        case .locationNeeded: "Allow location access or enter a manual location."
        case .locationFailed: "The location could not be resolved."
        case .invalidResponse: "The weather service returned an invalid response."
        case .invalidData: "The weather data could not be read."
        }
    }
}

@MainActor
@Observable
final class WeatherService: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private(set) var snapshot: WeatherSnapshot?
    private(set) var locationState: WeatherLocationState = .notDetermined
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private var lastLocation: CLLocation?
    private var locationContinuation: CheckedContinuation<CLLocation, Error>?
    private var cachedLocationRequest: String?

    override init() {
        super.init()
        locationManager.delegate = self
        updateAuthorization()
    }

    func requestLocationAccess() {
        locationManager.requestWhenInUseAuthorization()
    }

    func refreshPermission() { updateAuthorization() }

    func refresh(manualLocation: String, force: Bool = false) async {
        let locationRequest = manualLocation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !force,
           cachedLocationRequest == locationRequest,
           let snapshot,
           WeatherCachePolicy.isValid(fetchedAt: snapshot.fetchedAt) { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let resolved = try await resolveLocation(manualLocation: manualLocation)
            let response = try await fetch(latitude: resolved.coordinate.latitude, longitude: resolved.coordinate.longitude)
            snapshot = try Self.makeSnapshot(response: response, locationName: resolved.name, fetchedAt: Date())
            cachedLocationRequest = locationRequest
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices") {
            NSWorkspace.shared.open(url)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        updateAuthorization()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        lastLocation = location
        locationContinuation?.resume(returning: location)
        locationContinuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationContinuation?.resume(throwing: error)
        locationContinuation = nil
    }

    private func resolveLocation(manualLocation: String) async throws -> (coordinate: CLLocationCoordinate2D, name: String) {
        let manual = manualLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        if locationState == .authorized {
            let location: CLLocation
            if let lastLocation { location = lastLocation }
            else {
                location = try await withCheckedThrowingContinuation { continuation in
                    locationContinuation = continuation
                    locationManager.requestLocation()
                }
            }
            let name = (try? await geocoder.reverseGeocodeLocation(location).first).flatMap {
                $0.locality ?? $0.name
            } ?? "Current Location"
            return (location.coordinate, name)
        }
        guard !manual.isEmpty else { throw WeatherServiceError.locationNeeded }
        guard let placemark = try await geocoder.geocodeAddressString(manual).first,
              let coordinate = placemark.location?.coordinate else { throw WeatherServiceError.locationFailed }
        return (coordinate, placemark.locality ?? placemark.name ?? manual)
    }

    private func fetch(latitude: Double, longitude: Double) async throws -> OpenMeteoResponse {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,apparent_temperature,weather_code"),
            URLQueryItem(name: "hourly", value: "temperature_2m,precipitation_probability,weather_code"),
            URLQueryItem(name: "forecast_hours", value: "12"),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components.url else { throw WeatherServiceError.invalidResponse }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else { throw WeatherServiceError.invalidResponse }
        return try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
    }

    nonisolated static func makeSnapshot(response: OpenMeteoResponse, locationName: String, fetchedAt: Date) throws -> WeatherSnapshot {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        let count = [
            response.hourly.time.count,
            response.hourly.temperature.count,
            response.hourly.precipitationProbability.count,
            response.hourly.weatherCode.count
        ].min() ?? 0
        let hours = (0..<count).prefix(6).compactMap { index -> WeatherHour? in
            guard let date = formatter.date(from: response.hourly.time[index]) else { return nil }
            return WeatherHour(date: date, temperature: response.hourly.temperature[index], precipitationProbability: response.hourly.precipitationProbability[index], weatherCode: response.hourly.weatherCode[index])
        }
        guard !hours.isEmpty else { throw WeatherServiceError.invalidData }
        return WeatherSnapshot(
            locationName: locationName,
            temperature: response.current.temperature,
            apparentTemperature: response.current.apparentTemperature,
            weatherCode: response.current.weatherCode,
            precipitationProbability: hours.first?.precipitationProbability ?? 0,
            hourly: hours,
            fetchedAt: fetchedAt
        )
    }

    private func updateAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined: locationState = .notDetermined
        case .authorized, .authorizedAlways: locationState = .authorized
        case .denied: locationState = .denied
        case .restricted: locationState = .restricted
        @unknown default: locationState = .denied
        }
    }
}
