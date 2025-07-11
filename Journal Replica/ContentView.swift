//
//  ContentView.swift
//  Journal Replica
//
//  Created by Danny on 04/07/2025.
//

import SwiftUI
import LocalAuthentication
import PhotosUI
import AVFoundation
import UIKit
import UserNotifications

struct ContentView: View {
    @State private var isUnlocked = false
    @State private var authError: String?
    // Remove notification test state
    @State private var showReminderSheet = false
    @State private var reminderTime: Date = UserDefaults.standard.object(forKey: "reminderTime") as? Date ?? Calendar.current.date(bySettingHour: 20, minute: 0, second: 0, of: Date())!
    @State private var showNotificationAlert = false
    
    var body: some View {
        Group {
            if isUnlocked {
                JournalHomeView(showReminderSheet: $showReminderSheet, reminderTime: $reminderTime)
            } else {
                VStack(spacing: 24) {
                    Image(systemName: "lock.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.accentColor)
                    Text("Journal is locked")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Use Face ID to View Journal")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    if let error = authError {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    Button(action: authenticate) {
                        HStack {
                            Image(systemName: "faceid")
                            Text("View Journal")
                        }
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
        }
        .animation(.easeInOut, value: isUnlocked)
        .sheet(isPresented: $showReminderSheet) {
            ReminderTimePicker(reminderTime: $reminderTime, onSave: {
                scheduleDailyJournalReminder(at: reminderTime)
                showReminderSheet = false
            })
        }
        .onChange(of: reminderTime) { newValue in
            UserDefaults.standard.set(newValue, forKey: "reminderTime")
        }
        .alert(isPresented: $showNotificationAlert) {
            Alert(title: Text("Notifications Disabled"), message: Text("Please enable notifications in Settings to receive reminders."), dismissButton: .default(Text("OK")))
        }
    }
    
    func authenticate() {
        let context = LAContext()
        var error: NSError?
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to view your journal."
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    if success {
                        isUnlocked = true
                        authError = nil
                    } else {
                        authError = authenticationError?.localizedDescription ?? "Face ID failed. Please try again."
                    }
                }
            }
        }
    }
    
    private func requestNotificationPermissionAndSchedule() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            if settings.authorizationStatus == .notDetermined {
                UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                    if granted {
                        scheduleTestNotification()
                    } else {
                        showNotificationAlert = true
                    }
                }
            } else if settings.authorizationStatus == .denied {
                showNotificationAlert = true
            } else {
                scheduleTestNotification()
            }
        }
    }
    
    private func scheduleTestNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Time to journal your day"
        content.body = "Tap to add entry"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
        let request = UNNotificationRequest(identifier: "testJournalNotification", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            } else {
                DispatchQueue.main.async {
                    // Removed notificationScheduled = true
                }
            }
        }
    }

    private func scheduleDailyJournalReminder(at date: Date) {
        let content = UNMutableNotificationContent()
        content.title = "Time to journal your day"
        content.body = "Tap to add entry"
        content.sound = .default
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "dailyJournalReminder", content: content, trigger: trigger)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["dailyJournalReminder"])
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling daily notification: \(error)")
            }
        }
    }
}

// MARK: - Journal Home View

struct JournalEntry: Identifiable {
    let id = UUID()
    var title: String
    var description: String
    var date: Date
    var isBookmarked: Bool = false
    var showTitle: Bool = true
    var images: [UIImage] = []
    var audioFiles: [URL] = []
}

struct JournalHomeView: View {
    @State private var searchText = ""
    @State private var showSortMenu = false
    @State private var sortAscending = false
    @State private var showEntryMenuId: UUID?
    @State private var showEditSheet = false
    @State private var editingEntry: JournalEntry?
    @State private var entryTitle = ""
    @State private var entryDescription = ""
    @State private var showEntrySheet = false
    @State private var entryDate = Date()
    @State private var isEditing = false
    @State private var editIndex: Int? = nil
    @State private var showEditDateSheet = false
    @State private var entryToDelete: JournalEntry?
    @State private var showBookmarkedOnly = false
    @State private var entryShowTitle = true
    @State private var showSearchBar = false
    @State private var selectedImages: [UIImage] = []
    @State private var showPhotoPicker = false
    @State private var showFullScreenImage = false
    @State private var fullScreenImage: UIImage? = nil
    @State private var fullScreenImages: [UIImage] = []
    @State private var fullScreenIndex: Int = 0
    @State private var showTextFormatSheet = false
    @State private var showAudioRecorder = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var audioPlayer: AVAudioPlayer?
    @State private var audioURL: URL? = nil
    @State private var audioURLs: [URL] = []
    
