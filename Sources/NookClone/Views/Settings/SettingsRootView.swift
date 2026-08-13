import SwiftUI

enum SettingsCategory: String, CaseIterable, Identifiable {
    case general = "General"
    case appearance = "Appearance"
    case widgets = "Widgets"
    case school = "School"
    case tray = "Tray"
    case gestures = "Gestures"
    case display = "Display"
    case permissions = "Permissions"
    case about = "About"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .appearance: "paintbrush"
        case .widgets: "rectangle.3.group"
        case .school: "graduationcap"
        case .tray: "tray.full"
        case .gestures: "hand.draw"
        case .display: "display"
        case .permissions: "lock.shield"
        case .about: "info.circle"
        }
    }
}

struct SettingsRootView: View {
    let environment: AppEnvironment
    @State private var selection: SettingsCategory? = .widgets

    var body: some View {
        NavigationSplitView {
            List(SettingsCategory.allCases, selection: $selection) { category in
                Label {
                    Text(LocalizedStringKey(category.rawValue))
                } icon: {
                    Image(systemName: category.systemImage)
                }
                    .tag(category)
            }
            .listStyle(.sidebar)
            .navigationTitle("Dynamic Nook")
            .navigationSplitViewColumnWidth(min: 170, ideal: 190, max: 220)
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: 940, height: 590)
        .environment(\.locale, environment.settings.appLanguage.locale)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .widgets {
        case .general:
            GeneralSettingsView(environment: environment)
        case .appearance:
            AppearanceSettingsView(settings: environment.settings)
        case .widgets:
            WidgetSettingsView(environment: environment)
        case .school:
            SchoolSettingsView(environment: environment)
        case .tray:
            TraySettingsView(environment: environment)
        case .gestures:
            GestureSettingsView(settings: environment.settings)
        case .display:
            DisplaySettingsView(environment: environment)
        case .permissions:
            PermissionsSettingsView(environment: environment)
        case .about:
            AboutSettingsView(settings: environment.settings)
        }
    }
}
