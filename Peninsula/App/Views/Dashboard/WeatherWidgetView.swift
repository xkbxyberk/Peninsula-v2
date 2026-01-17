// WeatherWidgetView.swift
// Peninsula

import SwiftUI

/// Widget displaying current weather information.
/// Shows weather icon, temperature, location name, and condition.
struct WeatherWidgetView: View {
    @ObservedObject var weatherService: WeatherService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Weather condition icon
            Image(systemName: weatherService.conditionSymbol)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
            
            // Temperature
            Text(weatherService.temperature)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
            
            // Location name
            Text(weatherService.locationName.isEmpty ? String(localized: "Loading...") : weatherService.locationName)
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
            
            // Condition description
            if !weatherService.conditionDescription.isEmpty {
                Text(weatherService.conditionDescription)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
                    .lineLimit(1)
            }
        }
        .frame(minWidth: 80, alignment: .leading)
    }
}

#if DEBUG
struct WeatherWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            WeatherWidgetView(weatherService: WeatherService())
                .padding()
        }
        .frame(width: 150, height: 150)
    }
}
#endif
