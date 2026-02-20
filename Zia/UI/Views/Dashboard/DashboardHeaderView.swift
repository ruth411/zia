//
//  DashboardHeaderView.swift
//  Zia
//
//

import SwiftUI

/// Dashboard header with logo, title, and settings
struct DashboardHeaderView: View {
    let onSettingsTapped: () -> Void

    var body: some View {
        HStack {
            // Left: Logo + "Zia" label
            HStack(spacing: 6) {
                ZiaLogoView(size: 20)
                Text("Zia")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Center: Title
            Text("Zia")
                .font(.title3)
                .fontWeight(.semibold)

            Spacer()

            // Right: Settings gear
            Button(action: onSettingsTapped) {
                Image(systemName: "gearshape.fill")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
