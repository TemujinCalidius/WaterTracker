//
//  MyIcon.swift
//  WaterTracker
//
//  Created by Yu Liang on 10/27/24.
//

import SwiftUI

struct CupView: View {
    /* Not used in widgets, fine for using environment variables. */
    
    // FIXME:: FAR TOO MANY CONTENTS FOR ONE VIEW!!!
    
    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(\.scenePhase) var scenePhase
    
    // FIXME:: Animation glitches.
    // The waveOffset is necessary as a State here.
    // If move the waveOffset into waveAnimation, the start
    // position of the waveOffset will cause problem of the animation.
    @State private var waveOffset: Angle = .zero
    
    private var crossOsConnectivity: CrossOsConnectivity = CrossOsConnectivity.shared
    
    @Environment(WaterTrackerConfigManager.self) private var config
    @Environment(\.modelContext) var modelContext
    
    @State private var textStr: LocalizedStringKey = "100 ml"
    @State private var unitStr: String = "ml"

    // Used for drink water button expand animation.
    @State var isDrinkButtonExpanded: Bool = false

    // Used to notify update for the button circular progress bar.
    @State var updateToggle: Bool = false

    // The drink about to be logged. Persisted per-device in the app group.
    @State private var selectedDrinkType: DrinkType = LastDrinkTypeStore.get()

    // One-time "counts as N% toward your goal" disclosure.
    @State private var isShowFactorDisclosure: Bool = false
    @State private var disclosureDrinkType: DrinkType = .water
    
    func setDefaultDrinkNum() {
        self.healthKitManager.drinkNum = Double(Int(config.getCupCapacity() * 3 / 4))
    }
    
    func updateTextStr() {
        self.unitStr = config.getUnitStr()
        if config.waterUnit == .ml {
            let drinkNumStr = String(format: "%.3d", Int(self.healthKitManager.drinkNum))
            self.textStr = LocalizedStringKey("\(drinkNumStr)\(self.unitStr)")
        } else {
            let drinkNumStr = String(format: "%.1f", self.healthKitManager.drinkNum)
            self.textStr = LocalizedStringKey("\(drinkNumStr)\(self.unitStr)")
        }
    }
    
