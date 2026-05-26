//
//  ContentView.swift
//  OpenNest
//
//  Created by Joshua Dupati on 3/29/26.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("hasCompletedOnboardingTutorial") private var hasCompletedOnboardingTutorial = false
    @StateObject private var viewModel: JournalViewModel
    @State private var showLaunchScreen = true
    @State private var launchScreenVisible = false
    @State private var showTutorial = false
    @State private var selectedScreen: AppScreen = .journal

    init(viewModel: JournalViewModel = JournalViewModel(service: BackendJournalService(endpoint: AppConfiguration.journalAnalysisEndpoint))) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ZStack {
            TabView(selection: $selectedScreen) {
                HomeView(viewModel: viewModel)
                    .tag(AppScreen.journal)

                ProgressHubView(viewModel: viewModel)
                    .tag(AppScreen.progress)

                JournalGalleryView(viewModel: viewModel)
                    .tag(AppScreen.gallery)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            .overlay(alignment: .bottom) {
                PageIndicatorView(selectedScreen: selectedScreen)
                    .padding(.bottom, 8)
            }
            .opacity(showLaunchScreen ? 0 : 1)

            if showLaunchScreen {
                LaunchScreenView(isVisible: launchScreenVisible)
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .fullScreenCover(isPresented: $showTutorial) {
            TutorialWalkthroughView {
                hasCompletedOnboardingTutorial = true
                showTutorial = false
            }
        }
        .task {
            guard showLaunchScreen else { return }

            withAnimation(.easeOut(duration: 0.7)) {
                launchScreenVisible = true
            }

            try? await Task.sleep(for: .seconds(1.8))

            withAnimation(.easeInOut(duration: 0.6)) {
                showLaunchScreen = false
            }

            if !hasCompletedOnboardingTutorial {
                try? await Task.sleep(for: .milliseconds(250))
                showTutorial = true
            }
        }
    }
}

enum AppConfiguration {
    static let journalAnalysisEndpoint = URL(string: "http://127.0.0.1:3000/api/analyze-journal")!
}

#Preview {
    ContentView(viewModel: JournalViewModel(service: MockGeminiJournalService()))
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    ContentView(viewModel: JournalViewModel(service: MockGeminiJournalService()))
        .preferredColorScheme(.dark)
}
