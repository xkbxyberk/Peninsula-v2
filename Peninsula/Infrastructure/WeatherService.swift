// WeatherService.swift
// Peninsula

import Foundation
import WeatherKit
import CoreLocation
import Combine

/// Service for fetching weather data using Apple's WeatherKit API.
/// Requires `com.apple.developer.weatherkit` entitlement.
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
    private var lastFetchTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
    /// Minimum interval between weather fetches (5 minutes)
    private let fetchInterval: TimeInterval = 300
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - Setup
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 1000 // Update every 1km
    }
    
    // MARK: - Public Methods
    
    /// Request location permission and start fetching weather
    func startMonitoring() {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.hasError = true
                self.isLoading = false
                self.locationName = String(localized: "Location Denied")
            }
        @unknown default:
            break
        }
    }
    
    /// Force refresh weather data
    func refresh() {
        guard let location = currentLocation else {
            locationManager.requestLocation()
            return
        }
        fetchWeather(for: location)
    }
    
    // MARK: - Private Methods
    
    private func fetchWeather(for location: CLLocation) {
        // Check if we should throttle the request
        if let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < fetchInterval {
            return
        }
        
        isLoading = true
        lastFetchTime = Date()
        
        Task { @MainActor in
            do {
                let weather = try await weatherService.weather(for: location)
                updateWeatherData(weather.currentWeather)
                await updateLocationName(for: location)
            } catch {
                self.hasError = true
                self.isLoading = false
            }
        }
    }
    
    @MainActor
    private func updateWeatherData(_ current: CurrentWeather) {
        // Format temperature
        let temp = current.temperature.value
        let unit = current.temperature.unit
        
        if unit == .celsius {
            temperature = String(format: "%.0f°", temp)
        } else {
            temperature = String(format: "%.0f°F", temp)
        }
        
        // Map condition to SF Symbol
        conditionSymbol = mapConditionToSymbol(current.condition)
        conditionDescription = current.condition.description
        
        isLoading = false
        hasError = false
    }
    
    private func updateLocationName(for location: CLLocation) async {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            if let placemark = placemarks.first {
                await MainActor.run {
                    self.locationName = placemark.locality ?? placemark.administrativeArea ?? String(localized: "Unknown")
                }
            }
        } catch {
            await MainActor.run {
                self.locationName = String(localized: "Unknown")
            }
        }
    }
    
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
}

// MARK: - CLLocationManagerDelegate

extension WeatherService: CLLocationManagerDelegate {
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .denied, .restricted:
            DispatchQueue.main.async {
                self.hasError = true
                self.isLoading = false
                self.locationName = String(localized: "Location Denied")
            }
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only update if moved significantly or first location
        if currentLocation == nil ||
           location.distance(from: currentLocation!) > 1000 {
            currentLocation = location
            fetchWeather(for: location)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.hasError = true
            self.isLoading = false
        }
    }
}
