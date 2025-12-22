//
//  HolidayAPI.swift
//  Countdown App
//
//  Created by Kevin on 25/7/25.
//

import Foundation

/// API response structure for Singapore public holidays from data.gov.sg
struct HolidayAPIResponse: Codable {
    let result: HolidayResult
}

/// Container for holiday records in the API response
struct HolidayResult: Codable {
    let records: [HolidayRecord]
}

/// Individual holiday record from the Singapore public holidays API
/// Maps to the JSON structure returned by data.gov.sg
struct HolidayRecord: Codable, Identifiable {
    var id = UUID()                    // Unique identifier for SwiftUI
    let date: String                   // Date in "YYYY-MM-DD" format
    let day: String                    // Day of the week (e.g., "Friday")
    let name: String                   // Holiday name (e.g., "Good Friday")

    private enum CodingKeys: String, CodingKey {
        case date
        case day
        case name = "holiday"          // Maps JSON "holiday" field to "name" property
    }
}
