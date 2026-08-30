import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: AppStore

    var body: some View {
        Group {
            if store.hasCompletedOnboarding {
                MainTabView()
            } else {
                OnboardingView()
            }
        }
        .tint(Brand.primary)
    }
}

private struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("Heute", systemImage: "checkmark.circle.fill") }

            NavigationStack { HistoryView() }
                .tabItem { Label("Verlauf", systemImage: "clock.arrow.circlepath") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Einstellungen", systemImage: "gearshape.fill") }
        }
    }
}

private struct OnboardingView: View {
    @EnvironmentObject private var store: AppStore
    @State private var page = 0

    private let pages: [(String, LocalizedStringKey, LocalizedStringKey)] = [
        ("checkmark.seal.fill", "Nicht mehr zweimal fragen", "Ein Blick genügt: Du siehst sofort, was erledigt wurde und wann."),
        ("arrow.triangle.2.circlepath", "Bereit für den nächsten Tag", "Jede Karte wird automatisch zu dem Zeitpunkt zurückgesetzt, den du festlegst."),
        ("hand.tap.fill", "Ein Tipp. Fertig.", "Keine Projekte und keine komplizierten Listen – nur klare Gewissheit im Alltag.")
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: "F3F1FF"), .white], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()
                ZStack {
                    Circle().fill(Brand.primary.opacity(0.12)).frame(width: 142, height: 142)
                    Image(systemName: pages[page].0)
                        .font(.system(size: 62, weight: .semibold))
                        .foregroundStyle(Brand.primary)
                        .contentTransition(.symbolEffect(.replace))
                }

                VStack(spacing: 12) {
                    Text(pages[page].1)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(Brand.ink)
                        .multilineTextAlignment(.center)
                    Text(pages[page].2)
                        .font(.title3)
                        .foregroundStyle(Brand.secondaryInk)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.horizontal, 30)

                Spacer()

                HStack(spacing: 8) {
                    ForEach(0..<pages.count, id: \.self) { index in
                        Capsule()
                            .fill(index == page ? Brand.primary : Brand.border)
                            .frame(width: index == page ? 26 : 8, height: 8)
                    }
                }

                Button {
                    withAnimation(.snappy) {
                        if page < pages.count - 1 { page += 1 }
                        else { store.hasCompletedOnboarding = true }
                    }
                } label: {
                    Text(page == pages.count - 1 ? LocalizedStringKey("Loslegen") : LocalizedStringKey("Weiter"))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(Brand.primary, in: RoundedRectangle(cornerRadius: 18))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 16)
            }
        }
    }
}