    @State private var entries: [JournalEntry] = [
        JournalEntry(title: "Started Journal", description: "Today I started my new journal app!", date: Date()),
        JournalEntry(title: "Walk in Park", description: "Went for a walk in the park.", date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
        JournalEntry(title: "Read Book", description: "Read a great book.", date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!)
    ]
    
    @Binding var showReminderSheet: Bool
    @Binding var reminderTime: Date
    
    var filteredEntries: [JournalEntry] {
        let filtered = searchText.isEmpty ? entries : entries.filter { ($0.title.localizedCaseInsensitiveContains(searchText) || $0.description.localizedCaseInsensitiveContains(searchText)) && (!showBookmarkedOnly || $0.isBookmarked) }
        let nonEmpty = filtered.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        // Sort: Yesterday first, then current month, then previous months (all descending)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: today)!)
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)
        let yesterdayEntries = nonEmpty.filter { calendar.startOfDay(for: $0.date) == yesterday }
        let currentMonthEntries = nonEmpty.filter {
            let comps = calendar.dateComponents([.month, .year], from: $0.date)
            return comps.month == currentMonth && comps.year == currentYear && calendar.startOfDay(for: $0.date) != yesterday
        }
        let otherEntries = nonEmpty.filter {
            let comps = calendar.dateComponents([.month, .year], from: $0.date)
            return !(comps.month == currentMonth && comps.year == currentYear) && calendar.startOfDay(for: $0.date) != yesterday
        }
        let sorted = yesterdayEntries.sorted { $0.date > $1.date } + currentMonthEntries.sorted { $0.date > $1.date } + otherEntries.sorted { $0.date > $1.date }
        return showBookmarkedOnly ? sorted.filter { $0.isBookmarked } : sorted
    }
    
