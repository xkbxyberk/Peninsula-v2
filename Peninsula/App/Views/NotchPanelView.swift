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
                .shadow(
                    color: .black.opacity(0.25 * viewModel.expansionProgress),
                    radius: 6 * viewModel.expansionProgress,
                    x: 0,
                    y: 2 * viewModel.expansionProgress
                )
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
            MusicPanelView(musicService: viewModel.musicService)
                .padding(.top, 50)
        }
    }
}

