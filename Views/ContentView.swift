import SwiftUI

/// Main view that displays countdown cards in a swipeable interface
/// Shows three types of countdowns: non-working days, public holidays, and long weekends
struct ContentView: View {
    // MARK: - State Properties
    @StateObject private var model = CountdownModel()  // Main data model for countdown calculations
    @State private var selectedIndex = 0               // Currently selected card index (0-2)
    @State private var dragOffset: CGFloat = 0         // Drag offset for swipe gestures
    @State private var showSettings = false            // Controls settings sheet presentation
    @State private var selectedTab: NavTab = .countdowns // Currently selected navigation tab
    @State private var workingDaysChangedWhileInSettings = false // Track change source
    @State private var workingDaysBeforeSettings: String? = nil   // Snapshot when opening settings
    @State private var showWorkingDaysUpdatedDialog = false      // Controls confirmation dialog
    @AppStorage("hasCompletedSetup") private var hasCompletedSetup: Bool = false
    
    // User's working days configuration (Monday-Sunday, true=working, false=off)
    @AppStorage("workingDaysArray") private var workingDaysArray: String = "true,true,true,true,true,false,false"

    /// Dynamically generates card titles based on current day and working schedule
    /// Determines if user is currently in a non-working period or looking forward to one
    private var cardTitles: [String] {
        let workingDays = workingDaysArray.split(separator: ",").map { $0 == "true" }
        let nonWorkingDays = workingDays.enumerated().filter { !$0.element }.map { $0.offset }
        
        // Check if today is a non-working day
        let today = Date()
        let calendar = Calendar.singapore
        let todayWeekday = calendar.component(.weekday, from: today)
        let todayWorkIndex = (todayWeekday + 5) % 7 // Monday is 0, Sunday is 6
        let isTodayNonWorking = !workingDays[todayWorkIndex]
        
        let hasConsecutive = Self.hasConsecutiveDays(nonWorkingDays)
        let nonWorkingTitle: String = {
            if isTodayNonWorking {
                return hasConsecutive ? "Time Off!" : "Day Off!"
            } else {
                return hasConsecutive ? "Next Time Off" : "Next Day Off"
            }
        }()

        return [nonWorkingTitle, "Next Public Holiday", "Next Long Weekend"]
    }

    private let gradients: [LinearGradient] = [
        LinearGradient(
            gradient: Gradient(colors: [Color.purple, Color.blue]),
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        LinearGradient(
            gradient: Gradient(colors: [Color.orange, Color.red]),
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        LinearGradient(
            gradient: Gradient(colors: [Color.green, Color.teal]),
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
    ]

    /// Check if any indices in `days` are consecutive (e.g., Saturday/Sunday off)
    private static func hasConsecutiveDays(_ days: [Int]) -> Bool {
        guard days.count > 1 else { return false }
        for (a, b) in zip(days, days.dropFirst()) {
            if b == a + 1 { return true }
        }
        return false
    }

    /// Carousel of countdown cards with page indicators
    private var countdownSection: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Main countdown cards view with swipe functionality
                CountdownPagesView(
                    model: model,
                    selectedIndex: $selectedIndex,
                    dragOffset: $dragOffset,
                    geo: geo,
                    cardTitles: cardTitles,
                    gradients: gradients
                )

                // Page indicator dots (clickable for navigation)
                HStack(spacing: 12) {
                    ForEach(cardTitles.indices, id: \.self) { idx in
                        Button(action: {
                            // Animate to selected card
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.95)) {
                                selectedIndex = idx
                            }
                        }) {
                            Circle()
                                .fill(idx == selectedIndex ? Color.primary : Color.primary.opacity(0.3))
                                .frame(width: 14, height: 14)
                                .shadow(radius: idx == selectedIndex ? 4 : 0)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .padding(.top, 12)
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                countdownSection
                    .navigationTitle("Countdowns")
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(action: { showSettings = true }) {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Countdowns", systemImage: "hourglass")
            }
            .tag(NavTab.countdowns)

            NavigationStack {
                PlanView()
                    .environmentObject(model)
                    .navigationTitle("Leave Planning")
            }
            .tabItem {
                Label("Plan", systemImage: "calendar.badge.plus")
            }
            .tag(NavTab.plan)
        }
        .sheet(isPresented: $showSettings, onDismiss: {
            // After closing Settings, compare against snapshot to determine real change
            let changed = (workingDaysArray != (workingDaysBeforeSettings ?? workingDaysArray))
            workingDaysBeforeSettings = nil
            workingDaysChangedWhileInSettings = false
            if changed {
                // CountdownModel debounces UserDefaults changes by 500ms; add a small buffer
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    showWorkingDaysUpdatedDialog = true
                }
            }
        }) {
            // Settings sheet for configuring working days and holiday data
            SettingsView(onSaveWorkingDays: { workingDaysChangedWhileInSettings = true })
                .environmentObject(model)
        }
        // Detect working-days changes made within Settings (covers drag-to-dismiss save flows)
        .onChange(of: workingDaysArray) { _ in
            if showSettings { workingDaysChangedWhileInSettings = true }
        }
        // Capture snapshot when Settings is opened
        .onChange(of: showSettings) { isPresenting in
            if isPresenting {
                workingDaysBeforeSettings = workingDaysArray
            }
        }
        // Present first-run setup full screen until completed
        .fullScreenCover(
            isPresented: Binding(
                get: { !hasCompletedSetup },
                set: { _ in }
            )
        ) {
            SetupView()
        }
        // Confirmation dialog once updates are applied
        .alert("Updated Working Days", isPresented: $showWorkingDaysUpdatedDialog) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The app has been updated to reflect your new working days.")
        }
    }
}

