//
//  HolidayService.swift
//  Countdown App
//
//  Created by Kevin on 25/7/25.
//

import Foundation
import Combine

/// Errors that can occur when fetching holiday data
enum HolidayError: Error {
    case network(Error)    // Network-related errors
    case decoding(Error)   // JSON decoding errors
}

/// App-friendly holiday model with simplified structure
struct Holiday: Identifiable {
    let id   = UUID()      // Unique identifier for SwiftUI
    let name : String      // Holiday name (e.g., "Good Friday")
    let date : Date        // Holiday date
}

/// Service for fetching Singapore public holidays from data.gov.sg API
class HolidayService {
    // API endpoint for Singapore public holidays
    private let url = URL(string:
        "https://data.gov.sg/api/action/datastore_search?resource_id=d_3751791452397f1b1c80c451447e40b7&limit=500"
    )!

    /// Date formatter for parsing holiday dates in Singapore timezone
    private lazy var isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        // Parse holiday dates in Singapore time (app is Singapore-only)
        f.timeZone = TimeZone(identifier: "Asia/Singapore")
        return f
    }()

    /// Fetches Singapore public holidays from the API and converts them to app-friendly format
    /// Returns a Combine publisher that emits an array of Holiday objects
    func fetchHolidays() -> AnyPublisher<[Holiday], HolidayError> {
        return URLSession.shared.dataTaskPublisher(for: url)
            .mapError { HolidayError.network($0) }  // Convert network errors
            .map(\.data)                            // Extract data from response
            .decode(type: HolidayAPIResponse.self, decoder: JSONDecoder())  // Decode JSON
            .mapError { HolidayError.decoding($0) } // Convert decoding errors
            .map(\.result.records)                  // Extract records array
            .flatMap { [weak self] records -> AnyPublisher<[Holiday], Never> in
                guard let self = self else {
                    return Just([]).eraseToAnyPublisher()
                }
                // Convert API records to app-friendly Holiday objects
                let holidays = records.compactMap { rec -> Holiday? in
                    guard let d = self.isoFormatter.date(from: rec.date) else { return nil }
                    return Holiday(name: rec.name, date: d)
                }
                return Just(holidays)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
}
