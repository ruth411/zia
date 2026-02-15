//
//  SuggestionStripView.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import SwiftUI

/// Horizontal suggestion strip shown below the input bar
struct SuggestionStripView: View {
    let suggestions: [Suggestion]
    let onTap: (Suggestion) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(suggestions) { suggestion in
                    Button {
                        onTap(suggestion)
                    } label: {
                        HStack(spacing: 4) {
                            Text("Try:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(suggestion.text)
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Image(systemName: suggestion.iconName)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 6)
        }
    }
}