    var body : some View {
        // FIXME:: FAR TOO BIG.
        
        NavigationStack {
            ZStack{
                LinearGradient(gradient: Gradient(colors: [.skyBlue, .cyan]), startPoint: .top, endPoint: .bottom)
                    .clipped()
                    .ignoresSafeArea(.all) // As background.
                GeometryReader { geometry in
                    @State var cupWidth = geometry.size.width * 0.8
                    VStack{
                        Spacer()
                        HStack{
                            
                            Spacer()
                            ZStack{
                                
                                Cup()
                                    .fill(Color.white)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: cupWidth, alignment: .center)
                                    .overlay(
                                        WaveAnimation($waveOffset, true, fillColor: selectedDrinkType.waveColor)
                                            .frame(width: cupWidth, alignment: .center)
                                            .aspectRatio( contentMode: .fill)
                                            .mask(
                                                Cup()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: cupWidth, alignment: .center)
                                            )
                                    )
                                
                                
                                Cup()
#if !os(watchOS)
                                    .stroke(Color.black, style: StrokeStyle(lineWidth: 8))
#else
                                    .stroke(Color.black, style: StrokeStyle(lineWidth: 5))
#endif
                                
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: cupWidth, alignment: .center)
                                    .overlay(
                                        InvisibleSlider()
                                    )
                                
                            }
                            Spacer()
                        }
                        
                        Spacer()
                        
                        HStack{
                            Button{
                                Task {
                                    _ = await healthKitManager.saveDrinkWater(drink_num: self.healthKitManager.drinkNum, waterUnitInput: config.waterUnit, drinkType: selectedDrinkType)
                                    LocalNotificationHandler.registerLocalNotification()
                                    CrossOsConnectivity.shared.sendNotificationReminder()
                                    self.isDrinkButtonExpanded = true
                                    if selectedDrinkType == .water {
                                        self.textStr = "Water + "
                                    } else {
                                        self.textStr = LocalizedStringKey("\(selectedDrinkType.localizedName) + ")
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        self.isDrinkButtonExpanded = false
                                    }
                                    updateToggle.toggle()
                                    // First-ever log of a discounted drink: explain the
                                    // hydration factor once.
                                    if selectedDrinkType.writeFactor < 1.0 && !LastDrinkTypeStore.defaults.bool(forKey: LastDrinkTypeStore.factorDisclosureShownKey) {
                                        LastDrinkTypeStore.defaults.set(true, forKey: LastDrinkTypeStore.factorDisclosureShownKey)
                                        self.disclosureDrinkType = selectedDrinkType
                                        self.isShowFactorDisclosure = true
                                    }
                                }
#if os(watchOS)
                                WKInterfaceDevice.current().play(.success)
#elseif os(iOS)
                                // Vibrate on iOS when drink logging succeed.
                                let impactMed = UIImpactFeedbackGenerator(style: .heavy)
                                impactMed.impactOccurred()
#endif
                            } label: {
                                ZStack{
                                    Image(systemName: "plus")
                                        .foregroundStyle(.blue)
#if os(watchOS)
                                        .font(.system(size: 25))
#else
                                        .font(.system(size: 40))
#endif
                                }
                            }
#if !os(watchOS)
                            .padding()
                            .frame(width: 70, height: 70, alignment: .center)
#else
                            .apply {
                                if #available(watchOS 11.0, *) {
                                    $0.handGestureShortcut(.primaryAction)
                                } else {
                                    $0
                                }
                            }
#endif
                            .background(.regularMaterial)
                            .clipShape(.circle)
                            .scaleEffect(isDrinkButtonExpanded ? 2.5 : 1)
                            .animation(Animation.easeOut(duration: 0.3), value: self.isDrinkButtonExpanded)

                            DrinkTypePickerButton(selectedDrinkType: $selectedDrinkType)

                            Spacer()
                            
                            Text(self.textStr)
                                .font(.system(size: 300))
                                .minimumScaleFactor(0.00001)
                                .foregroundStyle(.black)
                                .fontWeight(.bold)
                                .frame(height: geometry.size.width * 0.30, alignment: .center)
                                .allowsHitTesting(false)
                                .multilineTextAlignment(.center)
                            
                            Spacer()
                            
                            NavigationLink(destination: SummaryView() ) {
                                HStack{
                                    Spacer(minLength: 0)
                                    VStack{
                                        Spacer(minLength: 0)
                                        CircularProgressView(config: self.config, updateToggle: self.$updateToggle)
                                        Spacer(minLength: 0)
                                    }
                                    Spacer(minLength: 0)
                                }
                            }
#if !os(watchOS)
                            .padding()
                            .frame(width: 70, height: 70, alignment: .center)
#endif
                            .background(.regularMaterial)
                            .clipShape(.circle)
                        }
                        .padding(.horizontal)
#if !os(watchOS)
                        .padding(.vertical) // give the small watch screen a break!
#endif
                        
                    } // From the VStack. This should expand to the whole screen excluding the safe area
                    .onAppear() {
                        config.receiveUpdatedWaterTrackerConfig(modelContext: self.modelContext)
                        setDefaultDrinkNum()
                        updateTextStr()
                        self.selectedDrinkType = LastDrinkTypeStore.get()
                        // HERE, make sure the animation plays correctly by reset the original value.
                        self.waveOffset = .zero
                        // If the user change the daily goal, update the circular progress bar when this view onAppear.
                        // Might be duplicated with the onChange(of: scenePhase), but should be fine to call it multiple times.
                        self.updateToggle.toggle()
                    }
                    .onChange(of: self.healthKitManager.drinkNum) {
                        updateTextStr()
                    }
                    .onChange(of: scenePhase) {
                        // When re-enter the app, refresh the
                        // circular progress bar.
                        oldPhase, newPhase in
                        if newPhase == .active {
                            // Toggle circular bar updates.
                            self.updateToggle.toggle()
                        }
                    }
                }
            }
            .alert("Hydration factor applied", isPresented: $isShowFactorDisclosure) {
                Button("OK", role: .cancel) {}
            } message: {
                let pctStr = String(format: "%.0f%%", disclosureDrinkType.writeFactor * 100.0)
                Text("\(disclosureDrinkType.localizedName) counts as \(pctStr) of its volume toward your daily goal, based on how well it hydrates (Maughan et al. 2016).")
            }
        }
        .accentColor(.black)
    }
}

