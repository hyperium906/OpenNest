//
//  Components.swift
//  OpenNest
//

import SwiftUI
import UIKit

struct GalleryJournalCard: View {
    let record: JournalRecord
    let theme: HomeTheme

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.entryDate.formatted(date: .complete, time: .omitted))
                            .font(.headline)
                            .foregroundStyle(theme.primaryText)

                        Text(record.analysis.mood == .good ? "Good day entry" : "Hard day entry")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(record.analysis.mood == .good ? theme.goodDayDot : theme.badDayDot)
                    }

                    Spacer()

                    Circle()
                        .fill(record.analysis.mood == .good ? theme.goodDayDot : theme.badDayDot)
                        .frame(width: 14, height: 14)
                }

                if !record.attachedPhotos.isEmpty {
                    photoStrip
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Full journal log")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.secondaryText)

                    Text(record.text)
                        .font(.body)
                        .foregroundStyle(theme.primaryText)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(18)
                .background(theme.controlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                HStack {
                    Label("\(record.analysis.score) score", systemImage: "chart.bar.fill")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.primaryText)

                    Spacer()

                    Text(record.analysis.harmfulTerms.isEmpty ? "No flagged terms" : record.analysis.harmfulTerms.joined(separator: ", "))
                        .font(.footnote)
                        .foregroundStyle(record.analysis.harmfulTerms.isEmpty ? theme.secondaryText : theme.alertText)
                        .multilineTextAlignment(.trailing)
                }
            }
            .padding(24)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    theme.cardFill,
                    theme.controlFill
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(theme.isDark ? 0.08 : 0.22), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.08), radius: 18, y: 12)
    }

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Attached images")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(record.attachedPhotos) { attachment in
                        JournalAttachmentThumbnail(data: attachment.imageData)
                            .frame(width: 150, height: 150)
                    }
                }
            }
        }
    }
}

struct JournalAttachmentThumbnail: View {
    let data: Data

    var body: some View {
        Group {
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.08),
                            Color.black.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )

                    Image(systemName: "photo")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(Color.black.opacity(0.35))
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct PageIndicatorView: View {
    let selectedScreen: AppScreen

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AppScreen.allCases, id: \.self) { screen in
                Capsule(style: .continuous)
                    .fill(screen == selectedScreen ? Color.white.opacity(0.95) : Color.white.opacity(0.35))
                    .frame(width: screen == selectedScreen ? 24 : 8, height: 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.black.opacity(0.12), in: Capsule(style: .continuous))
    }
}

struct BottomIslandView: View {
    let score: Int
    let needsTherapistNotification: Bool
    let detectedWordCount: Int
    let activeSafetyPing: SafetyPing?
    let theme: HomeTheme

    @Binding var selectedJournalDate: Date
    @Binding var showCalendarSheet: Bool

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(activeSafetyPing == nil ? (needsTherapistNotification ? "Safety alert" : "Daily check-in") : "Safety ping sent")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.72))

                Text(activeSafetyPing?.therapistName ?? (needsTherapistNotification ? "Therapist ping ready" : selectedJournalDate.formatted(date: .abbreviated, time: .omitted)))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer(minLength: 0)

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(detectedWordCount == 1 ? "1 flag" : "\(detectedWordCount) flags")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.72))
            }

            HStack(spacing: 10) {
                Button {
                    showCalendarSheet = true
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.isDark ? .white : theme.iconOnLightControl)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(theme.isDark ? Color.white.opacity(0.18) : theme.islandControlFill)
                        )
                }
                .buttonStyle(.plain)

                Circle()
                    .fill(needsTherapistNotification ? theme.badDayDot : theme.goodDayDot)
                    .frame(width: 14, height: 14)
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.55), lineWidth: 2)
                    }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: needsTherapistNotification
                    ? [theme.alertIslandStart, theme.alertIslandEnd]
                    : [theme.calmIslandStart, theme.calmIslandEnd],
                startPoint: .leading,
                endPoint: .trailing
            ),
            in: Capsule(style: .continuous)
        )
        .shadow(color: .black.opacity(0.16), radius: 18, y: 10)
    }
}

struct LaunchScreenView: View {
    let isVisible: Bool

