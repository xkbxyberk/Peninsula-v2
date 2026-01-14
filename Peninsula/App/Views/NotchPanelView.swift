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
                NotchShape(
                    progress: viewModel.expansionProgress,
                    closedWidth: Notch.Closed.width,
                    closedHeight: Notch.Closed.height,
                    openWidth: Notch.Expanded.width,
                    openHeight: Notch.Expanded.height
                )
                .fill(.black)
                
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
