//
//  JournalModels.swift
//  OpenNest
//

import Combine
import Foundation
import SwiftUI

final class JournalViewModel: ObservableObject {
    @Published var journalEntry: String
    @Published var selectedPhotos: [JournalPhotoAttachment]
    @Published var selectedJournalDate: Date
    @Published var userName: String
    @Published var email: String
    @Published var password: String
    @Published var therapistName: String
    @Published var isSubmitting = false
    @Published var submissionStatusMessage: String?
    @Published var submissionStatusIsError = false
    @Published var profileStatusMessage: String?
    @Published var profileStatusIsError = false
    @Published var photoSelectionStatusMessage: String?
    @Published var photoSelectionStatusIsError = false
    @Published private(set) var activeSafetyPing: SafetyPing?
    @Published private(set) var journalRecords: [JournalRecord]

    private let service: any JournalAnalyzing
    private let calendar = Calendar.current

    init(service: any JournalAnalyzing) {
        self.service = service

        journalEntry = ""
        selectedPhotos = []
        selectedJournalDate = Date()
        userName = ""
        email = ""
        password = ""
        therapistName = ""
        journalRecords = []
        activeSafetyPing = nil
        profileStatusMessage = nil
        profileStatusIsError = false
        photoSelectionStatusMessage = nil
        photoSelectionStatusIsError = false
    }

    var displayedRecord: JournalRecord? {
        journalRecords.first(where: { calendar.isDate($0.entryDate, inSameDayAs: selectedJournalDate) }) ?? latestRecord
    }

    var latestRecord: JournalRecord? {
        journalRecords.sorted(by: { $0.entryDate < $1.entryDate }).last
    }

    var wellnessScore: Int {
        displayedRecord?.analysis.score ?? 0
    }

    var detectedWords: [String] {
        displayedRecord?.analysis.harmfulTerms ?? []
    }

    var needsTherapistNotification: Bool {
        displayedRecord?.analysis.therapistAlert ?? false
    }

    var journalDayStatuses: [JournalDayStatus] {
        journalRecords.map { JournalDayStatus(date: $0.entryDate, mood: $0.analysis.mood) }
    }

    var canSubmitJournal: Bool {
        !journalEntry.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    var canSaveProfile: Bool {
        profileValidationErrors.isEmpty
    }

    var profileValidationErrors: [String] {
        var errors: [String] = []

        if userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Add your name.")
        }

        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedEmail.isEmpty {
            errors.append("Add your email.")
        } else if !Self.isValidEmail(trimmedEmail) {
            errors.append("Enter a valid email address.")
        }

        if password.count < 8 {
            errors.append("Password must be at least 8 characters.")
        }

        if therapistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Add your therapist.")
        }