    private let palette = [
        Color(red: 0.65, green: 0.67, blue: 0.62),
        Color(red: 0.94, green: 0.90, blue: 0.84),
        Color(red: 0.93, green: 0.77, blue: 0.84),
        Color(red: 0.86, green: 0.75, blue: 0.72),
        Color(red: 0.82, green: 0.67, blue: 0.63),
        Color(red: 0.60, green: 0.66, blue: 0.64)
    ]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [palette[1], palette[3], palette[5]],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                HStack(spacing: 0) {
                    ForEach(Array(palette.enumerated()), id: \.offset) { _, color in
                        Rectangle()
                            .fill(color.opacity(0.92))
                    }
                }
                .mask(RoundedRectangle(cornerRadius: 40, style: .continuous))
                .frame(width: min(geometry.size.width - 40, 360), height: 280)
                .overlay(alignment: .bottomLeading) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OPENNEST")
                            .font(.system(size: 28, weight: .bold, design: .serif))
                            .tracking(2)

                        Text("Safe reflection with therapist support.")
                            .font(.footnote.weight(.medium))
                    }
                    .foregroundStyle(Color(red: 0.19, green: 0.19, blue: 0.18))
                    .padding(24)
                }
                .shadow(color: .black.opacity(0.12), radius: 28, y: 18)
                .scaleEffect(isVisible ? 1 : 0.92)
                .opacity(isVisible ? 1 : 0)

                Circle()
                    .fill(palette[4].opacity(0.22))
                    .frame(width: 220)
                    .blur(radius: 10)
                    .offset(x: 110, y: -220)
                    .scaleEffect(isVisible ? 1 : 0.6)

                Circle()
                    .fill(palette[0].opacity(0.18))
                    .frame(width: 180)
                    .blur(radius: 14)
                    .offset(x: -120, y: 250)
                    .scaleEffect(isVisible ? 1 : 0.7)
            }
        }
        .ignoresSafeArea()
    }
}

struct TutorialWalkthroughView: View {
    private struct TutorialStep: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let symbol: String
    }

    let onFinish: () -> Void

    @State private var selectedStep = 0

    private let steps = [
        TutorialStep(
            title: "Write your daily journal",
            detail: "Capture how you are doing, add up to three images, and submit when you are ready.",
            symbol: "square.and.pencil"
        ),
        TutorialStep(
            title: "Track your calendar and history",
            detail: "Use the island calendar and gallery screens to review completed days and past entries.",
            symbol: "calendar.badge.clock"
        ),
        TutorialStep(
            title: "Escalate safety concerns",
            detail: "If a journal comes back high-risk, OpenNest can trigger a safety ping for the therapist.",
            symbol: "bell.badge.fill"
        )
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.94, green: 0.90, blue: 0.84),
                    Color(red: 0.81, green: 0.67, blue: 0.63)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Welcome to OpenNest")
                        .font(.system(size: 34, weight: .semibold, design: .serif))
                        .foregroundStyle(Color(red: 0.35, green: 0.31, blue: 0.29))

                    Text("A quick walkthrough before you start journaling live.")
                        .font(.subheadline)
                        .foregroundStyle(Color(red: 0.40, green: 0.44, blue: 0.42))
                }

                TabView(selection: $selectedStep) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        VStack(alignment: .leading, spacing: 18) {
                            Image(systemName: step.symbol)
                                .font(.system(size: 36, weight: .semibold))
                                .foregroundStyle(Color(red: 0.46, green: 0.33, blue: 0.31))
                                .frame(width: 72, height: 72)
                                .background(Color.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                            Text(step.title)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(Color(red: 0.35, green: 0.31, blue: 0.29))

                            Text(step.detail)
                                .font(.body)
                                .foregroundStyle(Color(red: 0.40, green: 0.44, blue: 0.42))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(28)
                        .background(Color.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 32, style: .continuous))
                        .padding(.vertical, 8)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
                .frame(height: 380)

                Button {
                    if selectedStep < steps.count - 1 {
                        selectedStep += 1
                    } else {
                        onFinish()
                    }
                } label: {
                    Text(selectedStep == steps.count - 1 ? "Start Using OpenNest" : "Continue")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.40, green: 0.44, blue: 0.42),
                                    Color(red: 0.60, green: 0.66, blue: 0.64)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                        )
                }
                .buttonStyle(.plain)

                Button("Skip tutorial") {
                    onFinish()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(red: 0.35, green: 0.31, blue: 0.29))
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
    }
}
