//
//  ZiaLogoView.swift
//  Zia
//
//  Created by Claude on 2/14/26.
//

import SwiftUI

/// Reusable Zia logo component with fallback
struct ZiaLogoView: View {
    let size: CGFloat

    var body: some View {
        Group {
            if let nsImage = Self.loadZiaLogo() {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: size, height: size)
                    .foregroundColor(.blue)
            }
        }
    }

    /// Load Zia logo with multiple fallback approaches
    static func loadZiaLogo() -> NSImage? {
        // Approach 1: Asset catalog
        if let image = NSImage(named: "ZiaLogo") {
            return image
        }

        // Approach 2: Direct resource path
        if let resourcePath = Bundle.main.resourcePath {
            let imagePath = "\(resourcePath)/Assets.xcassets/ZiaLogo.imageset/zialogo.png"
            if FileManager.default.fileExists(atPath: imagePath) {
                return NSImage(contentsOfFile: imagePath)
            }
        }

        // Approach 3: Bundle search
        if let imagePath = Bundle.main.path(forResource: "zialogo", ofType: "png") {
            return NSImage(contentsOfFile: imagePath)
        }

        return nil
    }
}
