//
//  HolidayStore.swift
//  Countdown App
//
//  Created by Kevin on 25/7/25.
//

import Foundation
import Combine

/// Status of holiday data download and storage
enum HolidayDownloadStatus: Equatable {
    case notDownloaded                    // No holiday data available
    case downloading                      // Currently downloading data
    case downloaded(date: Date, years: [String])  // Data downloaded with timestamp and years
    case error(String)                    // Download failed with error message
}

/// Central store for managing Singapore public holiday data
/// Handles downloading, caching, and providing holiday information to the app
class HolidayStore: ObservableObject {
    // MARK: - Published Properties
    @Published var holidays: [Holiday] = []                    // Array of all loaded holidays
    @Published var downloadStatus: HolidayDownloadStatus = .notDownloaded  // Current download status
    
    // MARK: - Private Properties
    private var cancellable: AnyCancellable?                   // Combine subscription
    private let service = HolidayService()                     // API service for live data
    private let downloader = HolidayDownloader()               // Downloader for cached data
    
    init() {
        // Check initial download status
        updateDownloadStatus()
        // 1. Load cached holidays immediately (if any)
        loadFromDiskIfAvailable()
        // 2. Start download in background, update if new data arrives
        fetchAndUpdateInBackground()
    }
    
    /// Updates the download status based on available cached files
    private func updateDownloadStatus() {
        let fileManager = FileManager.default
        guard let documentsURL = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) else {
            downloadStatus = .notDownloaded
            return
        }
        
        // Check current year, previous year, and next year for holiday files
        let currentYear = Calendar.singapore.component(.year, from: Date())
        let yearsToCheck = [currentYear - 1, currentYear, currentYear + 1]
        let files = yearsToCheck.map { "holidays\($0).json" }
        
        var existingFiles: [String] = []
        var lastModified: Date?
        
        for file in files {
            let fileURL = documentsURL.appendingPathComponent(file)
            if fileManager.fileExists(atPath: fileURL.path) {
                existingFiles.append(String(file.prefix(12))) // Extract year part like "holidays2026"
                if let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                   let modDate = attributes[.modificationDate] as? Date {
                    if lastModified == nil || modDate > lastModified! {
                        lastModified = modDate
                    }
                }
            }
        }
        
        print("🔍 HolidayStore: Found holiday files: \(existingFiles)")
        
        if existingFiles.isEmpty {
            downloadStatus = .notDownloaded
        } else {
            let years = existingFiles.map { $0.replacingOccurrences(of: "holidays", with: "") }
            downloadStatus = .downloaded(date: lastModified ?? Date(), years: years)
        }
    }

    /// Loads holidays from disk if cached files exist
    /// Does not fall back to live fetch on error - UI will show loading state
    private func loadFromDiskIfAvailable() {
        do {
            let data = try downloader.loadStoredHolidays()
            let apiResponse = try JSONDecoder().decode(HolidayAPIResponse.self, from: data)
            let mapped = apiResponse.result.records
                .compactMap { record -> Holiday? in
                    guard let date = isoFormatter.date(from: record.date) else { return nil }
                    return Holiday(name: record.name, date: date)
                }
            holidays = mapped.sorted { $0.date < $1.date }
        } catch {
            // If no cache, do nothing; UI will show loading state
        }
    }

    /// Downloads latest holidays and updates the store if new data arrives
    /// Only downloads datasets for missing years unless force is true
    private func fetchAndUpdateInBackground(force: Bool = false) {
        Task {
            await fetchAndUpdate(force: force)
        }
    }
    
    /// Public method to refresh holiday data (forces re-download)
    func refreshHolidayData() async {
        await fetchAndUpdate(force: true)
    }

    /// Main method for fetching and updating holiday data
    /// Handles both cached and live data fetching with error handling
    @MainActor
    private func fetchAndUpdate(force: Bool = false) async {
        downloadStatus = .downloading
        let currentYear = Calendar.singapore.component(.year, from: Date())
        // Download current year, next year, and also check if we need previous year for edge cases
        let candidateYears = [currentYear - 1, currentYear, currentYear + 1]

        let fileManager = FileManager.default
        // Determine which years are missing from disk
        var missingYears: [Int] = []
        if let docs = try? fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            for year in candidateYears {
                let fileURL = docs.appendingPathComponent("holidays\(year).json")
                if !fileManager.fileExists(atPath: fileURL.path) {
                    missingYears.append(year)
                }
            }
        } else {
            // If we can't access the documents directory, fall back to downloading all years
            missingYears = candidateYears
        }

        // If force is requested, download all candidate years regardless of cache
        if force {
            missingYears = candidateYears
        }

        // If nothing is missing and not forcing, just load from disk and update status
        if missingYears.isEmpty && !force {
            loadFromDisk()
            updateDownloadStatus()
            return
        }

        let yearsToDownload = force ? candidateYears : missingYears
        
        do {
            try await downloader.downloadAndStore(years: yearsToDownload)
            loadFromDisk()
            updateDownloadStatus()
        } catch {
            downloadStatus = .error(error.localizedDescription)
            loadLive()  // Fallback to live API fetch
        }
    }

    /// Loads holiday data from cached files on disk
    private func loadFromDisk() {
        do {
            let data = try downloader.loadStoredHolidays()
            let apiResponse = try JSONDecoder().decode(HolidayAPIResponse.self, from: data)
            // Map raw records to `Holiday` objects
            let mapped = apiResponse.result.records
                .compactMap { record -> Holiday? in
                    // Parse the date string
                    guard let date = isoFormatter.date(from: record.date) else { return nil }
                    // Use the `name` property (mapped from JSON "holiday")
                    return Holiday(name: record.name, date: date)
                }
            holidays = mapped.sorted { $0.date < $1.date }
            print("🔍 HolidayStore: loadFromDisk - Loaded \(holidays.count) holidays")
            
            // Debug: Print some of the loaded holidays
            let futureHolidays = holidays.filter { Calendar.singapore.startOfDay(for: $0.date) > Calendar.singapore.startOfDay(for: Date()) }
            print("🔍 HolidayStore: Future holidays loaded:")
            for holiday in futureHolidays.prefix(10) {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                print("🔍 HolidayStore: - \(holiday.name) on \(formatter.string(from: holiday.date))")
            }
        } catch {
            print("🔍 HolidayStore: loadFromDisk - Failed to load from disk: \(error)")
            // Fallback to live fetch on error
            loadLive()
        }
    }
    
    /// Fallback method to load holiday data from live API
    private func loadLive() {
        cancellable = service.fetchHolidays()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] fetched in
                    self?.holidays = fetched.sorted { $0.date < $1.date }
                }
            )
    }
    
    /// ISO formatter for parsing stored JSON dates in Singapore timezone
    private var isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Singapore")
        return f
    }()

    /// Shared singleton instance for use across the app
    static let shared = HolidayStore()
}