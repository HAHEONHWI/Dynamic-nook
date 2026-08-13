import SwiftUI

struct WeatherWidgetView: View {
    let service: WeatherService
    let settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(locationTitle, systemImage: "location.fill")
                    .font(.caption.weight(.bold)).lineLimit(1)
                Spacer()
                if service.isLoading { ProgressView().controlSize(.mini) }
                Button { Task { await service.refresh(manualLocation: settings.manualWeatherLocation, force: true) } } label: {
                    Image(systemName: "arrow.clockwise")
                }.buttonStyle(.plain)
            }

            if let weather = service.snapshot {
                weatherContent(weather)
            } else if service.isLoading {
                Spacer(); ProgressView().frame(maxWidth: .infinity); Spacer()
            } else if service.locationState == .notDetermined && settings.manualWeatherLocation.isEmpty {
                Spacer()
                Button("Allow Location") { service.requestLocationAccess() }.buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Spacer()
            } else {
                Spacer()
                Label("Weather unavailable", systemImage: "cloud.slash")
                    .font(.caption).foregroundStyle(.white.opacity(0.46)).frame(maxWidth: .infinity)
                if service.locationState == .denied && settings.manualWeatherLocation.isEmpty {
                    Button("Open System Settings") { service.openSystemSettings() }.buttonStyle(.plain).font(.caption2).frame(maxWidth: .infinity)
                }
                Spacer()
            }

            if let error = service.errorMessage { Text(LocalizedStringKey(error)).font(.system(size: 9)).foregroundStyle(.orange).lineLimit(1) }
        }
        .task(id: refreshKey) {
            await service.refresh(manualLocation: settings.manualWeatherLocation)
        }
    }

    private var locationTitle: LocalizedStringKey {
        guard let name = service.snapshot?.locationName else { return "Weather" }
        return LocalizedStringKey(name)
    }

    private var refreshKey: String {
        "\(settings.manualWeatherLocation)-\(String(describing: service.locationState))"
    }

    private func weatherContent(_ weather: WeatherSnapshot) -> some View {
        let condition = WMOWeatherCode.condition(for: weather.weatherCode)
        return VStack(spacing: 7) {
            HStack(spacing: 10) {
                Image(systemName: condition.symbol).font(.system(size: 30)).symbolRenderingMode(.multicolor)
                VStack(alignment: .leading, spacing: 1) {
                    Text(formatTemperature(weather.temperature)).font(.system(size: 25, weight: .bold, design: .rounded)).minimumScaleFactor(0.7)
                    Text(LocalizedStringKey(condition.titleKey)).font(.caption2).foregroundStyle(.white.opacity(0.55))
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Feels like \(formatTemperature(weather.apparentTemperature))").font(.system(size: 9))
                    Label("\(weather.precipitationProbability)%", systemImage: "drop.fill").font(.system(size: 9)).foregroundStyle(.blue)
                }.foregroundStyle(.white.opacity(0.48))
            }
            HStack(spacing: 4) {
                ForEach(weather.hourly) { hour in
                    VStack(spacing: 2) {
                        Text(hour.date, format: .dateTime.hour()).font(.system(size: 8))
                        Image(systemName: WMOWeatherCode.condition(for: hour.weatherCode).symbol).font(.system(size: 11))
                        Text(formatTemperature(hour.temperature)).font(.system(size: 8, weight: .bold)).lineLimit(1)
                        Text("\(hour.precipitationProbability)%").font(.system(size: 7)).foregroundStyle(.blue)
                    }.frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func formatTemperature(_ celsius: Double) -> String {
        let formatter = MeasurementFormatter()
        formatter.locale = settings.appLanguage.locale
        formatter.unitOptions = .temperatureWithoutUnit
        formatter.numberFormatter.maximumFractionDigits = 0
        return formatter.string(from: Measurement(value: celsius, unit: UnitTemperature.celsius))
    }
}
