//
//  HomeView.swift
//  OpenNest
//

import PhotosUI
import SwiftUI

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isJournalEditorFocused: Bool

    @ObservedObject var viewModel: JournalViewModel

    @State private var showCalendarSheet = false
    @State private var showProfileSheet = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    private var theme: HomeTheme {
        HomeTheme(colorScheme: colorScheme, isAlerting: viewModel.needsTherapistNotification)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [theme.backgroundTop, theme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    journalComposer
                    if let activeSafetyPing = viewModel.activeSafetyPing {
                        safetyAlertCard(activeSafetyPing)
                    }
                    scoreCard
                    if let summary = viewModel.displayedRecord?.analysis.summary {
                        summaryCard(summary: summary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 72)
                .padding(.bottom, 168)
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                isJournalEditorFocused = false
            }

            BottomIslandView(
                score: viewModel.wellnessScore,
                needsTherapistNotification: viewModel.needsTherapistNotification,
                detectedWordCount: viewModel.detectedWords.count,
                activeSafetyPing: viewModel.activeSafetyPing,
                theme: theme,
                selectedJournalDate: $viewModel.selectedJournalDate,
                showCalendarSheet: $showCalendarSheet
            )
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: $showCalendarSheet) {
            CalendarSheetView(
                selectedJournalDate: $viewModel.selectedJournalDate,
                journalDayStatuses: viewModel.journalDayStatuses,
                theme: theme
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showProfileSheet) {
            ProfileSheetView(viewModel: viewModel, theme: theme)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()

                Button("Done") {
                    isJournalEditorFocused = false
                }
            }
        }
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task {
                await loadSelectedPhotos(from: newItems)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .runSimulatorTestCase)) { notification in
            guard let testCase = notification.object as? SimulatorTestCase else { return }
            viewModel.runSimulatorTestCase(testCase)
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("OpenNest")
                    .font(.system(size: 36, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.primaryText)

                Text("Therapist-supported journaling that flags high-risk entries early.")
                    .font(.subheadline)
                    .foregroundStyle(theme.secondaryText)
            }

            Spacer(minLength: 16)

            Button {
                showProfileSheet = true
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(theme.primaryText)
                    .frame(width: 46, height: 46)
                    .background(theme.controlFill, in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var journalComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Today's journal")
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)

                Spacer()
            }

            HStack(spacing: 12) {
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 3,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Label("Add Images", systemImage: "photo.on.rectangle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(theme.controlFill, in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)

                Text("\(viewModel.selectedPhotos.count)/3 photos")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(theme.secondaryText)

                Spacer()
            }

            if !viewModel.selectedPhotos.isEmpty {
                selectedPhotoStrip
            }

            if let photoSelectionStatusMessage = viewModel.photoSelectionStatusMessage {
                Label(photoSelectionStatusMessage, systemImage: viewModel.photoSelectionStatusIsError ? "exclamationmark.triangle.fill" : "photo.badge.checkmark")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(viewModel.photoSelectionStatusIsError ? theme.alertText : theme.secondaryText)
            }

            TextEditor(text: $viewModel.journalEntry)
                .focused($isJournalEditorFocused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 150)
                .padding(14)
                .background(theme.editorFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(alignment: .topLeading) {
                    if viewModel.journalEntry.isEmpty {
                        Text("Write what came up today. This entry will be analyzed after you submit it.")
                            .font(.body)
                            .foregroundStyle(theme.secondaryText.opacity(0.75))
                            .padding(.horizontal, 20)
                            .padding(.vertical, 22)
                            .allowsHitTesting(false)
                    }
                }

            Button {
                Task {
                    await viewModel.submitJournal()
                }
            } label: {
                HStack(spacing: 10) {
                    if viewModel.isSubmitting {
                        ProgressView()
                            .tint(.white)
                    }

                    Text(viewModel.isSubmitting ? "Submitting..." : "Submit Journal")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [theme.calmIslandStart, theme.calmIslandEnd],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSubmitJournal)

            HStack {
                if let statusMessage = viewModel.submissionStatusMessage {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(statusMessage, systemImage: viewModel.submissionStatusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(viewModel.submissionStatusIsError ? theme.alertText : theme.secondaryText)

                        if viewModel.submissionStatusIsError {
                            Button("Try Again") {
                                Task {
                                    await viewModel.submitJournal()
                                }
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(theme.primaryText)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(theme.controlFill, in: Capsule(style: .continuous))
                            .buttonStyle(.plain)
                        }
                    }
                } else if viewModel.journalEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Add a few sentences before submitting.")
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)
                } else {
                    Text("Submit sends this entry through your backend/Gemini analysis flow.")
                        .font(.footnote)
                        .foregroundStyle(theme.secondaryText)
                }

                Spacer()
            }
        }
    }

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Daily wellness score")
                    .font(.headline)
                    .foregroundStyle(theme.primaryText)

                Spacer()

                Text("\(viewModel.wellnessScore)")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.primaryText)
            }

            ProgressView(value: Double(max(viewModel.wellnessScore, 0)), total: 100)
                .tint(viewModel.needsTherapistNotification ? theme.alertAccent : theme.calmAccent)

            if viewModel.detectedWords.isEmpty {
                Text(viewModel.displayedRecord == nil ? "Submit a journal to start generating live score data." : "No high-risk language detected in the selected journal entry.")
                    .font(.footnote)
                    .foregroundStyle(theme.secondaryText)
            } else {
                Text("Detected language: \(viewModel.detectedWords.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(theme.alertText)
            }

            if let record = viewModel.displayedRecord {
                HStack {
                    Text("Analyzed")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(theme.secondaryText)

                    Spacer()

                    Text(record.entryDate.formatted(date: .abbreviated, time: .shortened))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                }
            }
        }
        .padding(20)
        .background(theme.cardFill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var selectedPhotoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(viewModel.selectedPhotos) { attachment in
                    JournalAttachmentThumbnail(data: attachment.imageData)
                        .frame(width: 92, height: 92)
                }
            }
        }
    }

    private func loadSelectedPhotos(from items: [PhotosPickerItem]) async {
        var attachments: [JournalPhotoAttachment] = []
        var failedItemCount = 0

        for item in items.prefix(3) {
            if let data = try? await item.loadTransferable(type: Data.self) {
                attachments.append(JournalPhotoAttachment(imageData: data))
            } else {
                failedItemCount += 1
            }
        }

        await MainActor.run {
            viewModel.updateSelectedPhotos(attachments)
            if failedItemCount > 0 {
                viewModel.setPhotoSelectionError("Some photos could not be loaded. Try selecting them again.")
            } else if !attachments.isEmpty {
                viewModel.clearPhotoSelectionStatus()
            }
        }
    }

    private func safetyAlertCard(_ ping: SafetyPing) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Label("Safety Ping Triggered", systemImage: "bell.badge.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    viewModel.dismissSafetyPing()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.18), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Text(ping.notificationSent ? "This journal was flagged as high-risk and sent to \(ping.therapistName) for therapist review." : "This journal was flagged as high-risk, but therapist delivery was not confirmed. Try again or contact support.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.94))

            HStack {
                Text("Score \(ping.score)")
                    .font(.footnote.weight(.semibold))

                Spacer()

                Text("Sent \(ping.sentAt.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.88))

            if !ping.flaggedTerms.isEmpty {
                Text("Flagged language: \(ping.flaggedTerms.joined(separator: ", "))")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.82))
            }
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [theme.alertIslandStart, theme.alertIslandEnd],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .shadow(color: .black.opacity(0.12), radius: 16, y: 10)
    }

    private func summaryCard(summary: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Backend Summary")
                .font(.headline)
                .foregroundStyle(theme.primaryText)

            Text(summary)
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(20)
        .background(theme.cardFill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}
