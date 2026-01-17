// CalendarService.swift
// Peninsula

import Foundation
import EventKit
import Combine

/// Service for fetching calendar events using EventKit.
/// Requires `com.apple.security.personal-information.calendars` entitlement.
final class CalendarService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var todayEvents: [EKEvent] = []
    @Published private(set) var hasAccess: Bool = false
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var accessDenied: Bool = false
    
    /// Computed property for event count display
    var eventCountText: String {
        if accessDenied {
            return String(localized: "No access")
        }
        if todayEvents.isEmpty {
            return String(localized: "No events")
        }
        let count = todayEvents.count
        if count == 1 {
            return "1 " + String(localized: "event")
        }
        return "\(count) " + String(localized: "events")
    }
    
    /// Next upcoming event (if any)
    var nextEvent: EKEvent? {
        let now = Date()
        return todayEvents.first { event in
            guard let startDate = event.startDate else { return false }
            return startDate > now
        }
    }
    
    // MARK: - Private Properties
    
    private let eventStore = EKEventStore()
    private var refreshTimer: Timer?
    
    // MARK: - Initialization
    
    init() {
        // Check initial access status
        checkAccessStatus()
    }
    
    deinit {
        refreshTimer?.invalidate()
    }
    
    // MARK: - Public Methods
    
    /// Request calendar access and start monitoring events
    func startMonitoring() {
        requestAccess()
        setupRefreshTimer()
        
        // Listen for calendar changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(calendarChanged),
            name: .EKEventStoreChanged,
            object: eventStore
        )
    }
    
    /// Force refresh events
    func refresh() {
        guard hasAccess else {
            requestAccess()
            return
        }
        fetchTodayEvents()
    }
    
    // MARK: - Private Methods
    
    private func checkAccessStatus() {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .fullAccess, .authorized:
            hasAccess = true
            fetchTodayEvents()
        case .writeOnly:
            hasAccess = false
            accessDenied = true
            isLoading = false
        case .denied, .restricted:
            hasAccess = false
            accessDenied = true
            isLoading = false
        case .notDetermined:
            isLoading = true
        @unknown default:
            break
        }
    }
    
    private func requestAccess() {
        // Use the appropriate method based on availability
        if #available(macOS 14.0, *) {
            eventStore.requestFullAccessToEvents { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.handleAccessResult(granted: granted, error: error)
                }
            }
        } else {
            // Fallback for macOS 13
            eventStore.requestAccess(to: .event) { [weak self] granted, error in
                DispatchQueue.main.async {
                    self?.handleAccessResult(granted: granted, error: error)
                }
            }
        }
    }
    
    private func handleAccessResult(granted: Bool, error: Error?) {
        hasAccess = granted
        accessDenied = !granted
        isLoading = false
        
        if granted {
            fetchTodayEvents()
        }
    }
    
    private func fetchTodayEvents() {
        let calendar = Calendar.current
        let now = Date()
        
        guard let startOfDay = calendar.date(bySettingHour: 0, minute: 0, second: 0, of: now),
              let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) else {
            return
        }
        
        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil // All calendars
        )
        
        let events = eventStore.events(matching: predicate)
            .sorted { ($0.startDate ?? Date.distantFuture) < ($1.startDate ?? Date.distantFuture) }
        
        DispatchQueue.main.async {
            self.todayEvents = events
            self.isLoading = false
        }
    }
    
    private func setupRefreshTimer() {
        // Refresh events every minute to keep "next event" accurate
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.fetchTodayEvents()
        }
        refreshTimer?.tolerance = 10
    }
    
    @objc private func calendarChanged(_ notification: Notification) {
        fetchTodayEvents()
    }
}
