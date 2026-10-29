//
//  StatTile.swift
//  ParkFinder
//

import SwiftUI

// A compact labelled value, e.g. "Drivers paid · $3.00/hr".
struct StatTile: View {
    let title: LocalizedStringKey
    let value: String
    var footnote: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(Color.gold)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            if let footnote {
                Text(footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.charcoal, in: .rect(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gold.opacity(0.2), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    StatTile(title: "Drivers paid", value: "$3.00/hr", footnote: "2 days ago")
        .padding()
        .background(Color.ink)
}
