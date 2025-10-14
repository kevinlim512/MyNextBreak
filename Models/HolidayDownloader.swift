//
//  HolidayDownloader.swift
//  Countdown App
//
//  Created by Kevin on 25/7/25.
//

import Foundation

/// Handles downloading and storing Singapore public holiday data from data.gov.sg
/// Manages multiple year datasets and provides local storage capabilities
class HolidayDownloader {

    /// Map of known year -> resource id for Singapore public holidays API
    /// Add more years here if you have their resource ids from data.gov.sg
    private let resourceMap: [Int: String] = [
        2025: "d_3751791452397f1b1c80c451447e40b7",
        2026: "d_149b61ad0a22f61c09dc80f2df5bbec8"
    ]

    /// Fallback resource id for years not in the resourceMap
    /// Covers datasets that include multiple years
    private let defaultResourceID = "d_3751791452397f1b1c80c451447e40b7"

    /// Downloads the public holiday datasets for the provided years and stores them locally
    /// Each year is downloaded as a separate JSON file for efficient caching
    func downloadAndStore(years: [Int]) async throws {
        print("🔍 HolidayDownloader: Starting download for years: \(years)")
        let datasets: [(String, String)] = years.map { year in
            let resourceID = resourceIDForYear(year)
            let filename = "holidays\(year).json"
            return (resourceID, filename)
        }

        for (resourceID, filename) in datasets {
            print("🔍 HolidayDownloader: Downloading \(filename) with resource ID: \(resourceID)")
            
            // Construct API URL for the specific resource
            guard let url = URL(string: "https://data.gov.sg/api/action/datastore_search?resource_id=\(resourceID)&limit=1000") else {
                throw NSError(domain: "HolidayDownloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL for resource ID: \(resourceID)"])
            }
            
            // Download the data
            let (tempURL, _) = try await URLSession.shared.download(from: url)
            
            // Save to documents directory
            let docs = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let destURL = docs.appendingPathComponent(filename)
            
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            
            // Move downloaded file to final location
            try FileManager.default.moveItem(at: tempURL, to: destURL)
            print("🔍 HolidayDownloader: Successfully saved \(filename)")
        }
    }
    
    /// Returns a resource id for a given year, falling back to a generic resource if unknown
    private func resourceIDForYear(_ year: Int) -> String {
        return resourceMap[year] ?? defaultResourceID
    }

    /// Loads all stored holiday data from disk by merging all available `holidaysYYYY.json` files
    /// Returns a single JSON response containing all holiday records from all years
    func loadStoredHolidays() throws -> Data {
        let fm = FileManager.default
        let docs = try fm.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: false
        )
        let items = (try? fm.contentsOfDirectory(atPath: docs.path)) ?? []
        let holidayFiles = items.filter { $0.hasPrefix("holidays") && $0.hasSuffix(".json") }
        
        // If no files are found, throw an error
        if holidayFiles.isEmpty {
            throw NSError(domain: "HolidayDownloader", code: -3, userInfo: [NSLocalizedDescriptionKey: "No holiday files found"])
        }

        // Merge all found holiday files into a single dataset
        var allRecords: [HolidayRecord] = []
        for fileName in holidayFiles {
            let fileURL = docs.appendingPathComponent(fileName)
            let data = try Data(contentsOf: fileURL)
            do {
                let apiResponse = try JSONDecoder().decode(HolidayAPIResponse.self, from: data)
                allRecords.append(contentsOf: apiResponse.result.records)
            } catch {
                // Log error but continue processing other files
                NSLog("Failed to decode holiday file \(fileName): \(error.localizedDescription)")
            }
        }
        
        // Re-encode the merged records into a single JSON object
        let mergedResponse = HolidayAPIResponse(result: HolidayResult(records: allRecords))
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted // For easier debugging
        return try encoder.encode(mergedResponse)
    }
}
