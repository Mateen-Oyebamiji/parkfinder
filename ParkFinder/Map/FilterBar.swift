//
//  FilterBar.swift
//  ParkFinder
//

import SwiftUI

// Street / Underground / Lot chips. The selected chip is solid gold.
struct FilterBar: View {
    @Binding var selection: MapFilter

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(MapFilter.allCases) { filter in
                    let isSelected = selection == filter
                    Button {
                        selection = filter
                    } label: {
                        Label(filter.title, systemImage: filter.systemImage)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? Color.ink : Color.gold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background {
                                if isSelected {
                                    Capsule().fill(.goldGradient)
                                }
                            }
                            .glassPanel()
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.horizontal)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview {
    @Previewable @State var filter = MapFilter.all
    FilterBar(selection: $filter)
        .background(Color.ink)
}
