import SwiftUI
import Combine

struct MusicPanelView: View {
    @Bindable var musicService: MusicService
    @State private var isSeeking: Bool = false
    @State private var seekPosition: Double = 0
    @State private var isHoveringProgress: Bool = false
    @State private var isPressingPlay: Bool = false
    @State private var isPressingPrev: Bool = false
    @State private var isPressingNext: Bool = false
    @State private var isHoveringPlay: Bool = false
    @State private var isHoveringPrev: Bool = false
    @State private var isHoveringNext: Bool = false
    
    private var accentColor: Color {
        Color(nsColor: musicService.accentColor)
    }
    
    var body: some View {
        if musicService.activeApp != nil {
            VStack(spacing: 0) {
                Spacer().frame(height: 8)
                topSection
                Spacer()
                progressSection
                Spacer().frame(height: 14)
                controlsSection
                Spacer().frame(height: 20)
            }
            .frame(width: 480, height: 200)
        } else {
            emptyStateView
                .frame(width: 480, height: 200)
        }
    }
    
    private var topSection: some View {
        HStack(spacing: 16) {
            artworkView
            
            VStack(alignment: .leading, spacing: 4) {
                Text(musicService.trackName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Text(musicService.artistName)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            
            Spacer()
            
            if musicService.isPlaying {
                BarEqualizerView(accentColor: accentColor)
            }
        }
        .padding(.horizontal, 32)
    }
    
    private var artworkView: some View {
        ZStack {
            if musicService.isPlaying {
                PulseRingView(color: accentColor)
            }
            
            Group {
                if let artwork = musicService.artwork {
                    Image(nsImage: artwork)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .shadow(color: accentColor.opacity(0.5), radius: 12, y: 2)
                } else {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.08))
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                }
            }
        }
        .frame(width: 80, height: 80)
    }
    
    private var progressSection: some View {
        HStack(spacing: 12) {
            Text(formatTime(isSeeking ? seekPosition : musicService.currentPosition))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 40, alignment: .trailing)
            
            GeometryReader { geometry in
                let currentProgress = progressWidth(in: geometry.size.width)
                
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.12))
                        .frame(height: isHoveringProgress || isSeeking ? 6 : 4)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [accentColor, accentColor.opacity(0.7)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: currentProgress, height: isHoveringProgress || isSeeking ? 6 : 4)
                        .shadow(color: isSeeking ? accentColor.opacity(0.6) : .clear, radius: 8)
                    
                    if isHoveringProgress || isSeeking {
                        Circle()
                            .fill(.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: accentColor.opacity(0.5), radius: 6)
                            .offset(x: max(0, min(geometry.size.width - 14, currentProgress - 7)))
                    }
                }
                .frame(height: 14)
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHoveringProgress = hovering
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isSeeking = true
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            seekPosition = progress * musicService.duration
                        }
                        .onEnded { _ in
                            musicService.seek(to: seekPosition)
                            isSeeking = false
                        }
                )
            }
            .frame(height: 14)
            
            Text(formatTime(musicService.duration))
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.5))
                .frame(width: 40, alignment: .leading)
        }
        .padding(.horizontal, 32)
        .animation(.easeInOut(duration: 0.15), value: isHoveringProgress)
        .animation(.easeInOut(duration: 0.15), value: isSeeking)
    }
    
    private func progressWidth(in totalWidth: CGFloat) -> CGFloat {
        guard musicService.duration > 0 else { return 0 }
        let currentPos = isSeeking ? seekPosition : musicService.currentPosition
        let progress = currentPos / musicService.duration
        return max(0, min(totalWidth, totalWidth * progress))
    }
    
    private var controlsSection: some View {
        HStack(spacing: 20) {
            Button(action: { musicService.previousTrack() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [accentColor.opacity(isHoveringPrev ? 0.5 : 0.3), accentColor.opacity(isHoveringPrev ? 0.2 : 0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Circle()
                                .stroke(accentColor.opacity(isHoveringPrev ? 0.7 : 0.4), lineWidth: isHoveringPrev ? 1.5 : 1)
                        }
                    )
                    .shadow(color: accentColor.opacity(isHoveringPrev ? 0.4 : 0.2), radius: isHoveringPrev ? 12 : 8, y: 2)
                    .scaleEffect(isPressingPrev ? 0.9 : (isHoveringPrev ? 1.08 : 1.0))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHoveringPrev = hovering
                }
            }
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressingPrev = pressing
                }
            }, perform: {})
            
            Button(action: { musicService.playPause() }) {
                Image(systemName: musicService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [accentColor, accentColor.opacity(isHoveringPlay ? 0.85 : 0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Circle()
                                .fill(.white.opacity(isHoveringPlay ? 0.25 : 0.15))
                                .blur(radius: 2)
                                .offset(y: -2)
                                .mask(Circle())
                        }
                    )
                    .shadow(color: accentColor.opacity(isHoveringPlay ? 0.8 : 0.6), radius: isHoveringPlay ? 20 : 16, y: 4)
                    .scaleEffect(isPressingPlay ? 0.9 : (isHoveringPlay ? 1.08 : 1.0))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHoveringPlay = hovering
                }
            }
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressingPlay = pressing
                }
            }, perform: {})
            
            Button(action: { musicService.nextTrack() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [accentColor.opacity(isHoveringNext ? 0.5 : 0.3), accentColor.opacity(isHoveringNext ? 0.2 : 0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            Circle()
                                .stroke(accentColor.opacity(isHoveringNext ? 0.7 : 0.4), lineWidth: isHoveringNext ? 1.5 : 1)
                        }
                    )
                    .shadow(color: accentColor.opacity(isHoveringNext ? 0.4 : 0.2), radius: isHoveringNext ? 12 : 8, y: 2)
                    .scaleEffect(isPressingNext ? 0.9 : (isHoveringNext ? 1.08 : 1.0))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHoveringNext = hovering
                }
            }
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressingNext = pressing
                }
            }, perform: {})
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.15))
            
            Text(String(localized: "Not Playing"))
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.white.opacity(0.35))
            
            Text(String(localized: "Open Apple Music or Spotify"))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.2))
                .multilineTextAlignment(.center)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

struct PulseRingView: View {
    let color: Color
    
    @State private var scale: CGFloat = 1.0
    @State private var opacity: Double = 0.6
    
    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .stroke(color.opacity(opacity / Double(index + 1)), lineWidth: 2)
                    .frame(width: 64, height: 64)
                    .scaleEffect(scale + CGFloat(index) * 0.15)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                scale = 1.3
                opacity = 0.2
            }
        }
    }
}

struct BarEqualizerView: View {
    let accentColor: Color
    
    @State private var heights: [CGFloat] = [0.4, 0.7, 0.5, 0.8, 0.3]
    
    private let timer = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 4, height: 10 + heights[index] * 18)
                    .shadow(color: accentColor.opacity(0.4), radius: 4)
            }
        }
        .frame(height: 28)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.12)) {
                heights = heights.map { _ in CGFloat.random(in: 0.2...1.0) }
            }
        }
    }
}





