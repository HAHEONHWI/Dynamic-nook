import SwiftUI

struct MarketWidgetView: View {
    let service: MarketService
    let settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("Markets", systemImage: "chart.line.uptrend.xyaxis").font(.caption.weight(.bold))
                Spacer()
                if service.isLoading { ProgressView().controlSize(.mini) }
                Button { Task { await service.refresh(items: settings.marketItems, force: true) } } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain)
            }
            if !settings.allowMarketData {
                Spacer()
                Label("Market data is off", systemImage: "lock.shield").font(.caption).foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity)
                Button("Allow Market Data") { settings.allowMarketData = true }.buttonStyle(.plain).font(.caption2).frame(maxWidth: .infinity)
                Spacer()
            } else if service.quotes.isEmpty, !service.isLoading {
                Spacer(); Label("No market items", systemImage: "chart.line.flattrend.xyaxis").font(.caption).foregroundStyle(.white.opacity(0.5)).frame(maxWidth: .infinity); Spacer()
            } else {
                ForEach(service.quotes) { quote in
                    HStack(spacing: 7) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(quote.primaryLabel)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            if let code = quote.secondaryLabel {
                                Text(code).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                            }
                        }
                        .frame(minWidth: 105, maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(2)
                        VStack(alignment: .trailing, spacing: 0) {
                            Text(format(quote)).font(.caption.monospacedDigit()).lineLimit(1)
                            if let change = quote.change, let percent = quote.changePercent {
                                HStack(spacing: 4) {
                                    Text("\(change >= 0 ? "+" : "")\(formatChange(change))")
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.72)
                                    Text("\(percent >= 0 ? "+" : "")\(percent, specifier: "%.2f")%")
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(change >= 0 ? .red : .blue)
                            }
                        }
                        .frame(width: 116, alignment: .trailing)
                        .layoutPriority(1)
                    }
                    .padding(.horizontal, 7).frame(height: 34).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            if let error = service.errorMessage { Text(LocalizedStringKey(error)).font(.system(size: 9)).foregroundStyle(.orange).lineLimit(1) }
        }
        .task(id: "\(settings.allowMarketData)-\(settings.marketItems.map(\.id).joined(separator: ","))") {
            if settings.allowMarketData { await service.refresh(items: settings.marketItems) }
        }
    }

    private func format(_ quote: MarketQuote) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = quote.item.id.hasPrefix("fx:") ? 4 : 2
        return formatter.string(from: quote.value as NSNumber) ?? "—"
    }

    private func formatChange(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: value as NSNumber) ?? "—"
    }
}
