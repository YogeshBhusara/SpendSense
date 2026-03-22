//
//  ShimmerEffect.swift
//  SpendSense
//

import SwiftUI

/// Animated diagonal gradient sweep across redacted placeholders.
struct ShimmerEffect: ViewModifier {
    @State private var slide = false

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geo in
                    let w = max(geo.size.width, 1)
                    LinearGradient(
                        colors: [
                            .white.opacity(0),
                            .white.opacity(0.32),
                            .white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: w * 0.45)
                    .offset(x: slide ? w * 1.05 : -w * 0.5)
                    .blendMode(.plusLighter)
                }
                .allowsHitTesting(false)
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.25).repeatForever(autoreverses: false)) {
                    slide = true
                }
            }
    }
}

extension View {
    func shimmer(active: Bool) -> some View {
        Group {
            if active {
                modifier(ShimmerEffect())
            } else {
                self
            }
        }
    }

    /// Redacted placeholder plus optional shimmer (loading skeletons).
    @ViewBuilder
    func placeholderSkeleton(_ active: Bool) -> some View {
        if active {
            self
                .redacted(reason: .placeholder)
                .shimmer(active: true)
        } else {
            self
        }
    }
}