        return errors
    }

    func updateSelectedPhotos(_ photos: [JournalPhotoAttachment]) {
        selectedPhotos = Array(photos.prefix(3))
        if !selectedPhotos.isEmpty {
            photoSelectionStatusMessage = nil
            photoSelectionStatusIsError = false
        }
    }

    func setPhotoSelectionError(_ message: String) {
        photoSelectionStatusMessage = message
        photoSelectionStatusIsError = true
    }

    func clearPhotoSelectionStatus() {
        photoSelectionStatusMessage = nil
        photoSelectionStatusIsError = false
    }

    func submitJournal() async {
        let trimmedEntry = journalEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEntry.isEmpty else {
            submissionStatusMessage = "Write a journal entry before submitting."
            submissionStatusIsError = true
            return
        }

        isSubmitting = true
        submissionStatusMessage = nil
        submissionStatusIsError = false

        let request = JournalSubmissionRequest(
            entryText: trimmedEntry,
            entryDate: selectedJournalDate,
            attachedPhotoCount: selectedPhotos.count,
            userName: userName,
            therapistName: therapistName,
            locale: Locale.current.identifier,
            region: Locale.current.region?.identifier ?? "US"
        )

        do {
            let analysis = try await service.analyze(request)
            let newRecord = JournalRecord(
                entryDate: request.entryDate,
                text: request.entryText,
                attachedPhotos: selectedPhotos,
                analysis: analysis,
                therapistPingSentAt: analysis.therapistAlert ? Date() : nil
            )
            journalRecords.removeAll { calendar.isDate($0.entryDate, inSameDayAs: request.entryDate) }
            journalRecords.append(newRecord)
            if analysis.therapistAlert {
                activeSafetyPing = SafetyPing(
                    therapistName: therapistName,
                    score: analysis.score,
                    sentAt: newRecord.therapistPingSentAt ?? Date(),
                    flaggedTerms: analysis.harmfulTerms,
                    notificationSent: analysis.therapistNotificationSent
                )
                submissionStatusMessage = analysis.therapistNotificationSent
                    ? "Safety ping sent to \(therapistName)."
                    : "Analysis flagged this entry, but therapist notification was not confirmed."
                submissionStatusIsError = !analysis.therapistNotificationSent
            } else {
                activeSafetyPing = nil
                submissionStatusMessage = "Submitted. Backend analysis completed successfully."
                submissionStatusIsError = false
            }
            selectedPhotos = []
        } catch {
            submissionStatusMessage = error.localizedDescription
            submissionStatusIsError = true
        }

        isSubmitting = false
    }

    func logOut() {
        journalEntry = ""
        selectedPhotos = []
        activeSafetyPing = nil
        submissionStatusMessage = "Logged out locally."
        submissionStatusIsError = false
        profileStatusMessage = nil
        profileStatusIsError = false
        photoSelectionStatusMessage = nil
        photoSelectionStatusIsError = false
    }

    func dismissSafetyPing() {
        activeSafetyPing = nil
    }

    func saveProfile() {
        let errors = profileValidationErrors
        guard errors.isEmpty else {
            profileStatusMessage = errors.first
            profileStatusIsError = true
            return
        }

        userName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        therapistName = therapistName.trimmingCharacters(in: .whitespacesAndNewlines)
        profileStatusMessage = "Profile details saved locally."
        profileStatusIsError = false
    }

    func runSimulatorTestCase(_ testCase: SimulatorTestCase) {
        let entryDate = Date()
        let request = JournalSubmissionRequest(
            entryText: testCase.entryText,
            entryDate: entryDate,
            attachedPhotoCount: 0,
            userName: resolvedUserName,
            therapistName: resolvedTherapistName,
            locale: Locale.current.identifier,
            region: Locale.current.region?.identifier ?? "US"
        )

        var analysis = MockGeminiJournalService.previewAnalysis(for: request)
        switch testCase {
        case .lowWellnessAlert:
            analysis = JournalAnalysisResult(
                score: 22,
                harmfulTerms: ["hopeless", "overwhelmed", "isolated"],
                summary: "High distress markers detected. Escalate for therapist review.",
                therapistAlert: true,
                mood: .bad,
                language: request.locale.languageCodeFallback,
                region: request.region,
                therapistNotificationSent: true
            )
        case .stableEntry:
            analysis = JournalAnalysisResult(
                score: 86,
                harmfulTerms: [],
                summary: "Stable tone with no immediate escalation markers.",
                therapistAlert: false,
                mood: .good,
                language: request.locale.languageCodeFallback,
                region: request.region,
                therapistNotificationSent: false
            )
        case .notificationFailure:
            analysis = JournalAnalysisResult(
                score: 28,
                harmfulTerms: ["alone", "hopeless"],
                summary: "Distress markers detected, but therapist delivery was not confirmed.",
                therapistAlert: true,
                mood: .bad,
                language: request.locale.languageCodeFallback,
                region: request.region,
                therapistNotificationSent: false
            )
        }

        let record = JournalRecord(
            entryDate: entryDate,
            text: testCase.entryText,
            attachedPhotos: [],
            analysis: analysis,
            therapistPingSentAt: analysis.therapistAlert ? Date() : nil
        )

        journalEntry = testCase.entryText
        selectedJournalDate = entryDate
        journalRecords.removeAll { calendar.isDate($0.entryDate, inSameDayAs: entryDate) }
        journalRecords.append(record)

        if analysis.therapistAlert {
            activeSafetyPing = SafetyPing(
                therapistName: resolvedTherapistName,
                score: analysis.score,
                sentAt: Date(),
                flaggedTerms: analysis.harmfulTerms,
                notificationSent: analysis.therapistNotificationSent
            )
            submissionStatusMessage = analysis.therapistNotificationSent
                ? "Simulator test triggered a safety ping."
                : "Simulator test flagged the entry, but therapist delivery failed."
            submissionStatusIsError = !analysis.therapistNotificationSent
        } else {
            activeSafetyPing = nil
            submissionStatusMessage = "Simulator test created a stable journal result."
            submissionStatusIsError = false
        }
    }

    private static func isValidEmail(_ email: String) -> Bool {
        let parts = email.split(separator: "@")
        guard parts.count == 2 else { return false }
        return parts[1].contains(".")
    }

    private var resolvedUserName: String {
        userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Test User" : userName
    }

    private var resolvedTherapistName: String {
        therapistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Assigned Therapist" : therapistName
    }
}

