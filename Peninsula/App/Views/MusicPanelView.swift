import SwiftUI
import Combine

struct MusicPanelView: View {
    @ObservedObject var musicService: MusicService
    @State private var isSeeking: Bool = false
    @State private var seekPosition: Double = 0
    @State private var isHoveringProgress: Bool = false
    @State private var isPressingPlay: Bool = false
    @State private var isPressingPrev: Bool = false
    @State private var isPressingNext: Bool = false
    @State private var isHoveringPlay: Bool = false
    @State private var isHoveringPrev: Bool = false
    @State private var isHoveringNext: Bool = false
    @State private var isHoveringShuffle: Bool = false
    @State private var isPressingShuffle: Bool = false
    @State private var isHoveringAudio: Bool = false
    @State private var isPressingAudio: Bool = false
    @State private var showAudioPopover: Bool = false
    
    private let audioService = AudioOutputService.shared
    
    init(musicService: MusicService) {
        self.musicService = musicService
    }
    
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
            VinylRecordView(
                artwork: musicService.artwork,
                isPlaying: musicService.isPlaying,
                accentColor: accentColor
            )
            
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
                            if !isSeeking {
                                isSeeking = true
                                musicService.isSeeking = true
                            }
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            seekPosition = progress * musicService.duration
                        }
                        .onEnded { _ in
                            musicService.seek(to: seekPosition)
                            musicService.isSeeking = false
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
        HStack(spacing: 12) {
            Button(action: { musicService.toggleShuffle() }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(musicService.shuffleEnabled ? accentColor : .white.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(musicService.shuffleEnabled ? accentColor.opacity(0.2) : .white.opacity(0.05))
                            .overlay(
                                Circle()
                                    .stroke(musicService.shuffleEnabled ? accentColor.opacity(0.5) : .white.opacity(0.1), lineWidth: 1)
                            )
                    )
                    .scaleEffect(isPressingShuffle ? 0.9 : (isHoveringShuffle ? 1.08 : 1.0))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) { isHoveringShuffle = hovering }
            }
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressingShuffle = pressing }
            }, perform: {})
            
            Spacer().frame(width: 8)
            
            Button(action: { musicService.previousTrack() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        ZStack {
                            Circle().fill(.ultraThinMaterial)
                            Circle().fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(isHoveringPrev ? 0.5 : 0.3), accentColor.opacity(isHoveringPrev ? 0.2 : 0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            Circle().stroke(accentColor.opacity(isHoveringPrev ? 0.7 : 0.4), lineWidth: 1)
                        }
                    )
                    .shadow(color: accentColor.opacity(isHoveringPrev ? 0.3 : 0.15), radius: isHoveringPrev ? 10 : 6, y: 2)
                    .scaleEffect(isPressingPrev ? 0.9 : (isHoveringPrev ? 1.08 : 1.0))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) { isHoveringPrev = hovering }
            }
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressingPrev = pressing }
            }, perform: {})
            
            Button(action: { musicService.playPause() }) {
                Image(systemName: musicService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(
                        ZStack {
                            Circle().fill(
                                LinearGradient(
                                    colors: [accentColor, accentColor.opacity(isHoveringPlay ? 0.85 : 0.7)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            Circle().fill(.white.opacity(isHoveringPlay ? 0.25 : 0.15)).blur(radius: 2).offset(y: -2).mask(Circle())
                        }
                    )
                    .shadow(color: accentColor.opacity(isHoveringPlay ? 0.7 : 0.5), radius: isHoveringPlay ? 16 : 12, y: 3)
                    .scaleEffect(isPressingPlay ? 0.9 : (isHoveringPlay ? 1.08 : 1.0))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) { isHoveringPlay = hovering }
            }
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressingPlay = pressing }
            }, perform: {})
            
            Button(action: { musicService.nextTrack() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(
                        ZStack {
                            Circle().fill(.ultraThinMaterial)
                            Circle().fill(
                                LinearGradient(
                                    colors: [accentColor.opacity(isHoveringNext ? 0.5 : 0.3), accentColor.opacity(isHoveringNext ? 0.2 : 0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            Circle().stroke(accentColor.opacity(isHoveringNext ? 0.7 : 0.4), lineWidth: 1)
                        }
                    )
                    .shadow(color: accentColor.opacity(isHoveringNext ? 0.3 : 0.15), radius: isHoveringNext ? 10 : 6, y: 2)
                    .scaleEffect(isPressingNext ? 0.9 : (isHoveringNext ? 1.08 : 1.0))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) { isHoveringNext = hovering }
            }
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressingNext = pressing }
            }, perform: {})
            
            Spacer().frame(width: 8)
            
            Button(action: { showAudioPopover.toggle() }) {
                Image(systemName: "airplayaudio")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(.white.opacity(0.05))
                            .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 1))
                    )
                    .scaleEffect(isPressingAudio ? 0.9 : (isHoveringAudio ? 1.08 : 1.0))
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) { isHoveringAudio = hovering }
            }
            .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { isPressingAudio = pressing }
            }, perform: {})
            .popover(isPresented: $showAudioPopover, arrowEdge: .bottom) {
                audioOutputPopover
            }
        }
    }
    
    private var audioOutputPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Output Device")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.top, 8)
            
            Divider()
            
            ForEach(audioService.outputDevices) { device in
                Button(action: {
                    audioService.setOutputDevice(device)
                    showAudioPopover = false
                }) {
                    HStack {
                        Image(systemName: device.isDefault ? "checkmark.circle.fill" : "speaker.wave.2")
                            .foregroundStyle(device.isDefault ? .blue : .secondary)
                            .frame(width: 20)
                        
                        Text(device.name)
                            .font(.system(size: 13))
                            .foregroundStyle(.primary)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(device.isDefault ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .frame(minWidth: 200)
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

struct VinylRecordView: View {
    let artwork: NSImage?
    let isPlaying: Bool
    let accentColor: Color
    
    @State private var rotation: Double = 0
    @State private var waveScale1: CGFloat = 1.0
    @State private var waveScale2: CGFloat = 1.0
    @State private var waveScale3: CGFloat = 1.0
    @State private var waveOpacity1: Double = 0.5
    @State private var waveOpacity2: Double = 0.5
    @State private var waveOpacity3: Double = 0.5
    @State private var displayedArtwork: NSImage?
    
    private let discSize: CGFloat = 90
    private let labelSize: CGFloat = 50
    private let spindleSize: CGFloat = 8
    
    private let rotationTimer = Timer.publish(every: 1.0/60.0, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            if isPlaying {
                Circle()
                    .stroke(accentColor.opacity(waveOpacity1), lineWidth: 1)
                    .frame(width: discSize, height: discSize)
                    .scaleEffect(waveScale1)
                
                Circle()
                    .stroke(accentColor.opacity(waveOpacity2), lineWidth: 1)
                    .frame(width: discSize, height: discSize)
                    .scaleEffect(waveScale2)
                
                Circle()
                    .stroke(accentColor.opacity(waveOpacity3), lineWidth: 1)
                    .frame(width: discSize, height: discSize)
                    .scaleEffect(waveScale3)
            }
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(white: 0.12), Color(white: 0.05)],
                        center: .center,
                        startRadius: 0,
                        endRadius: discSize / 2
                    )
                )
                .frame(width: discSize, height: discSize)
            
            ForEach(0..<8, id: \.self) { index in
                Circle()
                    .stroke(Color.white.opacity(0.03), lineWidth: 0.5)
                    .frame(width: labelSize + CGFloat(index) * 6, height: labelSize + CGFloat(index) * 6)
            }
            
            Circle()
                .fill(Color(white: 0.15))
                .frame(width: discSize - 4, height: discSize - 4)
                .overlay(
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [Color.white.opacity(0.1), Color.white.opacity(0.02), Color.white.opacity(0.1)],
                                center: .center
                            ),
                            lineWidth: 1
                        )
                )
            
            // Artwork with crossfade transition
            ZStack {
                if let displayed = displayedArtwork {
                    Image(nsImage: displayed)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: labelSize, height: labelSize)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.3), lineWidth: 1)
                        )
                        .transition(.opacity)
                } else {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.4), accentColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: labelSize, height: labelSize)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.white.opacity(0.6))
                        )
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: displayedArtwork)
            
            Circle()
                .fill(Color.black)
                .frame(width: spindleSize, height: spindleSize)
            
            if isPlaying {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [Color.white.opacity(0.2), Color.clear, Color.clear, Color.clear, Color.clear, Color.clear],
                            center: .center,
                            startAngle: .degrees(0),
                            endAngle: .degrees(360)
                        )
                    )
                    .frame(width: discSize - 2, height: discSize - 2)
                    .blur(radius: 6)
            }
            
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white.opacity(0.15), Color.clear],
                        center: .topLeading,
                        startRadius: 0,
                        endRadius: discSize / 2
                    )
                )
                .frame(width: discSize, height: discSize)
        }
        .frame(width: discSize, height: discSize)
        .rotationEffect(.degrees(rotation))
        .shadow(color: isPlaying ? accentColor.opacity(0.3) : accentColor.opacity(0.15), radius: isPlaying ? 12 : 6, y: 2)
        .onReceive(rotationTimer) { _ in
            if isPlaying {
                rotation += 3.33
            }
        }
        .onChange(of: isPlaying) { playing in
            if playing {
                startWaveAnimations()
            } else {
                resetWaves()
            }
        }
        .onChange(of: artwork) { newArtwork in
            withAnimation(.easeInOut(duration: 0.25)) {
                displayedArtwork = newArtwork
            }
        }
        .onAppear {
            displayedArtwork = artwork
            if isPlaying {
                startWaveAnimations()
            }
        }
    }
    
    private func startWaveAnimations() {
        withAnimation(.easeOut(duration: 3.0).repeatForever(autoreverses: false)) {
            waveScale1 = 1.12
            waveOpacity1 = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 3.0).repeatForever(autoreverses: false)) {
                waveScale2 = 1.12
                waveOpacity2 = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 3.0).repeatForever(autoreverses: false)) {
                waveScale3 = 1.12
                waveOpacity3 = 0
            }
        }
    }
    
    private func resetWaves() {
        withAnimation(.easeOut(duration: 0.3)) {
            waveScale1 = 1.0
            waveScale2 = 1.0
            waveScale3 = 1.0
            waveOpacity1 = 0.5
            waveOpacity2 = 0.5
            waveOpacity3 = 0.5
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