    var groupedEntries: [(header: String, entries: [JournalEntry])]{
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: today)!)
        let currentMonth = calendar.component(.month, from: today)
        let currentYear = calendar.component(.year, from: today)
        let filtered = searchText.isEmpty ? entries : entries.filter { ($0.title.localizedCaseInsensitiveContains(searchText) || $0.description.localizedCaseInsensitiveContains(searchText)) && (!showBookmarkedOnly || $0.isBookmarked) }
        let nonEmpty = filtered.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !$0.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        // Group by Today, Yesterday, Current Month, Previous Months
        var groups: [(String, [JournalEntry])] = []
        let todayEntries = nonEmpty.filter { calendar.isDate(calendar.startOfDay(for: $0.date), inSameDayAs: today) }
        if !todayEntries.isEmpty {
            groups.append(("Today", todayEntries.sorted { $0.date > $1.date }))
        }
        let yesterdayEntries = nonEmpty.filter { calendar.isDate(calendar.startOfDay(for: $0.date), inSameDayAs: yesterday) }
        if !yesterdayEntries.isEmpty {
            groups.append(("Yesterday", yesterdayEntries.sorted { $0.date > $1.date }))
        }
        let currentMonthEntries = nonEmpty.filter {
            let comps = calendar.dateComponents([.month, .year], from: $0.date)
            return comps.month == currentMonth && comps.year == currentYear &&
                !calendar.isDate(calendar.startOfDay(for: $0.date), inSameDayAs: today) &&
                !calendar.isDate(calendar.startOfDay(for: $0.date), inSameDayAs: yesterday)
        }
        if !currentMonthEntries.isEmpty {
            let monthFormatter = DateFormatter()
            monthFormatter.dateFormat = "LLLL"
            let monthName = monthFormatter.string(from: today)
            groups.append((monthName, currentMonthEntries.sorted { $0.date > $1.date }))
        }
        // Previous months
        let previousMonths = Dictionary(grouping: nonEmpty.filter {
            let comps = calendar.dateComponents([.month, .year], from: $0.date)
            return !(comps.month == currentMonth && comps.year == currentYear) &&
                !calendar.isDate(calendar.startOfDay(for: $0.date), inSameDayAs: today) &&
                !calendar.isDate(calendar.startOfDay(for: $0.date), inSameDayAs: yesterday)
        }) { entry in
            let comps = calendar.dateComponents([.month, .year], from: entry.date)
            return comps
        }
        let sortedPrevMonths = previousMonths.keys.sorted { a, b in
            if a.year == b.year { return (a.month ?? 0) > (b.month ?? 0) }
            return (a.year ?? 0) > (b.year ?? 0)
        }
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "LLLL"
        for comps in sortedPrevMonths {
            let entries = previousMonths[comps] ?? []
            if let month = comps.month, let year = comps.year, !entries.isEmpty {
                let monthName = monthFormatter.monthSymbols[month-1]
                groups.append((monthName, entries.sorted { $0.date > $1.date }))
            }
        }
        return groups
    }
    
    // Stats calculation
    var dayStreak: Int {
        // Calculate the longest streak of consecutive days with entries
        let dates = entries.map { Calendar.current.startOfDay(for: $0.date) }.sorted(by: >)
        guard !dates.isEmpty else { return 0 }
        var streak = 1
        var currentStreak = 1
        for i in 1..<dates.count {
            let diff = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i-1]).day ?? 0
            if diff == 1 {
                currentStreak += 1
                streak = max(streak, currentStreak)
            } else if diff > 1 {
                currentStreak = 1
            }
        }
        return streak
    }
    var totalWords: Int {
        entries.reduce(0) { $0 + $1.title.split(separator: " ").count + $1.description.split(separator: " ").count }
    }
    var daysJournalled: Int {
        Set(entries.map { Calendar.current.startOfDay(for: $0.date) }).count
    }
    
    // Helper for month and yesterday headers
    func headerTitle(for entry: JournalEntry, previous: JournalEntry?) -> String? {
        let calendar = Calendar.current
        let entryDate = calendar.startOfDay(for: entry.date)
        let yesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: Date())!)
        if entryDate == yesterday {
            return "Yesterday"
        }
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "LLLL"
        let entryMonth = monthFormatter.string(from: entry.date)
        let prevMonth = previous.map { monthFormatter.string(from: $0.date) }
        if previous == nil || entryMonth != prevMonth {
            return entryMonth
        }
        return nil
    }
    
    private func dateFooterString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background gradient: tweak colors here if desired
            LinearGradient(gradient: Gradient(colors: [
                Color.black, // Top color
                Color(red: 44/255, green: 18/255, blue: 70/255) // Bottom dark purple
            ]), startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Journal")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                    if showSearchBar {
                        TextField("Search...", text: $searchText)
                            .padding(8)
                            .background(Color.white.opacity(0.12))
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .frame(maxWidth: 160)
                            .overlay(
                                HStack {
                                    Spacer()
                                    Button(action: { showSearchBar = false; searchText = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.white.opacity(0.7))
                                            .padding(.trailing, 8)
                                    }
                                }
                            )
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        Button(action: { withAnimation { showSearchBar = true } }) {
                            Image(systemName: "magnifyingglass")
                                .font(.title2)
                                .foregroundColor(.white)
                        }
                        .padding(.trailing, 8)
                    }
                    Menu {
                        Button("Sort by Newest", action: { sortAscending = false; showBookmarkedOnly = false })
                        Button("Sort by Oldest", action: { sortAscending = true; showBookmarkedOnly = false })
                        Button(showBookmarkedOnly ? "Show All" : "Bookmarked", action: { showBookmarkedOnly.toggle() })
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                }
                .padding([.top, .horizontal])
                // Stats section
                HStack(spacing: 0) {
                    statItem(icon: "flame.fill", iconColor: .red, number: dayStreak, label: "Day Streak")
                    statDivider()
                    statItem(icon: "quote.opening", iconColor: .yellow, number: totalWords, label: "Words Written")
                    statDivider()
                    statItem(icon: "calendar", iconColor: .purple, number: daysJournalled, label: "Days Journalled")
                }
                .padding(.vertical, 10)
                .padding(.horizontal)
                
                // Journal Entries List
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(groupedEntries, id: \ .header) { group in
                            if !group.entries.isEmpty {
                                HStack {
                                    Text(group.header)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white.opacity(0.85))
                                        .padding(.leading, 8)
                                    Spacer()
                                }
                                .padding(.top, 1) // Minimal space above card
                                ForEach(group.entries) { entry in
                                    Button(action: {
                                        openEditSheet(for: entry)
                                    }) {
                                        JournalEntryCard(entry: entry, onEdit: {
                                            openEditSheet(for: entry)
                                        }, onDelete: {
                                            if let realIdx = entries.firstIndex(where: { $0.id == entry.id }) {
                                                entries.remove(at: realIdx)
                                            }
                                        }, onToggleBookmark: {
                                            if let realIdx = entries.firstIndex(where: { $0.id == entry.id }) {
                                                entries[realIdx].isBookmarked.toggle()
                                            }
                                        }, showTitle: entry.showTitle, isBookmarked: entry.isBookmarked, onPrint: {
                                            printFaceCard(entry: entry)
                                        })
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top)
                    .padding(.bottom, 80) // For floating button space
                }
            }
            // Floating Add Button in center
            HStack {
                Spacer()
                Button(action: {
                    isEditing = false
                    entryTitle = ""
                    entryDescription = ""
                    entryDate = Date()
                    showEntrySheet = true
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 60, height: 60)
                            .shadow(radius: 4)
                        Image(systemName: "plus")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 12)
                Spacer()
            }
        }
        .sheet(isPresented: $showEntrySheet, onDismiss: { selectedImages = [] }) {
            VStack(spacing: 20) {
                // Top bar: bookmark, date, ellipsis, Done (always at top)
                HStack(spacing: 8) {
                    Button(action: {
                        if isEditing, let idx = editIndex {
                            entries[idx].isBookmarked.toggle()
                        }
                    }) {
                        Image(systemName: (isEditing && editIndex != nil && entries[editIndex!].isBookmarked) ? "bookmark.fill" : "bookmark")
                            .foregroundColor(.purple)
                            .font(.title2)
                    }
                    Spacer()
                    Text(dateHeaderString(for: entryDate))
                        .font(.headline)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                    Spacer()
                    Menu {
                        Button {
                            showEditDateSheet = true
                        } label: {
                            Label("Edit Date", systemImage: "calendar")
                        }
                        if isEditing, let idx = editIndex {
                            Button(role: .destructive) {
                                entries.remove(at: idx)
                                showEntrySheet = false
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        if isEditing, let idx = editIndex {
                            Button {
                                entries[idx].showTitle.toggle()
                            } label: {
                                Label(entries[idx].showTitle ? "Hide Title" : "Show Title", systemImage: entries[idx].showTitle ? "eye.slash" : "eye")
                            }
                        } else {
                            Button {
                                entryShowTitle.toggle()
                            } label: {
                                Label(entryShowTitle ? "Hide Title" : "Show Title", systemImage: entryShowTitle ? "eye.slash" : "eye")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title2)
                            .padding(.horizontal, 4)
                    }
                    Spacer().frame(width: 2)
                    Button("Done") {
                        if isEditing, let idx = editIndex {
                            entries[idx].title = entryTitle
                            entries[idx].description = entryDescription
                            entries[idx].date = entryDate
                            entries[idx].showTitle = entries[idx].showTitle
                            entries[idx].images = selectedImages // Update images
                            entries[idx].audioFiles = audioURLs // Update audio files
                            showEntrySheet = false
                        } else {
                            if !entryTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !entryDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                let newEntry = JournalEntry(title: entryTitle, description: entryDescription, date: entryDate, isBookmarked: false, showTitle: entryShowTitle, images: selectedImages, audioFiles: audioURLs)
                                entries.insert(newEntry, at: 0)
                                entryShowTitle = true
                            }
                            showEntrySheet = false
                        }
                    }
                    .font(.headline)
                }
                // Image collage preview (for new/edit entry)
                if !selectedImages.isEmpty || !audioURLs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(selectedImages.indices, id: \.self) { idx in
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: selectedImages[idx])
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    Button(action: {
                                        selectedImages.remove(at: idx)
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .resizable()
                                            .frame(width: 22, height: 22)
                                            .foregroundColor(Color.black.opacity(0.7))
                                            .background(Color.white.opacity(0.01))
                                            .clipShape(Circle())
                                    }
                                    .offset(x: -6, y: 6)
                                }
                            }
                            ForEach(audioURLs, id: \.self) { url in
                                AudioWaveformPlayerView(audioURL: url, onDelete: {
                                    if let idx = audioURLs.firstIndex(of: url) {
                                        audioURLs.remove(at: idx)
                                        try? FileManager.default.removeItem(at: url)
                                    }
                                })
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    if (!isEditing && entryShowTitle) || (isEditing && editIndex != nil && entries[editIndex!].showTitle) {
                        TextField("Title", text: $entryTitle)
                            .foregroundColor(.primary)
                            .font(.title2.weight(.bold))
                            .padding(.vertical, 8)
                            .background(Color.clear)
                    }
                    Divider().background(Color.primary.opacity(0.08))
                    TextField("Start writing...", text: $entryDescription, axis: .vertical)
                        .foregroundColor(.primary)
                        .font(.body)
                        .padding(.vertical, 8)
                        .background(Color.clear)
                }
                .padding(.top, 8)
                .padding(.horizontal, 2)
                Spacer()
                // Toolbar above keyboard, always at bottom
                HStack(spacing: 20) {
                    Button(action: { showPhotoPicker = true }) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Button(action: { showTextFormatSheet = true }) {
                        Image(systemName: "textformat.size")
                            .font(.title2)
                            .foregroundColor(.white)
                    }
                    Button(action: {
                        startAudioRecording()
                    }) {
                        Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle")
                            .font(.title2)
                            .foregroundColor(isRecording ? .red : .white)
                    }
                    // ... (other toolbar buttons for future) ...
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6).opacity(0.7))
            }
            .padding()
            .sheet(isPresented: $showEditDateSheet) {
                EditDateSheet(entryDate: $entryDate, onCancel: { showEditDateSheet = false }, onDone: { showEditDateSheet = false })
                    .ignoresSafeArea()
            }
            .sheet(isPresented: $showPhotoPicker) {
                PhotoPickerView(selectedImages: $selectedImages)
            }
            .actionSheet(isPresented: $showTextFormatSheet) {
                ActionSheet(title: Text("Text Formatting"), buttons: [
                    .default(Text("Bold")) { applyTextFormat("**", "**") },
                    .default(Text("Italic")) { applyTextFormat("*", "*") },
                    .default(Text("Underline")) { applyTextFormat("_", "_") },
                    .cancel()
                ])
            }
            // Full screen image gallery viewer
            if showFullScreenImage, !fullScreenImages.isEmpty {
                FullScreenGalleryView(images: fullScreenImages, startIndex: fullScreenIndex, onClose: { showFullScreenImage = false })
            }
        }
    }
    
    func dateHeaderString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date)
    }
    
    // When opening the edit sheet, initialize selectedImages with the entry's images
    func openEditSheet(for entry: JournalEntry) {
        isEditing = true
        entryTitle = entry.title
        entryDescription = entry.description
        entryDate = entry.date
        editIndex = entries.firstIndex(where: { $0.id == entry.id })
        selectedImages = entry.images
        audioURLs = entry.audioFiles // Initialize audio files
        showEntrySheet = true
    }
    
    // Text formatting helper
    func applyTextFormat(_ prefix: String, _ suffix: String) {
        // Simple: wrap the whole description for now
        entryDescription = prefix + entryDescription + suffix
    }
    
    @State private var isRecording = false
    @State private var recorder: AVAudioRecorder?
    func startAudioRecording() {
        if isRecording {
            recorder?.stop()
            isRecording = false
            if let url = recorder?.url {
                audioURLs.append(url)
            }
        } else {
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
                try session.setActive(true)
            } catch {
                // Handle error
            }
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let filename = "journal-audio-\(UUID().uuidString).m4a"
            let url = docs.appendingPathComponent(filename)
            let settings = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            do {
                let rec = try AVAudioRecorder(url: url, settings: settings)
                rec.record()
                recorder = rec
                isRecording = true
            } catch {
                // Handle error
            }
        }
    }
    
    // Helper for stat item
    func statItem(icon: String, iconColor: Color, number: Int, label: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 18, weight: .bold))
                Text("\(number)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            Text(label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }
    func statDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.15))
            .frame(width: 1, height: 36)
            .padding(.vertical, 2)
    }
    
    // Print face card using UIPrintInteractionController
    func printFaceCard(entry: JournalEntry) {
        let printFormatter = UIMarkupTextPrintFormatter(markupText: htmlForEntry(entry))
        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .general
        printInfo.jobName = entry.title.isEmpty ? "Journal Entry" : entry.title
        let controller = UIPrintInteractionController.shared
        controller.printInfo = printInfo
        controller.printFormatter = printFormatter
        controller.present(animated: true, completionHandler: nil)
    }
    // Generate HTML for printing the face card
    func htmlForEntry(_ entry: JournalEntry) -> String {
        var html = "<div style='font-family: -apple-system; color: #222; padding: 16px; max-width: 400px;'>"
        if !entry.images.isEmpty {
            html += "<div style='display: flex; gap: 8px; margin-bottom: 12px;'>"
            for img in entry.images {
                if let data = img.jpegData(compressionQuality: 0.8) {
                    let base64 = data.base64EncodedString()
                    html += "<img src='data:image/jpeg;base64,\(base64)' style='width: 80px; height: 80px; object-fit: cover; border-radius: 10px;' />"
                }
            }
            html += "</div>"
        }
        if !entry.title.isEmpty {
            html += "<h2 style='margin: 0 0 8px 0;'>\(entry.title)</h2>"
        }
        if !entry.description.isEmpty {
            html += "<p style='margin: 0 0 8px 0;'>\(entry.description)</p>"
        }
        html += "<div style='color: #888; font-size: 13px; margin-top: 12px;'>\(dateFooterString(for: entry.date))</div>"
        html += "</div>"
        return html
    }
}

