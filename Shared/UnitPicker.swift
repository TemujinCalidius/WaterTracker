//
//  UnitPicker.swift
//  WaterTracker
//
//  Created by Yu Liang on 10/31/24.
//

import SwiftUI

struct UnitPickerView: View {
    /* Not used in widgets, thus fine to use environment variables. */
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(WaterTrackerConfigManager.self) private var config
    @Environment(\.modelContext) var modelContext
    
    // Connect to the parent view to update the whole page when configurations are updated.
    @Binding var updateToggle: Bool
    
    /* Placeholder for the pickers. */
    @State private var waterUnitSelection: String = ""
    @State private var waterUnitChoice = ["Milliliter", "Ounce", ""]
    
    @State private var dailyGoal: Double = 0.0
    @State private var dailyGoalChoice: [Double] = [2500]
    
    @State private var reminderTimeInterval: Double = 0.0
    @State private var reminderTimeIntervalChoice: [Double] = [1800.0, 3600.0, 5400.0 , 7200.0, 9000.0, 10800]
    
    var body : some View {
        
        HStack{
            
            Text("Daily Goal: ")
#if os(iOS)
                .font(.title)
#elseif os(watchOS)
                .font(.body)
#endif
                .foregroundStyle(.black)
                .fontWeight(.bold)
                .allowsHitTesting(false)
                .multilineTextAlignment(.leading)
#if os(iOS)
            // Trick for citation.
            Text("[1]")
                .font(.system(size: 8))
                .foregroundStyle(.black)
                .baselineOffset(6.0)
#endif
            
            
            Picker("", selection: self.$dailyGoal) {
                ForEach(self.dailyGoalChoice, id: \.self) {
                    let unitStr = self.config.waterUnit == .ml ? "ml" : "oz"
                    Text(String("\($0) \(unitStr)"))
                }
            }
#if os(iOS)
            .pickerStyle(.wheel)
#elseif os(watchOS)
            .pickerStyle(.navigationLink)
#endif
            .foregroundStyle(.black) // FIXME: Does not have effect on the wheel text (watchOS).
            .accentColor(.black) // FIXME: Another failed attempt to change the wheel text to black (watchOS).
            .multilineTextAlignment(.center)
            .labelsHidden()
            .onAppear {
                self.dailyGoal = self.config.getDailyGoal()
                self.dailyGoalChoice = self.config.getDailyGoalCustomRange()
            }
            .onChange(of: self.dailyGoal) { oldValue, newValue in
                if oldValue != 0.0 {
                    // onChange is triggered when changing values in onAppear.
                    // But the placeholder is 0.0, thus won't run setDailyGoal on view onAppear.
                    DispatchQueue.main.async{
                        self.config.setDailyGoal(self.dailyGoal, modelContext: modelContext)
                        updateToggle = !updateToggle
                    }
                }
            }
        }
        
        HStack{
            
            Text("Choose Unit: ")
#if !os(watchOS)
                .font(.title)
#else
                .font(.body)
#endif
                .foregroundStyle(.black)
                .fontWeight(.bold)
                .allowsHitTesting(false)
                .multilineTextAlignment(.leading)
            
            Picker("", selection: self.$waterUnitSelection) {
                ForEach(self.waterUnitChoice, id: \.self) {
                    Text(LocalizedStringKey($0))
                }
            }
#if os(watchOS)
            // navigationLink looks terrible on iOS.
            .pickerStyle(.navigationLink)
#else
            .pickerStyle(SegmentedPickerStyle())
#endif
            .foregroundStyle(.black) // FIXME: Same as above.
            .accentColor(.black)
            .multilineTextAlignment(.center)
            .labelsHidden()
            .onAppear {
                if self.config.waterUnit == .ml {
                    self.waterUnitSelection = "Milliliter"
                } else {
                    self.waterUnitSelection = "Ounce"
                }
                // Remove the empty choice.
                self.waterUnitChoice = ["Milliliter", "Ounce"]
            }
            .onChange(of: waterUnitSelection) { oldValue, newValue in
                DispatchQueue.main.async{
                    // Same as above. Will trigger on onAppear() but avoided by "" placeholder.
                    if newValue == "Milliliter" && oldValue != "" {
                        self.config.setWaterUnit(.ml, modelContext: modelContext)
                        self.dailyGoalChoice = self.config.getDailyGoalCustomRange()
                        self.dailyGoal = self.config.getDailyGoal()
                        updateToggle = !updateToggle
                    }
                    else if newValue == "Ounce" && oldValue != "" {
                        self.config.setWaterUnit(.oz, modelContext: modelContext)
                        self.dailyGoalChoice = self.config.getDailyGoalCustomRange()
                        self.dailyGoal = self.config.getDailyGoal()
                        updateToggle = !updateToggle
                    }
                }
            }
        }
        
        HStack {
            
            Text("Reminder Time Interval: ")
#if os(iOS)
                .font(.title)
#elseif os(watchOS)
                .font(.body)
#endif
                .foregroundStyle(.black)
                .fontWeight(.bold)
                .allowsHitTesting(false)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            Picker("", selection: self.$reminderTimeInterval) {
                ForEach(self.reminderTimeIntervalChoice, id: \.self) {
                    switch $0 {
                    case 1800.0:
                        let intervalStr: LocalizedStringKey = "30 mins"
                        return Text(intervalStr)
                    case 3600.0:
                        let intervalStr: LocalizedStringKey = "1 hour"
                        return Text(intervalStr)
                    case 5400.0:
                        let intervalStr: LocalizedStringKey = "1.5 hours"
                        return Text(intervalStr)
                    case 7200.0:
                        let intervalStr: LocalizedStringKey = "2 hours"
                        return Text(intervalStr)
                    case 9000.0:
                        let intervalStr: LocalizedStringKey = "2.5 hours"
                        return Text(intervalStr)
                    case 10800.0:
                        let intervalStr: LocalizedStringKey = "3 hours"
                        return Text(intervalStr)
                    default:
                        let intervalStr: LocalizedStringKey = "2 hours"
                        return Text(intervalStr)
                    }
                }
            }
            #if os(iOS)
            .pickerStyle(.wheel)
            #elseif os(watchOS)
            .pickerStyle(.navigationLink)
            #endif
            .foregroundStyle(.black) // FIXME: Does not have effect on the wheel text (watchOS).
            .accentColor(.black) // FIXME: Another failed attempt to change the wheel text to black (watchOS).
            .multilineTextAlignment(.center)
            .labelsHidden()
            .onAppear() {
                self.reminderTimeInterval = self.config.reminderTimeInterval
            }
            .onChange(of: self.reminderTimeInterval) { oldValue, newValue in
                if oldValue == 0.0 {
                    return
                } else {
                    self.config.setReminderTimeInterval(self.reminderTimeInterval, modelContext: modelContext)
                }
            }
        }

#if os(iOS)
        HStack {
            NavigationLink {
                QuickAddsEditorView()
            } label: {
                Text("Quick Add Amounts")
                    .font(.title)
                    .foregroundStyle(.black)
                    .fontWeight(.bold)
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.black)
            }
        }
#endif
    }
    
}

