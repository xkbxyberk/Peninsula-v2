import SwiftUI
import Combine

struct NotchPanelView: View {
    @ObservedObject var viewModel: NotchViewModel
    @State private var progressRingVisible: Bool = false
    
    private var animationTiming: Animation {
        .timingCurve(
            Notch.animationTimingFunction.c1,
            Notch.animationTimingFunction.c2,
            Notch.animationTimingFunction.c3,
            Notch.animationTimingFunction.c4,
            duration: Notch.animationDuration
        )
    }
    
    private var accentColor: Color {
        Color(nsColor: viewModel.musicService.accentColor)
    }
    
    private var progressValue: CGFloat {
        guard viewModel.musicService.duration > 0 else { return 0 }
        return viewModel.musicService.currentPosition / viewModel.musicService.duration
    }
    
    private var closedWidth: CGFloat {
        viewModel.baseWidth
    }
    
    private var closedHeight: CGFloat {
        viewModel.baseHeight
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                NotchShape(
                    progress: viewModel.expansionProgress,
                    closedWidth: closedWidth,
                    closedHeight: closedHeight,
                    openWidth: Notch.Expanded.width,
                    openHeight: Notch.Expanded.height
                )
                .fill(.black)
                .shadow(
                    color: .black.opacity(lerp(0.08, 0.25, viewModel.expansionProgress)),
                    radius: lerp(2, 6, viewModel.expansionProgress),
                    x: 0,
                    y: lerp(0.5, 2, viewModel.expansionProgress)
                )
                .shadow(
                    color: .black.opacity(lerp(0.04, 0.1, viewModel.expansionProgress)),
                    radius: lerp(4, 12, viewModel.expansionProgress),
                    x: 0,
                    y: lerp(1, 3, viewModel.expansionProgress)
                )
                
                if viewModel.isMusicActive && progressRingVisible {
                    ProgressRingShape(
                        width: closedWidth,
                        height: closedHeight
                    )
                    .trim(from: 0, to: progressValue)
                    .stroke(
                        accentColor,
                        style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                    )
                    .shadow(color: accentColor.opacity(0.5), radius: 4)
                    .animation(.linear(duration: 1.0), value: progressValue)
                    .transition(.opacity.animation(.easeIn(duration: 0.25)))
                }
                
                if viewModel.state.isPlaying {
                    miniPlayerContent
                        .opacity(1.0 - viewModel.expansionProgress)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                if viewModel.state.isExpanded {
                    expandedContent
                        .opacity(viewModel.expansionProgress)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .animation(animationTiming, value: viewModel.state)
        .animation(.spring(response: 0.45, dampingFraction: 0.7, blendDuration: 0.1), value: viewModel.isMusicActive)
        .onChange(of: viewModel.state.isExpanded) { isExpanded in
            if isExpanded {
                progressRingVisible = false
            } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.easeIn(duration: 0.25)) {
                        progressRingVisible = viewModel.isMusicActive && !viewModel.state.isExpanded
                    }
                }
            }
        }
        .onChange(of: viewModel.musicService.activeApp) { newActiveApp in
            withAnimation(.spring(response: 0.45, dampingFraction: 0.7, blendDuration: 0.1)) {
                viewModel.refreshMusicState()
            }
            
            // Müzik uygulaması aktif hale geldiğinde ve panel kapalıysa progress ring'i göster
            if newActiveApp != nil && !viewModel.state.isExpanded && !progressRingVisible {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeIn(duration: 0.25)) {
                        // Tekrar kontrol et - durum değişmiş olabilir
                        if viewModel.isMusicActive && !viewModel.state.isExpanded {
                            progressRingVisible = true
                        }
                    }
                }
            } else if newActiveApp == nil {
                // Müzik uygulaması kapandığında progress ring'i gizle
                withAnimation(.easeOut(duration: 0.2)) {
                    progressRingVisible = false
                }
            }
        }
        .onAppear {
            // İlk açılışta müzik aktifse, kısa bir delay ile progress ring'i göster
            // Bu delay, MusicService'in durumu algılaması için zaman tanır
            if viewModel.isMusicActive && !viewModel.state.isExpanded {
                progressRingVisible = true
            } else {
                // Eğer henüz aktif değilse, kısa süre sonra tekrar kontrol et
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if viewModel.isMusicActive && !viewModel.state.isExpanded && !progressRingVisible {
                        withAnimation(.easeIn(duration: 0.25)) {
                            progressRingVisible = true
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var miniPlayerContent: some View {
        HStack(alignment: .center, spacing: 0) {
            if let artwork = viewModel.musicService.artwork {
                Image(nsImage: artwork)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .padding(.leading, 28)
            } else {
                RoundedRectangle(cornerRadius: 5)
                    .fill(.white.opacity(0.1))
                    .frame(width: 24, height: 24)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.3))
                    }
                    .padding(.leading, 28)
            }
            
            Spacer()
            
            if viewModel.musicService.isPlaying {
                MiniEqualizerView(accentColor: accentColor)
                    .padding(.trailing, 28)
            }
        }
        .frame(width: Notch.Playing.width, height: closedHeight, alignment: .center)
    }
    
    @ViewBuilder
    private var expandedContent: some View {
        MusicPanelView(musicService: viewModel.musicService)
            .padding(.top, 50)
    }
}

struct MiniEqualizerView: View {
    let accentColor: Color
    
    @State private var heights: [CGFloat] = [0.4, 0.6, 0.5, 0.7]
    
    private let timer = Timer.publish(every: 0.15, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(accentColor)
                    .frame(width: 3, height: 4 + heights[index] * 12)
            }
        }
        .frame(height: 16)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                heights = heights.map { _ in CGFloat.random(in: 0.2...1.0) }
            }
        }
    }
}

private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}