protocol JournalAnalyzing {
    func analyze(_ request: JournalSubmissionRequest) async throws -> JournalAnalysisResult
}

struct BackendJournalService: JournalAnalyzing {
    let endpoint: URL

    func analyze(_ request: JournalSubmissionRequest) async throws -> JournalAnalysisResult {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 20
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            urlRequest.httpBody = try JSONEncoder.openNestEncoder.encode(
                BackendJournalRequest(
                    journalEntry: request.entryText,
                    userName: request.userName,
                    therapistName: request.therapistName,
                    locale: request.locale,
                    region: request.region
                )
            )
        } catch {
            throw JournalServiceError.requestEncodingFailed
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: urlRequest)
        } catch let urlError as URLError {
            throw JournalServiceError(urlError: urlError)
        } catch {
            throw JournalServiceError.unknown(error.localizedDescription)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw JournalServiceError.invalidResponse
        }

        guard 200 ..< 300 ~= httpResponse.statusCode else {
            let apiError = try? JSONDecoder().decode(BackendErrorResponse.self, from: data)
            throw JournalServiceError.serverError(apiError?.error ?? "Request failed with status \(httpResponse.statusCode).")
        }

        do {
            let decodedResponse = try JSONDecoder().decode(BackendJournalResponse.self, from: data)
            return decodedResponse.asAnalysisResult
        } catch {
            throw JournalServiceError.decodingFailed
        }
    }
}

struct MockGeminiJournalService: JournalAnalyzing {
    func analyze(_ request: JournalSubmissionRequest) async throws -> JournalAnalysisResult {
        try await Task.sleep(for: .milliseconds(500))
        return Self.previewAnalysis(for: request)
    }

    static func previewAnalysis(for request: JournalSubmissionRequest) -> JournalAnalysisResult {
        let harmfulWords = ["alone", "worthless", "hopeless", "overwhelmed", "hurt", "empty", "anxious", "isolated"]
        let positiveWords = ["calm", "grateful", "safe", "hopeful", "steady", "grounded", "supported"]
        let lowercasedEntry = request.entryText.lowercased()

        let harmfulTerms = harmfulWords.filter { lowercasedEntry.contains($0) }
        let positiveMatches = positiveWords.filter { lowercasedEntry.contains($0) }
        let rawScore = 78 - (harmfulTerms.count * 16) + (positiveMatches.count * 8)
        let score = min(max(rawScore, 10), 100)
        let therapistAlert = score < 50 || harmfulTerms.count >= 2
        let mood: JournalMood = therapistAlert ? .bad : .good

        let summary: String
        if therapistAlert {
            summary = "Distress language detected in \(request.userName)'s entry. Escalate this summary to \(request.therapistName) for review."
        } else {
            summary = "Entry shows manageable emotional tone with no immediate escalation markers. Continue routine therapist monitoring."
        }

        return JournalAnalysisResult(
            score: score,
            harmfulTerms: harmfulTerms,
            summary: summary,
            therapistAlert: therapistAlert,
            mood: mood,
            language: request.locale.languageCodeFallback,
            region: request.region,
            therapistNotificationSent: therapistAlert
        )
    }
}

struct JournalSubmissionRequest {
    let entryText: String
    let entryDate: Date
    let attachedPhotoCount: Int
    let userName: String
    let therapistName: String
    let locale: String
    let region: String
}

struct JournalAnalysisResult {
    let score: Int
    let harmfulTerms: [String]
    let summary: String
    let therapistAlert: Bool
    let mood: JournalMood
    let language: String
    let region: String
    let therapistNotificationSent: Bool
}

struct BackendJournalRequest: Encodable {
    let journalEntry: String
    let userName: String
    let therapistName: String
    let locale: String
    let region: String
}

