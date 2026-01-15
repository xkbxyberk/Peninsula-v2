import SwiftUI

struct NotchPanelView: View {
    @Bindable var viewModel: NotchViewModel
    
    private var animationTiming: Animation {
        .timingCurve(
            Notch.animationTimingFunction.c1,
            Notch.animationTimingFunction.c2,
            Notch.animationTimingFunction.c3,
            Notch.animationTimingFunction.c4,
            duration: Notch.animationDuration
        )
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                // Main notch shape with native shadow
                NotchShape(
                    progress: viewModel.expansionProgress,
                    closedWidth: Notch.Closed.width,
                    closedHeight: Notch.Closed.height,
                    openWidth: Notch.Expanded.width,
                    openHeight: Notch.Expanded.height
                )
                .fill(.black)
                // Thin subtle glow around the notch shape
                .shadow(
                    color: .black.opacity(0.25 * viewModel.expansionProgress),
                    radius: 6 * viewModel.expansionProgress,
                    x: 0,
                    y: 2 * viewModel.expansionProgress
                )
                // Slightly larger soft glow
                .shadow(
                    color: .black.opacity(0.1 * viewModel.expansionProgress),
                    radius: 12 * viewModel.expansionProgress,
                    x: 0,
                    y: 3 * viewModel.expansionProgress
                )
                
                expandedContent
                    .opacity(viewModel.expansionProgress)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .animation(animationTiming, value: viewModel.state)
    }
    
    @ViewBuilder
    private var expandedContent: some View {
        if viewModel.state.isExpanded {
            VStack {
                Spacer()
                    .frame(height: 100)
                
                placeholderContent
                
                Spacer()
            }
            .frame(width: Notch.Expanded.width)
        }
    }
    
    private var placeholderContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.purple, .blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Text("Peninsula")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            
            Text("Dynamic Notch")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(.horizontal, 40)
        .padding(.vertical, 20)
    }
}