/// Loading state card shown while holiday data is being fetched
/// Displays a progress indicator with a message
struct LoadingCard: View {
    let message: String           // Loading message to display
    let background: LinearGradient // Gradient background matching the card type
    let cardHeight: CGFloat       // Fixed height for consistent sizing
    
    var body: some View {
        ZStack {
            // Background card with same styling as CountdownCard
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(background)
                .frame(maxWidth: .infinity, minHeight: cardHeight, maxHeight: cardHeight)
                .shadow(radius: 16)
            
            // Loading indicator with message
            ProgressView(message)
                .font(.title)
                .foregroundColor(.white)
                .shadow(radius: 4)
        }
        .padding(.horizontal, 24)
    }
}

/// View that manages the swipeable countdown cards with crescent-shaped layout
/// Handles drag gestures and animations for card transitions
struct CountdownPagesView: View {
    // MARK: - Properties
    @ObservedObject var model: CountdownModel  // Data model for countdown calculations
    @Binding var selectedIndex: Int            // Currently selected card index
    @Binding var dragOffset: CGFloat           // Current drag offset for animations
    var geo: GeometryProxy                     // Geometry proxy for screen dimensions
    var cardTitles: [String]                   // Dynamic titles for each card
    let gradients: [LinearGradient]            // Gradient backgrounds for each countdown card

    private var cardCount: Int { cardTitles.count }          // Total number of countdown cards
    private var cardWidth: CGFloat { geo.size.width }        // Full screen width for cards
    private var cardHeight: CGFloat { geo.size.height - 180 }
    private var containerHeight: CGFloat { geo.size.height - 120 }
    
    /// Calculates the crescent-shaped layout offsets for each card
    /// Creates a curved arrangement where cards are positioned in an arc
    private func crescentOffset(for index: Int) -> (x: CGFloat, y: CGFloat, rotation: Double) {
        let distanceFromSelected = Double(index - selectedIndex)
        let normalizedDistance = distanceFromSelected / Double(cardCount - 1)
        
        // Create a crescent shape using sine function
        // This creates a curved layout: cards go down in the middle and up at the edges
        let verticalOffset = sin(normalizedDistance * .pi) * 60 // Amplitude of the curve
        let horizontalOffset = CGFloat(distanceFromSelected) * cardWidth
        
        // Add rotation for more dynamic visual effect
        let rotation = normalizedDistance * 15 // Maximum 15 degrees rotation
        
        return (horizontalOffset, verticalOffset, rotation)
    }
    
    /// Creates the appropriate card view for the given index
    @ViewBuilder
    private func cardView(for idx: Int) -> some View {
        switch idx {
        case 0:
            // Non-working day countdown card
            CountdownCard(
                title: cardTitles[0],
                target: model.nextNonWorkingDate,
                countdown: model.countdown(to: model.nextNonWorkingDate),
                background: gradients[0],
                cardHeight: cardHeight
            )
        case 1:
            // Public Holiday countdown card
            if let h = model.nextHoliday {
                CountdownCard(
                    title: cardTitles[1],
                    target: h.date,
                    countdown: model.countdown(to: h.date),
                    background: gradients[1],
                    cardHeight: cardHeight,
                    subtitle: h.name
                )
            } else {
                // Show loading state while holiday data is being fetched
                LoadingCard(message: "Loading holidays…", background: gradients[1], cardHeight: cardHeight)
            }
        case 2:
            // Long Weekend countdown card
            if let lw = model.nextLongWeekendHoliday {
                CountdownCard(
                    title: cardTitles[2],
                    target: lw.date,
                    countdown: model.countdown(to: lw.date),
                    background: gradients[2],
                    cardHeight: cardHeight,
                    subtitle: lw.name
                )
            } else {
                // Show loading state while searching for long weekends
                LoadingCard(message: "Looking for a long weekend…", background: gradients[2], cardHeight: cardHeight)
            }
        default:
            EmptyView()
        }
    }

    var body: some View {
        ZStack {
            ForEach(0..<cardCount) { idx in
                cardView(for: idx)
                .frame(width: cardWidth)
                .offset(
                    x: crescentOffset(for: idx).x + dragOffset,  // Apply crescent layout + drag
                    y: crescentOffset(for: idx).y
                )
                .rotationEffect(.degrees(crescentOffset(for: idx).rotation))  // Apply rotation
                .scaleEffect(idx == selectedIndex ? 1.0 : 0.9)  // Scale down non-selected cards
                .opacity(idx == selectedIndex ? 1.0 : 0.7)      // Fade non-selected cards
                .zIndex(idx == selectedIndex ? 1 : 0)           // Bring selected card to front
            }
        }
        .frame(width: cardWidth, height: containerHeight)
        // Snappier, less bouncy spring animations for card transitions
        .animation(.interpolatingSpring(stiffness: 180, damping: 24), value: selectedIndex)
        .animation(.interpolatingSpring(stiffness: 180, damping: 24), value: dragOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    // Update drag offset for real-time visual feedback
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    // Determine if drag was sufficient to change cards
                    let threshold = cardWidth / 8
                    let drag = value.translation.width
                    var newIndex = selectedIndex
                    
                    // Swipe left: go to next card
                    if drag < -threshold && selectedIndex < cardCount - 1 {
                        newIndex += 1
                    }
                    // Swipe right: go to previous card
                    else if drag > threshold && selectedIndex > 0 {
                        newIndex -= 1
                    }
                    
                    // Animate to new selection
                    withAnimation(.interpolatingSpring(stiffness: 180, damping: 24)) {
                        selectedIndex = newIndex
                        dragOffset = 0
                    }
                }
        )
        .frame(height: containerHeight)
        .padding(.top, 8)
    }
}

private enum NavTab: String, CaseIterable, Identifiable {
    case countdowns
    case plan

    var id: String { rawValue }
}
