//
//  ParkingKindPicker.swift
//  ParkFinder
//

import SwiftUI

// Three big tiles: Street, Underground / Garage, Open Lot.
struct ParkingKindPicker: View {
    @Binding var selection: ParkingKind

    var body: some View {
        HStack(spacing: 10) {
            ForEach(ParkingKind.choosable) { kind in
                let isSelected = selection == kind
                Button {
                    selection = kind
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: kind.systemImage)
                            .font(.title2)
                        Text(kind.shortName)
                            .font(.caption.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(isSelected ? Color.ink : Color.gold)
                    .frame(maxWidth: .infinity, minHeight: 70)
                    .background {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(isSelected ? AnyShapeStyle(.goldGradient) : AnyShapeStyle(Color.charcoal))
                    }
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.gold.opacity(0.4), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(kind.displayName)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview {
    @Previewable @State var kind = ParkingKind.street
    ParkingKindPicker(selection: $kind)
        .padding()
        .background(Color.ink)
}
