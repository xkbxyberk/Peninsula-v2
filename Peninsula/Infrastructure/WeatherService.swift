// WeatherService.swift
// Peninsula
//
// Optimized WeatherKit service with intelligent caching and cost management.
// Target: Reduce API calls by 95%+ through smart caching strategies.

import Foundation
import WeatherKit
import CoreLocation
import Combine
import AppKit

// MARK: - Cache Models

/// Volatility level determines cache duration
enum WeatherVolatility: String, Codable {
    case stable     // Clear, sunny → longer cache
    case moderate   // Partly cloudy → normal cache
    case volatile   // Rain, storms → shorter cache
    
    var cacheDurationMultiplier: Double {
        switch self {
        case .stable: return 2.0
        case .moderate: return 1.0
        case .volatile: return 0.5
        }
    }
}

/// Cached location for comparison
struct CachedLocation: Codable {
    let latitude: Double
    let longitude: Double
    
    init(from location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
    }
    
    func toCLLocation() -> CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
    
    func distance(to location: CLLocation) -> CLLocationDistance {
        toCLLocation().distance(from: location)
    }
}

/// Hourly weather data for interpolation
struct CachedHourlyWeather: Codable {
    let date: Date
    let temperature: Double
    let conditionCode: String // WeatherCondition raw string
    let symbolName: String
}

/// Complete weather cache structure
struct WeatherCache: Codable {
    let temperature: Double
    let temperatureUnit: String
    let conditionCode: String
    let symbolName: String
    let conditionDescription: String
    let locationName: String
    let location: CachedLocation
    let fetchTime: Date
    let volatility: WeatherVolatility
    let hourlyForecast: [CachedHourlyWeather]
    
    /// Check if cache is still valid based on volatility and time of day
    func isValid(currentLocation: CLLocation?) -> Bool {
        let age = Date().timeIntervalSince(fetchTime)
        let maxAge = calculateMaxAge()
        
        // Check time validity
        guard age < maxAge else {
            print("[WeatherService] 📊 Cache expired: age=\(Int(age))s, maxAge=\(Int(maxAge))s")
            return false
        }
        
        // Check location validity (10km threshold)
        if let current = currentLocation {
            let distance = location.distance(to: current)
            if distance > 10000 { // 10 km
                print("[WeatherService] 📍 Cache invalid: location moved \(Int(distance))m")
                return false
            }
        }
        
        return true
    }
    
    /// Calculate max cache age based on volatility and time of day
    private func calculateMaxAge() -> TimeInterval {
        // Base interval: 45 minutes
        var baseInterval: TimeInterval = 2700
        
        // Night time (23:00 - 07:00): extend to 3 hours
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 7 || hour >= 23 {
            baseInterval = 10800 // 3 hours
        }
        
        // Apply volatility multiplier
        let adjusted = baseInterval * volatility.cacheDurationMultiplier
        
        // Apply usage limit multiplier
        let usageMultiplier = WeatherUsageTracker.shared.cacheMultiplier
        
        return adjusted * usageMultiplier
    }
    
    /// Get current weather from hourly forecast based on current time
    func interpolatedWeather() -> (temp: Double, symbol: String, condition: String)? {
        let now = Date()
        let calendar = Calendar.current
        let currentHour = calendar.component(.hour, from: now)
        
        // Find matching hourly forecast
        if let hourly = hourlyForecast.first(where: {
            calendar.component(.hour, from: $0.date) == currentHour &&
            calendar.isDate($0.date, inSameDayAs: now)
        }) {
            return (hourly.temperature, hourly.symbolName, hourly.conditionCode)
        }
        
        // Fallback to cached current weather
        return nil
    }
}

// MARK: - Usage Tracker

/// Tracks monthly API usage and adjusts cache duration accordingly
final class WeatherUsageTracker {
    static let shared = WeatherUsageTracker()
    
    private let monthlyLimit = 10_000
    private let queryCountKey = "weatherkit_monthly_queries"
    private let monthKey = "weatherkit_month"
    
    private init() {
        resetIfNewMonth()
    }
    
    var queryCount: Int {
        get { UserDefaults.standard.integer(forKey: queryCountKey) }
        set { UserDefaults.standard.set(newValue, forKey: queryCountKey) }
    }
    
    private var currentMonth: Int {
        get { UserDefaults.standard.integer(forKey: monthKey) }
        set { UserDefaults.standard.set(newValue, forKey: monthKey) }
    }
    
    /// Multiplier to extend cache duration when approaching limit
    var cacheMultiplier: Double {
        let usage = Double(queryCount) / Double(monthlyLimit)
        switch usage {
        case 0..<0.5: return 1.0      // Normal
        case 0.5..<0.75: return 1.5   // Extend by 50%
        case 0.75..<0.9: return 2.0   // Double cache time
        default: return 4.0           // Emergency: 4x cache
        }
    }
    
