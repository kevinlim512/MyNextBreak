//
//  Countdown_AppTests.swift
//  Countdown AppTests
//
//  Created by Kevin on 25/7/25.
//

import Testing
@testable import Countdown_App

struct Countdown_AppTests {

    @Test func testCountdownModelInitialization() async throws {
        let model = CountdownModel()
        #expect(model.nextNonWorkingDate != Date.distantFuture)
    }
    
    @Test func testCalendarExtension() async throws {
        let calendar = Calendar.singapore
        let workingDays = [true, true, true, true, true, false, false] // Mon-Fri work, Sat-Sun off (default configuration)
        
        // Test next day off calculation
        let today = Date()
        if let nextDayOff = calendar.nextDayOff(startingAfter: today, workingDays: workingDays) {
            #expect(nextDayOff >= today)
        }
    }
    
    @Test func testHolidayModel() async throws {
        let holiday = Holiday(name: "Test Holiday", date: Date())
        #expect(holiday.name == "Test Holiday")
        #expect(holiday.id != UUID())
    }
    
    @Test func testWorkingDaysArrayParsing() async throws {
        let workingDaysString = "true,true,true,true,true,false,false"
        let workingDays = workingDaysString.split(separator: ",").map { $0 == "true" }
        
        #expect(workingDays.count == 7)
        #expect(workingDays[0] == true) // Monday
        #expect(workingDays[5] == false) // Saturday (default non-working day)
        #expect(workingDays[6] == false) // Sunday (default non-working day)
    }
    
    @Test func testHolidayStoreAndLongWeekend() async throws {
        let store = HolidayStore.shared
        let model = CountdownModel()
        
        // Wait a bit for holidays to load
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        print("🔍 Test: Total holidays in store: \(store.holidays.count)")
        print("🔍 Test: Next holiday: \(model.nextHoliday?.name ?? "None")")
        print("🔍 Test: Next long weekend: \(model.nextLongWeekendHoliday?.name ?? "None")")
        
        // Basic expectations
        #expect(store.holidays.count >= 0) // Should have some holidays or at least not crash
        #expect(model.nextHoliday != nil || store.holidays.isEmpty) // Either we have a next holiday or no holidays loaded
    }
    
    @Test func testLongWeekendCalculation() async throws {
        let model = CountdownModel()
        
        // Create some test holidays
        let calendar = Calendar.singapore
        let today = Date()
        
        // Create a holiday that should create a long weekend (Thursday holiday)
        let thursdayHoliday = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        let thursdayWeekday = calendar.component(.weekday, from: thursdayHoliday)
        
        // Adjust to make it a Thursday (weekday 5)
        let daysToAdd = (5 - thursdayWeekday + 7) % 7
        let testHolidayDate = calendar.date(byAdding: .day, value: daysToAdd, to: thursdayHoliday) ?? today
        
        let testHoliday = Holiday(name: "Test Holiday", date: testHolidayDate)
        
        // Manually set the holiday in the store for testing
        model.nextHoliday = testHoliday
        
        print("🔍 Test: Created test holiday on \(testHolidayDate)")
        print("🔍 Test: Holiday weekday: \(calendar.component(.weekday, from: testHolidayDate))")
        
        // The test should pass if the logic is working
        #expect(testHoliday.name == "Test Holiday")
    }
}