#if os(iOS)
struct QuickAddsEditorView: View {
    /* Lets the user customize the quick-fill preset amounts shown above the
     * bottle. Values are stored canonically in ml (QuickAddStore) but edited
     * and displayed in the current unit. */

    @Environment(WaterTrackerConfigManager.self) private var config
    @State private var amountsML: [Double] = QuickAddStore.get()
    @State private var isShowEntry: Bool = false
    @State private var entryText: String = ""
    @State private var editingIndex: Int? = nil

    private func label(_ ml: Double) -> String {
        if config.waterUnit == .ml {
            return ml >= 1000 ? String(format: "%gL", ml / 1000.0) : "\(Int(ml))ml"
        } else {
            return "\(Int((ml / mlPerUSFluidOunce).rounded()))oz"
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(amountsML.indices, id: \.self) { index in
                    Button {
                        editingIndex = index
                        entryText = config.waterUnit == .ml
                            ? String(Int(amountsML[index]))
                            : String(Int((amountsML[index] / mlPerUSFluidOunce).rounded()))
                        isShowEntry = true
                    } label: {
                        HStack {
                            Image(systemName: "drop.fill")
                                .foregroundStyle(.blue)
                            Text("Quick Add")
                            Spacer()
                            Text(label(amountsML[index]))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                }
                .onDelete { offsets in
                    amountsML.remove(atOffsets: offsets)
                    QuickAddStore.set(amountsML)
                }

                if amountsML.count < 6 {
                    Button {
                        amountsML.append(250)
                        QuickAddStore.set(amountsML)
                    } label: {
                        Label("Add Amount", systemImage: "plus.circle.fill")
                    }
                }
            } header: {
                Text("Quick Add Amounts")
            } footer: {
                Text("These appear above the bottle for one-tap logging. Swipe to delete.")
            }
        }
        .navigationTitle("Quick Adds")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Set Amount", isPresented: $isShowEntry) {
            TextField("Amount", text: $entryText)
                .keyboardType(.numberPad)
            Button("Cancel", role: .cancel) { editingIndex = nil }
            Button("Set") {
                if let index = editingIndex, let value = Double(entryText), value > 0 {
                    amountsML[index] = config.waterUnit == .ml ? value : value * mlPerUSFluidOunce
                    QuickAddStore.set(amountsML)
                }
                editingIndex = nil
            }
        } message: {
            Text("Enter the amount in \(config.getUnitStr()).")
        }
    }
}
#endif

#Preview {
    @Previewable @State var healthKitManager = HealthKitManager()
    @Previewable @State var configManager = WaterTrackerConfigManager()
    @Previewable @State var updateToggle = false

    UnitPickerView(updateToggle: $updateToggle)
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .environment(healthKitManager)
        .environment(configManager)
}