// Show images in face card
struct JournalEntryCard: View {
    let entry: JournalEntry
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onToggleBookmark: () -> Void
    var showTitle: Bool
    var isBookmarked: Bool
    var onPrint: (() -> Void)? = nil
    @State private var showFullScreenImage = false
    @State private var fullScreenImage: UIImage? = nil
    @State private var fullScreenImages: [UIImage] = []
    @State private var fullScreenIndex: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image collage
            if !entry.images.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 2) {
                        ForEach(entry.images.indices, id: \.self) { idx in
                            let img = entry.images[idx]
                            Image(uiImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                .onTapGesture {
                                    fullScreenImages = entry.images
                                    fullScreenIndex = idx
                                    showFullScreenImage = true
                                }
                        }
                    }
                    .padding(.horizontal, 8) // Add left/right padding for consistency
                    .padding(.top, 8) // Add top padding for consistency
                }
            }
            // Audio collage
            if !entry.audioFiles.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(entry.audioFiles, id: \.self) { url in
                            AudioWaveformPlayerView(audioURL: url, onDelete: {})
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.top, 8)
                }
            }
            if showTitle {
                Text(entry.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.top, 16)
                    .padding(.horizontal)
            }
            Text(entry.description)
                .font(.body)
                .foregroundColor(.white.opacity(0.85))
                .padding(.horizontal)
                .padding(.bottom, 4) // Minimal space below description
            Divider()
                .background(Color.primary.opacity(0.08))
                .padding(.horizontal, 8)
                .padding(.bottom, 2) // Minimal space below divider
            HStack {
                Text(dateFooterString(for: entry.date))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Menu {
                    Button { onEdit() } label: { Label("Edit", systemImage: "pencil") }
                    Button(role: .destructive) { onDelete() } label: { Label("Delete", systemImage: "trash") }
                    Button { onToggleBookmark() } label: { Label(isBookmarked ? "Remove Bookmark" : "Bookmark", systemImage: isBookmarked ? "bookmark.fill" : "bookmark") }
                    Button {
                        onPrint?()
                    } label: {
                        Label("Print", systemImage: "printer")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20)) // Slightly smaller
                        .padding(.trailing, 8)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding([.horizontal, .bottom], 12)
            // Full screen image gallery viewer
            if showFullScreenImage, !fullScreenImages.isEmpty {
                FullScreenGalleryView(images: fullScreenImages, startIndex: fullScreenIndex, onClose: { showFullScreenImage = false })
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color(.sRGB, red: 0.22, green: 0.13, blue: 0.32, opacity: 0.96))
                .shadow(color: Color.black.opacity(0.13), radius: 8, x: 0, y: 3)
        )
    }
    
    func dateFooterString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: date)
    }
}

