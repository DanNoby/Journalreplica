//
//  ContentView.swift
//  Journal Replica
//
//  Created by Danny on 04/07/2025.
//

import SwiftUI
import LocalAuthentication

struct ContentView: View {
    @State private var isUnlocked = false
    @State private var authError: String?
    
    var body: some View {
        Group {
            if isUnlocked {
                JournalHomeView()
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
        } else {
            authError = error?.localizedDescription ?? "Face ID not available."
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
    
    @State private var entries: [JournalEntry] = [
        JournalEntry(title: "Started Journal", description: "Today I started my new journal app!", date: Date()),
        JournalEntry(title: "Walk in Park", description: "Went for a walk in the park.", date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!),
        JournalEntry(title: "Read Book", description: "Read a great book.", date: Calendar.current.date(byAdding: .day, value: -2, to: Date())!)
    ]
    
    var filteredEntries: [JournalEntry] {
        let filtered = searchText.isEmpty ? entries : entries.filter { ($0.title.localizedCaseInsensitiveContains(searchText) || $0.description.localizedCaseInsensitiveContains(searchText)) && (!showBookmarkedOnly || $0.isBookmarked) }
        let sorted = sortAscending ? filtered.sorted { $0.date < $1.date } : filtered.sorted { $0.date > $1.date }
        return showBookmarkedOnly ? sorted.filter { $0.isBookmarked } : sorted
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Purple to black gradient background
            LinearGradient(gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.purple, Color.black]), startPoint: .top, endPoint: .bottom)
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
                
                // Journal Entries List
                ScrollView {
                    VStack(spacing: 20) {
                        ForEach(filteredEntries.indices, id: \ .self) { idx in
                            let entry = filteredEntries[idx]
                            JournalEntryCard(entry: entry, onEdit: {
                                isEditing = true
                                entryTitle = entry.title
                                entryDescription = entry.description
                                entryDate = entry.date
                                editIndex = entries.firstIndex(where: { $0.id == entry.id })
                                showEntrySheet = true
                            }, onDelete: {
                                if let realIdx = entries.firstIndex(where: { $0.id == entry.id }) {
                                    entries.remove(at: realIdx)
                                }
                            }, onToggleBookmark: {
                                if let realIdx = entries.firstIndex(where: { $0.id == entry.id }) {
                                    entries[realIdx].isBookmarked.toggle()
                                }
                            }, showTitle: entry.showTitle, isBookmarked: entry.isBookmarked)
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
                    Image(systemName: "plus.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(Color.purple.opacity(0.85))
                        .shadow(radius: 4)
                }
                .padding(.bottom, 12)
                Spacer()
            }
        }
        .sheet(isPresented: $showEntrySheet) {
            VStack(spacing: 20) {
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
                            showEntrySheet = false
                        } else {
                            if !entryTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !entryDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                let newEntry = JournalEntry(title: entryTitle, description: entryDescription, date: entryDate, isBookmarked: false, showTitle: entryShowTitle)
                                entries.insert(newEntry, at: 0)
                                entryShowTitle = true
                            }
                            showEntrySheet = false
                        }
                    }
                    .font(.headline)
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
            }
            .padding()
            .sheet(isPresented: $showEditDateSheet) {
                EditDateSheet(entryDate: $entryDate, onCancel: { showEditDateSheet = false }, onDone: { showEditDateSheet = false })
                    .ignoresSafeArea()
            }
        }
    }
    
    func dateHeaderString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: date)
    }
}

struct JournalEntryCard: View {
    let entry: JournalEntry
    var onEdit: () -> Void
    var onDelete: () -> Void
    var onToggleBookmark: () -> Void
    var showTitle: Bool
    var isBookmarked: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 20)) // Slightly smaller
                        .padding(.trailing, 8)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding([.horizontal, .bottom], 12)
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