struct BackendJournalResponse: Decodable {
    let score: Int
    let flaggedTerms: [String]
    let therapistAlert: Bool
    let summary: String
    let mood: String
    let language: String
    let region: String
    let therapistNotificationSent: Bool

    var asAnalysisResult: JournalAnalysisResult {
        JournalAnalysisResult(
            score: score,
            harmfulTerms: flaggedTerms,
            summary: summary,
            therapistAlert: therapistAlert,
            mood: JournalMood(apiValue: mood),
            language: language,
            region: region,
            therapistNotificationSent: therapistNotificationSent
        )
    }

    private enum CodingKeys: String, CodingKey {
        case score
        case flaggedTerms
        case therapistAlert
        case summary
        case mood
        case language
        case region
        case therapistNotificationSent
    }
}

struct BackendErrorResponse: Decodable {
    let error: String
}

struct JournalRecord: Identifiable {
    let id = UUID()
    let entryDate: Date
    let text: String
    let attachedPhotos: [JournalPhotoAttachment]
    let analysis: JournalAnalysisResult
    let therapistPingSentAt: Date?

    var attachedPhotoCount: Int {
        attachedPhotos.count
    }
}

struct SafetyPing {
    let therapistName: String
    let score: Int
    let sentAt: Date
    let flaggedTerms: [String]
    let notificationSent: Bool
}

enum SimulatorTestCase: CaseIterable, Identifiable {
    case lowWellnessAlert
    case stableEntry
    case notificationFailure

    var id: Self { self }

    var title: String {
        switch self {
        case .lowWellnessAlert:
            return "Low Wellness Alert"
        case .stableEntry:
            return "Stable Entry"
        case .notificationFailure:
            return "Notification Failure"
        }
    }

    var detail: String {
        switch self {
        case .lowWellnessAlert:
            return "Creates a low-score journal that should trigger the safety ping."
        case .stableEntry:
            return "Creates a healthy journal result with no therapist escalation."
        case .notificationFailure:
            return "Creates a flagged journal where therapist delivery is not confirmed."
        }
    }

    var entryText: String {
        switch self {
        case .lowWellnessAlert:
            return "I feel hopeless, isolated, and overwhelmed today."
        case .stableEntry:
            return "I felt grounded today and had a supportive check-in."
        case .notificationFailure:
            return "I feel alone and hopeless and do not know what to do."
        }
    }
}

struct JournalPhotoAttachment: Identifiable, Hashable {
    let id = UUID()
    let imageData: Data
}

struct CalendarDay: Identifiable {
    let date: Date
    let dayNumber: Int
    let isInDisplayedMonth: Bool
    let mood: JournalMood?

    var id: Date { date }
}

struct JournalDayStatus {
    let date: Date
    let mood: JournalMood
}

enum JournalMood {
    case good
    case bad

    init(apiValue: String) {
        switch apiValue.lowercased() {
        case "good":
            self = .good
        default:
            self = .bad
        }
    }
}

enum AppScreen: CaseIterable {
    case journal
    case progress
    case gallery
}

struct HomeTheme {
    let isDark: Bool
    let backgroundTop: Color
    let backgroundBottom: Color
    let primaryText: Color
    let secondaryText: Color
    let controlFill: Color
    let editorFill: Color
    let cardFill: Color
    let alertFill: Color
    let alertText: Color
    let calmAccent: Color
    let alertAccent: Color
    let calmIslandStart: Color
    let calmIslandEnd: Color
    let alertIslandStart: Color
    let alertIslandEnd: Color
    let islandControlFill: Color
    let iconOnLightControl: Color
    let sheetBackground: Color
    let selectedDayFill: Color
    let selectedDayText: Color
    let goodDayDot: Color
    let badDayDot: Color