// PhotoPickerView for SwiftUI
struct PhotoPickerView: UIViewControllerRepresentable {
    @Binding var selectedImages: [UIImage]
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 0 // Allow multiple
        config.filter = .images
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: PhotoPickerView
        init(_ parent: PhotoPickerView) { self.parent = parent }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            for result in results {
                if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    result.itemProvider.loadObject(ofClass: UIImage.self) { object, _ in
                        if let image = object as? UIImage {
                            DispatchQueue.main.async {
                                // Prevent duplicates
                                if !self.parent.selectedImages.contains(where: { $0.pngData() == image.pngData() }) {
                                    self.parent.selectedImages.append(image)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// WhatsApp-style full screen image gallery viewer
struct FullScreenGalleryView: View {
    let images: [UIImage]
    let startIndex: Int
    var onClose: () -> Void
    @State private var currentIndex: Int = 0 
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @Environment(\.presentationMode) var presentationMode
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            TabView(selection: $currentIndex) {
                ForEach(images.indices, id: \.self) { idx in
                    GeometryReader { geo in
                        Image(uiImage: images[idx])
                            .resizable()
                            .scaledToFit()
                            .frame(width: geo.size.width, height: geo.size.height)
                            .scaleEffect(currentIndex == idx ? scale : 1.0)
                            .gesture(MagnificationGesture()
                                .onChanged { value in
                                    if currentIndex == idx {
                                        scale = lastScale * value
                                    }
                                }
                                .onEnded { value in
                                    if currentIndex == idx {
                                        lastScale = scale
                                    }
                                }
                            )
                    }
                    .tag(idx)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.top, 40)
                    .padding(.trailing, 20)
            }
        }
        .onAppear { currentIndex = startIndex }
        .transition(.opacity)
    }
}

// Audio Recorder and Player Views
struct AudioRecorderView: View {
    @Binding var audioURL: URL?
    @State private var isRecording = false
    @State private var recorder: AVAudioRecorder?
    @State private var tempURL: URL? = nil
    var body: some View {
        VStack(spacing: 24) {
            Text(isRecording ? "Recording..." : "Tap to Record")
                .font(.headline)
            Button(action: {
                if isRecording {
                    recorder?.stop()
                    audioURL = tempURL
                    isRecording = false
                } else {
                    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".m4a")
                    let settings = [
                        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                        AVSampleRateKey: 12000,
                        AVNumberOfChannelsKey: 1,
                        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                    ]
                    do {
                        let rec = try AVAudioRecorder(url: temp, settings: settings)
                        rec.record()
                        recorder = rec
                        tempURL = temp
                        isRecording = true
                    } catch {
                        // Handle error
                    }
                }
            }) {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .resizable()
                    .frame(width: 64, height: 64)
                    .foregroundColor(isRecording ? .red : .purple)
            }
            if let url = audioURL, !isRecording {
                AudioPlayerView(audioURL: url)
            }
            Spacer()
        }
        .padding()
    }
}

struct AudioPlayerView: View {
    let audioURL: URL
    @State private var player: AVAudioPlayer? = nil
    @State private var isPlaying = false
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                if isPlaying {
                    player?.stop()
                    isPlaying = false
                } else {
                    do {
                        player = try AVAudioPlayer(contentsOf: audioURL)
                        player?.play()
                        isPlaying = true
                    } catch {}
                }
            }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.purple)
            }
            Text(audioURL.lastPathComponent)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .cornerRadius(10)
    }
}

