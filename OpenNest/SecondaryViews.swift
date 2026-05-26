//
//  SecondaryViews.swift
//  OpenNest
//

import SwiftUI

struct ProgressHubView: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: JournalViewModel

    private var theme: HomeTheme {
        HomeTheme(colorScheme: colorScheme, isAlerting: viewModel.needsTherapistNotification)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundBottom, theme.backgroundTop],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Progress Hub")
                            .font(.system(size: 36, weight: .semibold, design: .serif))
                            .foregroundStyle(theme.primaryText)

                        Text("Swipe back right to return to your journal.")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)
                    }

                    metricCard(
                        title: "Entries Logged",
                        value: "\(viewModel.journalRecords.count)",
                        detail: "Tracked journal submissions in your timeline."
                    )

                    metricCard(
                        title: "Current Mood Trend",
                        value: currentMoodTrend,
                        detail: viewModel.journalRecords.isEmpty ? "Your trend will update after your first submitted journal." : "Based on the latest backend analysis and completed journal dates."
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Journal Activity")
                            .font(.headline)
                            .foregroundStyle(theme.primaryText)

                        if viewModel.journalRecords.isEmpty {
                            emptyStateCard(
                                title: "No activity yet",
                                detail: "Submit your first journal entry to start building a live history for you and your therapist."
                            )
                        } else {
                            ForEach(viewModel.journalRecords.sorted(by: { $0.entryDate > $1.entryDate }).prefix(4)) { record in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle()
                                        .fill(record.analysis.mood == .good ? theme.goodDayDot : theme.badDayDot)
                                        .frame(width: 12, height: 12)
                                        .padding(.top, 6)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.entryDate.formatted(date: .abbreviated, time: .omitted))
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(theme.primaryText)

                                        Text(record.analysis.summary)
                                            .font(.footnote)
                                            .foregroundStyle(theme.secondaryText)
                                            .lineLimit(3)
                                    }

                                    Spacer()
                                }
                                .padding(16)
                                .background(theme.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 72)
                .padding(.bottom, 120)
            }
        }
    }

    private func metricCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.primaryText)

            Text(value)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(theme.primaryText)

            Text(detail)
                .font(.footnote)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(20)
        .background(theme.cardFill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private var currentMoodTrend: String {
        guard let latestRecord = viewModel.latestRecord else { return "No journals yet" }
        return latestRecord.analysis.mood == .good ? "Good day" : "Hard day"
    }

    private func emptyStateCard(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.primaryText)

            Text(detail)
                .font(.footnote)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(18)
        .background(theme.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct JournalGalleryView: View {
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject var viewModel: JournalViewModel
    @State private var selectedRecordID: JournalRecord.ID?

    private var theme: HomeTheme {
        HomeTheme(colorScheme: colorScheme, isAlerting: viewModel.needsTherapistNotification)
    }

    private var sortedRecords: [JournalRecord] {
        viewModel.journalRecords.sorted(by: { $0.entryDate > $1.entryDate })
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [theme.backgroundTop, theme.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Journal Gallery")
                            .font(.system(size: 36, weight: .semibold, design: .serif))
                            .foregroundStyle(theme.primaryText)

                        Text("Swipe through past entries like a photo carousel.")
                            .font(.subheadline)
                            .foregroundStyle(theme.secondaryText)

                        if !sortedRecords.isEmpty {
                            journalEntryDropdown
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, geometry.safeAreaInsets.top + 24)

                    if sortedRecords.isEmpty {
                        emptyGalleryState
                            .padding(.horizontal, 24)
                            .padding(.bottom, geometry.safeAreaInsets.bottom + 72)
                    } else {
                        TabView(selection: $selectedRecordID) {
                            ForEach(sortedRecords) { record in
                                GalleryJournalCard(record: record, theme: theme)
                                    .padding(.horizontal, 4)
                                    .padding(.bottom, geometry.safeAreaInsets.bottom + 72)
                                    .tag(Optional(record.id))
                            }
                        }
                        .frame(height: geometry.size.height - geometry.safeAreaInsets.top - geometry.safeAreaInsets.bottom - 70)
                        .tabViewStyle(.page(indexDisplayMode: .never))
                    }

                    Spacer(minLength: 0)
                }
            }
        }
        .task {
            selectedRecordID = sortedRecords.first?.id
        }
    }

    private var journalEntryDropdown: some View {
        Picker("Choose Entry", selection: $selectedRecordID) {
            ForEach(sortedRecords) { record in
                Text(record.entryDate.formatted(date: .abbreviated, time: .omitted))
                    .tag(Optional(record.id))
            }
        }
        .pickerStyle(.menu)
        .tint(theme.primaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(theme.controlFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var emptyGalleryState: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("No saved journal entries")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.primaryText)

            Text("Once you submit entries, they will appear here as a live gallery of your past reflections.")
                .font(.subheadline)
                .foregroundStyle(theme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(24)
        .background(theme.cardFill, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
    }
}

struct CalendarSheetView: View {
    @Binding var selectedJournalDate: Date
    let journalDayStatuses: [JournalDayStatus]
    let theme: HomeTheme

    @State private var displayedMonth = Date()

    private let calendar = Calendar.current
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var daysInMonth: [CalendarDay] {
        guard
            let monthInterval = calendar.dateInterval(of: .month, for: displayedMonth),
            let firstWeekInterval = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start),
            let lastMomentInMonth = calendar.date(byAdding: DateComponents(second: -1), to: monthInterval.end),
            let lastWeekInterval = calendar.dateInterval(of: .weekOfMonth, for: lastMomentInMonth)
        else {
            return []
        }

        let visibleInterval = DateInterval(start: firstWeekInterval.start, end: lastWeekInterval.end)
        var days: [CalendarDay] = []
        var cursor = visibleInterval.start

        while cursor < visibleInterval.end {
            let isInDisplayedMonth = calendar.isDate(cursor, equalTo: displayedMonth, toGranularity: .month)
            let mood = journalDayStatuses.first(where: { calendar.isDate($0.date, inSameDayAs: cursor) })?.mood
            days.append(
                CalendarDay(
                    date: cursor,
                    dayNumber: calendar.component(.day, from: cursor),
                    isInDisplayedMonth: isInDisplayedMonth,
                    mood: mood
                )
            )

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = nextDay
        }

        return days
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Journal Calendar")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(theme.primaryText)

                    Text("Completed days show a mood dot from the analyzed journal result.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }

                VStack(spacing: 16) {
                    HStack {
                        Button {
                            guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: displayedMonth) else { return }
                            displayedMonth = previousMonth
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(theme.primaryText)
                                .frame(width: 36, height: 36)
                                .background(theme.controlFill, in: Circle())
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Text(monthTitle)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(theme.primaryText)

                        Spacer()

                        Button {
                            guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: displayedMonth) else { return }
                            displayedMonth = nextMonth
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(theme.primaryText)
                                .frame(width: 36, height: 36)
                                .background(theme.controlFill, in: Circle())
                        }
                        .buttonStyle(.plain)
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 7), spacing: 12) {
                        ForEach(weekdaySymbols, id: \.self) { symbol in
                            Text(symbol)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(theme.secondaryText)
                                .frame(maxWidth: .infinity)
                        }

                        ForEach(daysInMonth) { day in
                            Button {
                                selectedJournalDate = day.date
                            } label: {
                                VStack(spacing: 6) {
                                    Text("\(day.dayNumber)")
                                        .font(.subheadline.weight(calendar.isDate(day.date, inSameDayAs: selectedJournalDate) ? .bold : .medium))
                                        .foregroundStyle(dayTextColor(for: day))

                                    Circle()
                                        .fill(dotColor(for: day))
                                        .frame(width: 8, height: 8)
                                        .opacity(day.mood == nil ? 0 : 1)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .padding(.vertical, 8)
                                .background(dayBackground(for: day), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .disabled(!day.isInDisplayedMonth)
                        }
                    }

                    HStack(spacing: 18) {
                        Label {
                            Text("Good day")
                                .foregroundStyle(theme.secondaryText)
                        } icon: {
                            Circle()
                                .fill(theme.goodDayDot)
                                .frame(width: 10, height: 10)
                        }
                        .font(.footnote.weight(.medium))

                        Label {
                            Text("Hard day")
                                .foregroundStyle(theme.secondaryText)
                        } icon: {
                            Circle()
                                .fill(theme.badDayDot)
                                .frame(width: 10, height: 10)
                        }
                        .font(.footnote.weight(.medium))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(16)
                .background(theme.cardFill, in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                HStack {
                    Text("Selected")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(theme.secondaryText)

                    Spacer()

                    Text(selectedJournalDate.formatted(date: .complete, time: .omitted))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                }
                .padding(18)
                .background(theme.controlFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.sheetBackground.ignoresSafeArea())
        }
    }

    private func dayTextColor(for day: CalendarDay) -> Color {
        guard day.isInDisplayedMonth else { return theme.secondaryText.opacity(0.35) }
        return calendar.isDate(day.date, inSameDayAs: selectedJournalDate) ? theme.selectedDayText : theme.primaryText
    }

    private func dayBackground(for day: CalendarDay) -> Color {
        guard day.isInDisplayedMonth else { return .clear }
        return calendar.isDate(day.date, inSameDayAs: selectedJournalDate) ? theme.selectedDayFill : theme.controlFill.opacity(0.75)
    }

    private func dotColor(for day: CalendarDay) -> Color {
        switch day.mood {
        case .good:
            return theme.goodDayDot
        case .bad:
            return theme.badDayDot
        case nil:
            return .clear
        }
    }
}

struct ProfileSheetView: View {
    @ObservedObject var viewModel: JournalViewModel
    let theme: HomeTheme
    @State private var showSettingsSheet = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Profile")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(theme.primaryText)

                    Text("Manage your account details and therapist connection.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }

                VStack(spacing: 14) {
                    ProfileFieldCard(title: "User's name", text: $viewModel.userName, theme: theme)
                    ProfileFieldCard(title: "Email", text: $viewModel.email, theme: theme)
                    ProfileSecureFieldCard(title: "Password", text: $viewModel.password, theme: theme)
                    ProfileFieldCard(title: "Therapist", text: $viewModel.therapistName, theme: theme)
                }

                if let profileStatusMessage = viewModel.profileStatusMessage {
                    statusCard(
                        message: profileStatusMessage,
                        isError: viewModel.profileStatusIsError
                    )
                } else if !viewModel.canSaveProfile {
                    statusCard(
                        message: viewModel.profileValidationErrors.first ?? "Complete your profile details.",
                        isError: true
                    )
                }

                Button {
                    viewModel.saveProfile()
                } label: {
                    Text("Save Profile")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
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

                Button {
                    showSettingsSheet = true
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.cardFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    viewModel.logOut()
                } label: {
                    Text("Log Out")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.isDark ? .white : theme.alertText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            theme.isDark ? theme.alertIslandStart.opacity(0.85) : theme.alertFill,
                            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
                        )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.sheetBackground.ignoresSafeArea())
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheetView(theme: theme)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private func statusCard(message: String, isError: Bool) -> some View {
        Label(message, systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            .font(.footnote.weight(.medium))
            .foregroundStyle(isError ? theme.alertText : theme.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background((isError ? theme.alertFill.opacity(0.75) : theme.cardFill), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

struct ProfileFieldCard: View {
    let title: String
    @Binding var text: String
    let theme: HomeTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            TextField("", text: $text)
                .foregroundStyle(theme.primaryText)
                .textInputAutocapitalization(title == "Email" ? .never : .words)
                .autocorrectionDisabled(title == "Email")
        }
        .padding(18)
        .background(theme.cardFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct ProfileSecureFieldCard: View {
    let title: String
    @Binding var text: String
    let theme: HomeTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(theme.secondaryText)

            SecureField("", text: $text)
                .foregroundStyle(theme.primaryText)
        }
        .padding(18)
        .background(theme.cardFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

struct SettingsSheetView: View {
    let theme: HomeTheme

    @AppStorage("hasCompletedOnboardingTutorial") private var hasCompletedOnboardingTutorial = true
    @AppStorage("settingsSafetyAlertsEnabled") private var settingsSafetyAlertsEnabled = true
    @AppStorage("settingsDailyReminderEnabled") private var settingsDailyReminderEnabled = true
    @AppStorage("settingsDarkModeFollowsSystem") private var settingsDarkModeFollowsSystem = true

    @State private var settingsMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Settings")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(theme.primaryText)

                    Text("Tune the beta experience before you connect the full backend.")
                        .font(.subheadline)
                        .foregroundStyle(theme.secondaryText)
                }

                VStack(spacing: 14) {
                    settingsToggleRow(
                        title: "Safety alerts",
                        detail: "Keep therapist-facing safety escalation enabled in the app UI.",
                        isOn: $settingsSafetyAlertsEnabled
                    )

                    settingsToggleRow(
                        title: "Daily reminder",
                        detail: "Leave journal reminder behavior enabled for the beta build.",
                        isOn: $settingsDailyReminderEnabled
                    )

                    settingsToggleRow(
                        title: "Follow system appearance",
                        detail: "Continue matching the device light and dark mode automatically.",
                        isOn: $settingsDarkModeFollowsSystem
                    )
                }

                Button {
                    hasCompletedOnboardingTutorial = false
                    settingsMessage = "Tutorial will appear the next time the app launches."
                } label: {
                    Label("Replay Tutorial Next Launch", systemImage: "sparkles.rectangle.stack")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(theme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(theme.cardFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)

                if let settingsMessage {
                    Label(settingsMessage, systemImage: "info.circle.fill")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(theme.secondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(theme.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Simulator Test Cases")
                        .font(.headline)
                        .foregroundStyle(theme.primaryText)

                    ForEach(SimulatorTestCase.allCases) { testCase in
                        Button {
                            runSimulatorTest(testCase)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(testCase.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(theme.primaryText)

                                Text(testCase.detail)
                                    .font(.footnote)
                                    .foregroundStyle(theme.secondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(theme.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }

                Spacer()
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.sheetBackground.ignoresSafeArea())
        }
    }

    private func settingsToggleRow(title: String, detail: String, isOn: Binding<Bool>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(title, isOn: isOn)
                .font(.headline)
                .tint(theme.calmAccent)
                .foregroundStyle(theme.primaryText)

            Text(detail)
                .font(.footnote)
                .foregroundStyle(theme.secondaryText)
        }
        .padding(18)
        .background(theme.cardFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func runSimulatorTest(_ testCase: SimulatorTestCase) {
        NotificationCenter.default.post(
            name: .runSimulatorTestCase,
            object: testCase
        )
        settingsMessage = "\(testCase.title) loaded into the app."
    }
}

extension Notification.Name {
    static let runSimulatorTestCase = Notification.Name("runSimulatorTestCase")
}