    init(colorScheme: ColorScheme, isAlerting: Bool) {
        isDark = colorScheme == .dark

        if isDark {
            backgroundTop = Color(red: 0.15, green: 0.17, blue: 0.18)
            backgroundBottom = Color(red: 0.29, green: 0.25, blue: 0.24)
            primaryText = Color(red: 0.95, green: 0.91, blue: 0.86)
            secondaryText = Color(red: 0.77, green: 0.74, blue: 0.71)
            controlFill = Color.white.opacity(0.10)
            editorFill = Color.white.opacity(0.08)
            cardFill = Color.white.opacity(0.10)
            alertFill = Color(red: 0.52, green: 0.30, blue: 0.34).opacity(0.55)
            alertText = Color(red: 0.96, green: 0.76, blue: 0.80)
            calmAccent = Color(red: 0.64, green: 0.71, blue: 0.68)
            alertAccent = Color(red: 0.78, green: 0.48, blue: 0.46)
            calmIslandStart = Color(red: 0.29, green: 0.33, blue: 0.32)
            calmIslandEnd = Color(red: 0.43, green: 0.49, blue: 0.47)
            alertIslandStart = Color(red: 0.43, green: 0.24, blue: 0.27)
            alertIslandEnd = Color(red: 0.58, green: 0.33, blue: 0.34)
            islandControlFill = Color.white.opacity(0.16)
            iconOnLightControl = Color(red: 0.17, green: 0.17, blue: 0.16)
            sheetBackground = Color(red: 0.13, green: 0.14, blue: 0.15)
            selectedDayFill = Color(red: 0.64, green: 0.71, blue: 0.68).opacity(0.35)
            selectedDayText = .white
            goodDayDot = Color(red: 0.63, green: 0.83, blue: 0.67)
            badDayDot = Color(red: 0.92, green: 0.55, blue: 0.56)
        } else {
            backgroundTop = Color(red: 0.94, green: 0.90, blue: 0.84)
            backgroundBottom = Color(red: 0.81, green: 0.67, blue: 0.63)
            primaryText = Color(red: 0.35, green: 0.31, blue: 0.29)
            secondaryText = Color(red: 0.40, green: 0.44, blue: 0.42)
            controlFill = Color.white.opacity(0.55)
            editorFill = Color.white.opacity(0.65)
            cardFill = Color.white.opacity(0.45)
            alertFill = Color(red: 0.93, green: 0.77, blue: 0.84).opacity(0.75)
            alertText = Color(red: 0.46, green: 0.33, blue: 0.31)
            calmAccent = Color(red: 0.60, green: 0.66, blue: 0.64)
            alertAccent = Color(red: 0.64, green: 0.38, blue: 0.36)
            calmIslandStart = Color(red: 0.40, green: 0.44, blue: 0.42)
            calmIslandEnd = Color(red: 0.60, green: 0.66, blue: 0.64)
            alertIslandStart = Color(red: 0.52, green: 0.28, blue: 0.30)
            alertIslandEnd = Color(red: 0.64, green: 0.38, blue: 0.36)
            islandControlFill = Color(red: 0.94, green: 0.90, blue: 0.84)
            iconOnLightControl = Color(red: 0.17, green: 0.17, blue: 0.16)
            sheetBackground = Color(red: 0.96, green: 0.93, blue: 0.89)
            selectedDayFill = Color(red: 0.60, green: 0.66, blue: 0.64).opacity(0.35)
            selectedDayText = Color(red: 0.29, green: 0.27, blue: 0.26)
            goodDayDot = Color(red: 0.45, green: 0.68, blue: 0.52)
            badDayDot = Color(red: 0.76, green: 0.42, blue: 0.43)
        }
    }
}

enum JournalServiceError: LocalizedError {
    case invalidResponse
    case requestEncodingFailed
    case decodingFailed
    case offline
    case timeout
    case cannotReachServer
    case serverError(String)
    case unknown(String)

    init(urlError: URLError) {
        switch urlError.code {
        case .notConnectedToInternet:
            self = .offline
        case .timedOut:
            self = .timeout
        case .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed, .networkConnectionLost:
            self = .cannotReachServer
        default:
            self = .unknown(urlError.localizedDescription)
        }
    }

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The backend returned an invalid response."
        case .requestEncodingFailed:
            return "The journal request could not be prepared."
        case .decodingFailed:
            return "The backend response could not be read. Check the API response format."
        case .offline:
            return "You appear to be offline. Reconnect and try again."
        case .timeout:
            return "The request timed out. Try submitting again."
        case .cannotReachServer:
            return "The backend could not be reached. Verify the server is running."
        case .serverError(let message):
            return message
        case .unknown(let message):
            return message
        }
    }
}

private extension JSONEncoder {
    static var openNestEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}

private extension String {
    var languageCodeFallback: String {
        Locale(identifier: self).language.languageCode?.identifier ?? "en"
    }
}