// Audio waveform player view
struct AudioWaveformPlayerView: View {
    let audioURL: URL
    var onDelete: () -> Void
    @State private var player: AVAudioPlayer? = nil
    @State private var isPlaying = false
    @State private var duration: TimeInterval = 0
    @State private var samples: [Float] = []
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                if isPlaying {
                    player?.stop()
                    isPlaying = false
                } else {
                    do {
                        let session = AVAudioSession.sharedInstance()
                        try? session.setCategory(.playback, mode: .default, options: [.defaultToSpeaker])
                        try? session.setActive(true)
                        player = try AVAudioPlayer(contentsOf: audioURL)
                        player?.play()
                        isPlaying = true
                    } catch {}
                }
            }) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .resizable()
                    .frame(width: 40, height: 40)
                    .foregroundColor(.purple)
            }
            WaveformView(samples: samples)
                .frame(height: 40)
                .onAppear {
                    samples = AudioWaveformPlayerView.loadSamples(url: audioURL)
                    duration = (try? AVAudioPlayer(contentsOf: audioURL).duration) ?? 0
                }
            Text(AudioWaveformPlayerView.formatTime(duration))
                .font(.caption)
                .foregroundColor(.white)
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
        .padding(8)
        .background(Color.purple.opacity(0.2))
        .cornerRadius(10)
    }
    static func formatTime(_ t: TimeInterval) -> String {
        let min = Int(t) / 60
        let sec = Int(t) % 60
        return String(format: "%d:%02d", min, sec)
    }
    static func loadSamples(url: URL) -> [Float] {
        guard let file = try? AVAudioFile(forReading: url) else { return [] }
        let length = Int(file.length)
        guard length > 0 else { return [] }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(length)) else { return [] }
        try? file.read(into: buffer)
        guard let channelData = buffer.floatChannelData?[0] else { return [] }
        let sampleCount = 60
        let step = max(1, length / sampleCount)
        var samples: [Float] = []
        for i in stride(from: 0, to: length, by: step) {
            let val = abs(channelData[i])
            samples.append(val)
        }
        return samples
    }
}

struct WaveformView: View {
    let samples: [Float]
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .center, spacing: 2) {
                ForEach(samples.indices, id: \.self) { idx in
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: 2, height: max(8, CGFloat(samples[idx]) * geo.size.height))
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

struct EditDateSheet: View {
    @Binding var entryDate: Date
    var onCancel: () -> Void
    var onDone: () -> Void
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel)
                    .foregroundColor(.purple)
                    .font(.headline)
                Spacer()
                Text("EDIT DATE")
                    .font(.headline)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                Spacer()
                Button("Done", action: onDone)
                    .foregroundColor(.purple)
                    .font(.headline)
            }
            .padding()
            Spacer().frame(height: 8)
            Text("SELECT CUSTOM DATE")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.bottom, 0)
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.4), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemGray6))
                    )
                DatePicker("", selection: $entryDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(GraphicalDatePickerStyle())
                    .labelsHidden()
                    .padding()
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
            Spacer()
        }
    }
}

struct ReminderTimePicker: View {
    @Binding var reminderTime: Date
    var onSave: () -> Void
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("Set Daily Journal Reminder")
                    .font(.headline)
                DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                Button("Save") {
                    onSave()
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.purple.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