struct DrinkTypePickerButton: View {
    /* Sparing extraction from CupView's bottom HStack (see the FIXME above).
     * iOS renders a Menu with drink sections plus serving shortcuts;
     * watchOS pushes a list, following UnitPicker's platform split. */

    @Environment(HealthKitManager.self) private var healthKitManager
    @Environment(WaterTrackerConfigManager.self) private var config

    @Binding var selectedDrinkType: DrinkType

    var body: some View {
#if !os(watchOS)
        Menu {
            ForEach(DrinkSection.allCases) { section in
                Section {
                    ForEach(DrinkType.allCases.filter { $0.section == section }) { drink in
                        Button {
                            self.selectedDrinkType = drink
                            LastDrinkTypeStore.set(drink)
                        } label: {
                            if drink == selectedDrinkType {
                                Label(drink.displayName, systemImage: "checkmark")
                            } else {
                                Text(drink.displayName)
                            }
                        }
                    }
                } header: {
                    Text(section.displayName)
                }
            }
            Section {
                ForEach(selectedDrinkType.defaultServingsML, id: \.self) { servingML in
                    Button {
                        if config.waterUnit == .ml {
                            self.healthKitManager.drinkNum = servingML
                        } else {
                            self.healthKitManager.drinkNum = servingML / mlPerUSFluidOunce
                        }
                    } label: {
                        if config.waterUnit == .ml {
                            Text(String("\(Int(servingML))ml"))
                        } else {
                            Text(String(format: "%.1foz", servingML / mlPerUSFluidOunce))
                        }
                    }
                }
            } header: {
                Text("Serving Size")
            }
        } label: {
            Image(systemName: selectedDrinkType.symbolName)
                .foregroundStyle(selectedDrinkType.waveColor)
                .font(.system(size: 28))
        }
        .padding()
        .frame(width: 70, height: 70, alignment: .center)
        .background(.regularMaterial)
        .clipShape(.circle)
#else
        NavigationLink {
            DrinkTypeListPicker(selectedDrinkType: $selectedDrinkType)
        } label: {
            Image(systemName: selectedDrinkType.symbolName)
                .foregroundStyle(selectedDrinkType.waveColor)
                .font(.system(size: 16))
        }
        .background(.regularMaterial)
        .clipShape(.circle)
#endif
    }
}

#if os(watchOS)
struct DrinkTypeListPicker: View {
    /* The watch drink list. Selecting a row persists and pops back. */

    @Binding var selectedDrinkType: DrinkType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(DrinkSection.allCases) { section in
                Section {
                    ForEach(DrinkType.allCases.filter { $0.section == section }) { drink in
                        Button {
                            self.selectedDrinkType = drink
                            LastDrinkTypeStore.set(drink)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: drink.symbolName)
                                    .foregroundStyle(drink.waveColor)
                                Text(drink.displayName)
                                Spacer()
                                if drink == selectedDrinkType {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } header: {
                    Text(section.displayName)
                }
            }
        }
    }
}
#endif

extension View {
    /* For conditional watchOS 11.0's Double Tap gesture. */
    func apply<V: View>(@ViewBuilder _ block: (Self) -> V) -> V { block(self) }
}

#Preview {
    @Previewable @State var healthKitManager = HealthKitManager()
    @Previewable @State var configManager = WaterTrackerConfigManager()
    CupView()
        .background(Color.white.edgesIgnoringSafeArea(.all))
        .environment(healthKitManager)
        .environment(configManager)
}
