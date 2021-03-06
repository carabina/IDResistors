//
//  ResistorInputView.swift
//  IDResistors
//
//  Created by Marc Rummel on 08.06.20.
//  Copyright © 2020 Marc Rummel.
//  This code is licensed under MIT license (see LICENSE.txt for details)
//

import SwiftUI
import Combine

class InputModel: ObservableObject {
    @Published var valueText: String = ""
    @Published var valueScale: Int = 1
    @Published var formInvalid:Bool = true

    var valueMessage = ""
    var value: Double = 0.0

    private var cancellableSet: Set<AnyCancellable> = []
    private let formatter = NumberFormatter()

    private var numberValuePublisher: AnyPublisher<Double?, Never> {
        $valueText
            .removeDuplicates()
            .map {input in
                self.formatter.number(from: input)?.doubleValue
            }
            .eraseToAnyPublisher()
    }

    private var doubleValuePublisher: AnyPublisher<Double, Never> {
        numberValuePublisher.compactMap { $0 }
        .eraseToAnyPublisher()
    }

    private var isValueInvalidPublisher: AnyPublisher<Bool, Never> {
        numberValuePublisher.map {
            $0 == nil
        }.eraseToAnyPublisher()
    }

    private var valuePublisher: AnyPublisher<Double, Never> {
        Publishers.CombineLatest(doubleValuePublisher, $valueScale)
            .map { value, scale in
                return value * Double(scale)
        }.eraseToAnyPublisher()
    }

    init() {
        isValueInvalidPublisher
            .receive(on: RunLoop.main)
            .assign(to: \.formInvalid, on: self)
            .store(in: &cancellableSet)

        isValueInvalidPublisher
            .receive(on: RunLoop.main)
            .map {
                if $0 == true {
                    return "Enter a decimal number"
                }
                else {
                    return ""
                }
            }
            .assign(to: \.valueMessage, on: self)
            .store(in: &cancellableSet)

        valuePublisher
            .receive(on: RunLoop.main)
            .assign(to: \.value, on: self)
            .store(in: &cancellableSet)
    }
}

struct ResistorInputView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var model = InputModel()
    @EnvironmentObject var code: Code

    @State var showTolerances: Bool

    let tolerances = ToleranceRing.allCases.sorted(by: { $0.rawValue < $1.rawValue })
    @State var tolerance = 2

    var body: some View {
        Form {
            Section(footer: Text(model.valueMessage)) {
                TextField("Enter Value:", text: $model.valueText)
                Picker("Rings", selection: $model.valueScale) {
                    Text("Ω").tag(1)
                    Text("kΩ").tag(1000)
                    Text("MΩ").tag(1000000)
                }.pickerStyle(SegmentedPickerStyle())
                if showTolerances {
                    Stepper("Tolerance \(tolerances[tolerance].string)", value: $tolerance, in: 0...(tolerances.count - 1))
                }
            }
            Section() {
                Button(action: {
                    self.code.value = self.model.value
                    if self.showTolerances {
                        self.code.toleranceRing = self.tolerances[self.tolerance]
                    }
                    self.presentationMode.wrappedValue.dismiss() }) {
                        Text("Set Resistor Value")
                }.disabled(model.formInvalid)
            }
        }
    }
}

struct SMDInputView_Previews: PreviewProvider {
    static var previews: some View {
        ResistorInputView(showTolerances: false).environmentObject(Code(value: 27_000)!)
    }
}
