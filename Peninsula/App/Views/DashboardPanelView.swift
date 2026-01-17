// DashboardPanelView.swift
// Peninsula

import SwiftUI

/// Main dashboard panel view that appears when no music is playing.
/// Layout matches the Dynamic Island-style reference design.
struct DashboardPanelView: View {
    @ObservedObject var weatherService: WeatherService
    @ObservedObject var calendarService: CalendarService
    
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Left: Weather Widget
            WeatherWidgetView(weatherService: weatherService)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Center: Clock Widget
            ClockWidgetView()
                .frame(maxWidth: .infinity, alignment: .center)
            
            // Right: Calendar Widget
            CalendarWidgetView(calendarService: calendarService)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .frame(width: 480, height: 200)
    }
}

#if DEBUG
struct DashboardPanelView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            DashboardPanelView(
                weatherService: WeatherService(),
                calendarService: CalendarService()
            )
        }
        .frame(width: 530, height: 260)
    }
}
#endif