    func recordQuery() {
        resetIfNewMonth()
        queryCount += 1
        print("[WeatherService] 📊 Monthly queries: \(queryCount)/\(monthlyLimit) (multiplier: \(cacheMultiplier)x)")
    }
    
    private func resetIfNewMonth() {
        let month = Calendar.current.component(.month, from: Date())
        if currentMonth != month {
            currentMonth = month
            queryCount = 0
            print("[WeatherService] 📊 New month detected, resetting query count")
        }
    }
}

// MARK: - Weather Service

/// Optimized weather service with intelligent caching
final class WeatherService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var temperature: String = "--°"
    @Published private(set) var conditionSymbol: String = "cloud"
    @Published private(set) var conditionDescription: String = ""
    @Published private(set) var locationName: String = ""
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var hasError: Bool = false
    
    // MARK: - Private Properties
    
    private let weatherService = WeatherKit.WeatherService.shared
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    private var currentLocation: CLLocation?
    private var cache: WeatherCache?
    private var cancellables = Set<AnyCancellable>()
    private var isSystemAwake = true
    private var pendingLocationUpdate: CLLocation?
    
    private let cacheKey = "weatherCache_v2"
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupLocationManager()
        setupSystemNotifications()
        loadCacheFromDisk()
    }
    
    // MARK: - Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 10000 // 10 km - reduced sensitivity
    }
    
    private func setupSystemNotifications() {
        let workspace = NSWorkspace.shared.notificationCenter
        
        // Sleep/Wake
        workspace.addObserver(self, selector: #selector(systemWillSleep),
                              name: NSWorkspace.willSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(systemDidWake),
                              name: NSWorkspace.didWakeNotification, object: nil)
        
        // Screen sleep/wake
        workspace.addObserver(self, selector: #selector(screenDidSleep),
                              name: NSWorkspace.screensDidSleepNotification, object: nil)
        workspace.addObserver(self, selector: #selector(screenDidWake),
                              name: NSWorkspace.screensDidWakeNotification, object: nil)
    }
    
    // MARK: - System Event Handlers
    
    @objc private func systemWillSleep() {
        print("[WeatherService] 😴 System going to sleep, pausing operations")
        isSystemAwake = false
        locationManager.stopUpdatingLocation()
    }
    
    @objc private func systemDidWake() {
        print("[WeatherService] ⏰ System woke up")
        isSystemAwake = true
        // Don't immediately fetch - wait for dashboard to open
    }
    
    @objc private func screenDidSleep() {
        print("[WeatherService] 🖥️ Screen sleeping, pausing location updates")
        locationManager.stopUpdatingLocation()
    }
    
    @objc private func screenDidWake() {
        print("[WeatherService] 🖥️ Screen woke up")
        // Resume location updates only if we have authorization
        // macOS uses .authorized instead of .authorizedWhenInUse
        if locationManager.authorizationStatus == .authorized ||
           locationManager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    // MARK: - Public Methods
    
    /// Request location permission and prepare for weather fetching
    /// NOTE: Does NOT immediately fetch weather - waits for dashboard to open
    func startMonitoring() {
        let status = locationManager.authorizationStatus
        print("[WeatherService] 📍 startMonitoring called, authorization status: \(status.rawValue)")
        
        switch status {
        case .notDetermined:
            print("[WeatherService] 📍 Requesting location authorization...")
            locationManager.requestWhenInUseAuthorization()
        case .authorized, .authorizedAlways:
            print("[WeatherService] 📍 Location authorized, starting updates...")
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            print("[WeatherService] ❌ Location access denied or restricted")
            DispatchQueue.main.async {
                self.hasError = true
                self.isLoading = false
                self.locationName = String(localized: "Location Denied")
            }
        @unknown default:
            print("[WeatherService] ⚠️ Unknown authorization status: \(status.rawValue)")
            break
        }
    }
    
    /// Called when Dashboard becomes visible - the main trigger for weather updates
    /// Implements Stale-While-Revalidate strategy
    func fetchIfNeeded() {
        print("[WeatherService] 🎯 fetchIfNeeded called (Dashboard opened)")
        
        // 1. Immediately show cached data (Stale-While-Revalidate)
        if let cached = cache {
            applyCacheToUI(cached)
            print("[WeatherService] ✅ Showing cached data from \(Int(Date().timeIntervalSince(cached.fetchTime)))s ago")
            
            // Check if cache is still valid
            if cached.isValid(currentLocation: currentLocation) {
                print("[WeatherService] ✅ Cache still valid, skipping API call")
                return
            }
        } else {
            // Try loading from disk
            if let diskCache = loadCacheFromDiskSync() {
                cache = diskCache
                applyCacheToUI(diskCache)
                print("[WeatherService] 💾 Loaded cache from disk")
                
                if diskCache.isValid(currentLocation: currentLocation) {
                    print("[WeatherService] ✅ Disk cache still valid, skipping API call")
                    return
                }
            }
        }
        
        // 2. Fetch fresh data if needed
        guard let location = currentLocation ?? pendingLocationUpdate else {
            print("[WeatherService] ⚠️ No location available, requesting...")
            isLoading = cache == nil // Only show loading if no cache
            locationManager.requestLocation()
            return
        }
        
        fetchWeather(for: location)
    }
    
    /// Force refresh weather data (ignores cache)
    func refresh() {
        guard let location = currentLocation else {
            locationManager.requestLocation()
            return
        }
        
        // Clear cache timestamp to force refresh
        cache = nil
        fetchWeather(for: location)
    }
    
    // MARK: - Private Methods
    
    private func fetchWeather(for location: CLLocation) {
        guard isSystemAwake else {
            print("[WeatherService] 😴 System is sleeping, skipping fetch")
            return
        }
        
        print("[WeatherService] 🌤️ Fetching weather for: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Only show loading if we don't have any data to display
        if cache == nil {
            isLoading = true
        }
        
        Task { @MainActor in
            do {
                // Fetch current weather AND hourly forecast (12 hours)
                // WeatherKit returns a tuple when requesting multiple data types
                let (currentWeather, hourlyForecast) = try await weatherService.weather(
                    for: location,
                    including: .current, .hourly
                )
                
                // Record API usage
                WeatherUsageTracker.shared.recordQuery()
                
                print("[WeatherService] ✅ Weather fetched: \(currentWeather.temperature)")
                
                // Determine volatility
                let volatility = determineVolatility(currentWeather.condition)
                
                // Create hourly forecast cache (next 12 hours)
                let hourlyCache = hourlyForecast.prefix(12).map { hourly in
                    CachedHourlyWeather(
                        date: hourly.date,
                        temperature: hourly.temperature.value,
                        conditionCode: String(describing: hourly.condition),
                        symbolName: mapConditionToSymbol(hourly.condition)
                    )
                }
                
                // Get location name
                let locName = await fetchLocationName(for: location)
                
                // Create cache
                let newCache = WeatherCache(
                    temperature: currentWeather.temperature.value,
                    temperatureUnit: currentWeather.temperature.unit == .celsius ? "C" : "F",
                    conditionCode: String(describing: currentWeather.condition),
                    symbolName: mapConditionToSymbol(currentWeather.condition),
                    conditionDescription: currentWeather.condition.description,
                    locationName: locName,
                    location: CachedLocation(from: location),
                    fetchTime: Date(),
                    volatility: volatility,
                    hourlyForecast: Array(hourlyCache)
                )
                
                // Save to memory and disk
                cache = newCache
                saveCacheToDisk(newCache)
                
                // Update UI
                applyCacheToUI(newCache)
                
            } catch {
                print("[WeatherService] ❌ WeatherKit Error: \(error.localizedDescription)")
                print("[WeatherService] ❌ Full error: \(error)")
                
                // Show error only if we have no cached data
                if cache == nil {
                    hasError = true
                    isLoading = false
                    locationName = String(localized: "Weather unavailable")
                }
            }
        }
    }
    
    private func applyCacheToUI(_ cached: WeatherCache) {
        // Try to use interpolated hourly data first
        if let interpolated = cached.interpolatedWeather() {
            let temp = interpolated.temp
            temperature = cached.temperatureUnit == "C" 
                ? String(format: "%.0f°", temp)
                : String(format: "%.0f°F", temp)
            conditionSymbol = interpolated.symbol
            conditionDescription = interpolated.condition
        } else {
            // Fallback to cached current weather
            temperature = cached.temperatureUnit == "C"
                ? String(format: "%.0f°", cached.temperature)
                : String(format: "%.0f°F", cached.temperature)
            conditionSymbol = cached.symbolName
            conditionDescription = cached.conditionDescription
        }
        
        locationName = cached.locationName
        isLoading = false
        hasError = false
    }
    
    private func determineVolatility(_ condition: WeatherCondition) -> WeatherVolatility {
        switch condition {
        case .clear, .mostlyClear, .hot:
            return .stable
        case .partlyCloudy, .mostlyCloudy, .cloudy, .foggy, .haze, .breezy:
            return .moderate
        case .rain, .heavyRain, .thunderstorms, .isolatedThunderstorms,
             .scatteredThunderstorms, .strongStorms, .snow, .heavySnow,
             .blizzard, .hurricane, .tropicalStorm:
            return .volatile
        default:
            return .moderate
        }
    }
    
    private func fetchLocationName(for location: CLLocation) async -> String {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                return placemark.locality ?? placemark.administrativeArea ?? String(localized: "Unknown")
            }
        } catch {
            print("[WeatherService] ⚠️ Geocoder error: \(error.localizedDescription)")
        }
        return String(localized: "Unknown")
    }
    
    // MARK: - Disk Cache
    
    private func saveCacheToDisk(_ cache: WeatherCache) {
        if let data = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(data, forKey: cacheKey)
            print("[WeatherService] 💾 Cache saved to disk")
        }
    }
    
    private func loadCacheFromDisk() {
        if let cached = loadCacheFromDiskSync() {
            cache = cached
            applyCacheToUI(cached)
            isLoading = false
            print("[WeatherService] 💾 Loaded cache from disk on init")
        }
    }
    
    private func loadCacheFromDiskSync() -> WeatherCache? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(WeatherCache.self, from: data)
        else { return nil }
        return cached
    }
    
    // MARK: - Condition Mapping
    
    private func mapConditionToSymbol(_ condition: WeatherCondition) -> String {
        switch condition {
        case .clear:
            return isNightTime() ? "moon.stars.fill" : "sun.max.fill"
        case .mostlyClear:
            return isNightTime() ? "moon.fill" : "sun.min.fill"
        case .partlyCloudy:
            return isNightTime() ? "cloud.moon.fill" : "cloud.sun.fill"
        case .mostlyCloudy:
            return "cloud.fill"
        case .cloudy:
            return "smoke.fill"
        case .foggy:
            return "cloud.fog.fill"
        case .haze:
            return "sun.haze.fill"
        case .smoky:
            return "smoke.fill"
        case .breezy, .windy:
            return "wind"
        case .drizzle:
            return "cloud.drizzle.fill"
        case .rain:
            return "cloud.rain.fill"
        case .heavyRain:
            return "cloud.heavyrain.fill"
        case .flurries:
            return "cloud.snow.fill"
        case .snow:
            return "snowflake"
        case .heavySnow:
            return "snowflake"
        case .sleet:
            return "cloud.sleet.fill"
        case .freezingRain:
            return "cloud.sleet.fill"
        case .freezingDrizzle:
            return "cloud.sleet.fill"
        case .hail:
            return "cloud.hail.fill"
        case .thunderstorms:
            return "cloud.bolt.fill"
        case .isolatedThunderstorms, .scatteredThunderstorms, .strongStorms:
            return "cloud.bolt.rain.fill"
        case .hurricane:
            return "hurricane"
        case .tropicalStorm:
            return "tropicalstorm"
        case .blizzard:
            return "wind.snow"
        case .blowingSnow:
            return "wind.snow"
        case .sunShowers:
            return "sun.rain.fill"
        case .hot:
            return "thermometer.sun.fill"
        case .frigid:
            return "thermometer.snowflake"
        case .wintryMix:
            return "cloud.sleet.fill"
        case .sunFlurries:
            return "sun.snow.fill"
        case .blowingDust:
            return "sun.dust.fill"
        @unknown default:
            return "cloud.fill"
        }
    }
    
    private func isNightTime() -> Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 6 || hour >= 20
    }
    
    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }
}

