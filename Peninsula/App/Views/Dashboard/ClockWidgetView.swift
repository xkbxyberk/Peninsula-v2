// ClockWidgetView.swift
// Peninsula

import SwiftUI
import Combine

/// Widget displaying current time and date.
/// Shows large time display with localized date format.
struct ClockWidgetView: View {
    @State private var currentTime = Date()
    
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM EEEE"
        formatter.locale = Locale.current
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            // Time display
            Text(timeFormatter.string(from: currentTime))
                .font(.system(size: 48, weight: .light, design: .default))
                .foregroundStyle(.white)
                .monospacedDigit()
            
            // Date display
            Text(dateFormatter.string(from: currentTime))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.white.opacity(0.6))
        }
        .onReceive(timer) { newTime in
            currentTime = newTime
        }
    }
}

#if DEBUG
struct ClockWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            ClockWidgetView()
                .padding()
        }
        .frame(width: 200, height: 150)
    }
}
#endif
