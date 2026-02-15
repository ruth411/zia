//
//  WelcomeStepView.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import SwiftUI

/// Welcome screen with Zia branding and "Get Started" button
struct WelcomeStepView: View {

    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Logo
            ZiaLogoView(size: 80)

            // Title
            Text("Welcome to Zia")
                .font(.system(size: 28, weight: .bold))

            // Subtitle
            Text("Your personal AI assistant for macOS.\nManage calendar, music, flights, and more.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            // Get started button
            Button(action: onNext) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
    }
}