// MARK: - CLLocationManagerDelegate

extension WeatherService: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        print("[WeatherService] 📍 Authorization changed to: \(manager.authorizationStatus.rawValue)")
        
        switch manager.authorizationStatus {
        case .authorized, .authorizedAlways:
            print("[WeatherService] 📍 Location authorized, starting updates...")
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("[WeatherService] ❌ Location access denied or restricted")
            DispatchQueue.main.async {
                self.hasError = true
                self.isLoading = false
                self.locationName = String(localized: "Location Denied")
            }
        case .notDetermined:
            print("[WeatherService] ⏳ Location authorization not determined yet")
        @unknown default:
            print("[WeatherService] ⚠️ Unknown authorization status")
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        print("[WeatherService] 📍 Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
        
        // Store for batch update
        pendingLocationUpdate = location
        
        // Only update currentLocation if moved significantly (10km)
        if currentLocation == nil {
            currentLocation = location
            print("[WeatherService] 📍 Initial location set")
        } else if location.distance(from: currentLocation!) > 10000 {
            currentLocation = location
            print("[WeatherService] 📍 Location changed significantly (>10km)")
            // Don't immediately fetch - wait for dashboard to open
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[WeatherService] ❌ Location error: \(error.localizedDescription)")
        print("[WeatherService] ❌ Full location error: \(error)")
        
        // Only show error if we have no cache
        if cache == nil {
            DispatchQueue.main.async {
                self.hasError = true
                self.isLoading = false
                self.locationName = String(localized: "Location error")
            }
        }
    }
}
