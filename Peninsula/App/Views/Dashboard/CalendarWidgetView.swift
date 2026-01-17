// CalendarWidgetView.swift
// Peninsula

import SwiftUI
import EventKit

/// Widget displaying today's calendar summary.
/// Shows "Today" label with calendar icon and event count.
struct CalendarWidgetView: View {
    @ObservedObject var calendarService: CalendarService
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 12) {
            // Today button with calendar icon
            HStack(spacing: 6) {
                Text(String(localized: "Today"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                
                Image(systemName: "calendar")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white.opacity(0.1))
                    )
            }
            
            // Event count or status
            Text(calendarService.eventCountText)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.5))
            
            // Next event preview (if available)
            if let nextEvent = calendarService.nextEvent {
                NextEventView(event: nextEvent)
            }
        }
        .frame(minWidth: 100, alignment: .trailing)
    }
}

/// Shows the next upcoming event
struct NextEventView: View {
    let event: EKEvent
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(event.title ?? "")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .lineLimit(1)
            
            if let startDate = event.startDate {
                Text(timeFormatter.string(from: startDate))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
    }
}

#if DEBUG
struct CalendarWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            CalendarWidgetView(calendarService: CalendarService())
                .padding()
        }
        .frame(width: 200, height: 150)
    }
}
#endif
