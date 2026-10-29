//
//  PriceFields.swift
//  ParkFinder
//

import SwiftUI

// Form section for what parking cost, plus a time limit for street parking.
struct PriceFields: View {
    let kind: ParkingKind
    @Binding var isFree: Bool
    @Binding var pricePerHour: Double?
    @Binding var timeLimitMinutes: Int

    private let currencyCode = Locale.current.currency?.identifier ?? "CAD"
    private let timeLimits = [0, 30, 60, 120, 180, 240]

    var body: some View {
        Section {
            Toggle("It was free", isOn: $isFree.animation())
            if !isFree {
                LabeledContent("Price per hour") {
                    TextField("0.00", value: $pricePerHour, format: .currency(code: currencyCode))
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(Color.gold)
                }
            }
            if kind == .street {
                Picker("Time limit", selection: $timeLimitMinutes) {
                    ForEach(timeLimits, id: \.self) { minutes in
                        if minutes == 0 {
                            Text("No limit").tag(0)
                        } else {
                            Text(Duration.seconds(minutes * 60), format: .units(allowed: [.hours, .minutes], width: .abbreviated))
                                .tag(minutes)
                        }
                    }
                }
            }
        } header: {
            Text("Price")
        } footer: {
            Text("Prices you share update the spot for every driver.")
        }
    }
}
