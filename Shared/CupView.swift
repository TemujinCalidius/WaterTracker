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

    // Tap-the-amount-to-type entry (iOS). The invisible cup drag still works too.
    @State private var isShowAmountEntry: Bool = false
    @State private var amountEntryText: String = ""

    func prefillAmountEntry() {
        if config.waterUnit == .ml {
            self.amountEntryText = String(Int(self.healthKitManager.drinkNum))
        } else {
            self.amountEntryText = String(format: "%.1f", self.healthKitManager.drinkNum)
        }
    }

    // Generous per-log ceiling (e.g. a 1L bottle), well above the cup's visual
    // capacity; the wave just shows full past capacity. Kept in the current unit.
    var maxLogAmount: Double {
        config.waterUnit == .ml ? 4000.0 : 135.0
    }

    // Quick-fill presets shown above the bottle. Stored as canonical ml
    // (user-customizable in Settings) and rendered/logged in the current unit.
    var quickAmountsML: [Double] {
        QuickAddStore.get()
    }

    func quickAmountLabel(_ amountML: Double) -> String {
        if config.waterUnit == .ml {
            return amountML >= 1000 ? String(format: "%gL", amountML / 1000.0) : "\(Int(amountML))ml"
        } else {
            return "\(Int((amountML / mlPerUSFluidOunce).rounded()))oz"
        }
    }

    func drinkNumForAmountML(_ amountML: Double) -> Double {
        config.waterUnit == .ml ? amountML : amountML / mlPerUSFluidOunce
    }

    func setDrinkNum(_ amount: Double) {
        // Animate deliberate amount changes (presets, typed entry) so the water
        // fills smoothly. The launch default and the cup drag set drinkNum
        // directly (no animation), which keeps the launch glitch away.
        withAnimation(.linear(duration: 0.3)) {
            self.healthKitManager.drinkNum = min(maxLogAmount, max(config.cupMinimumNum, amount))
        }
    }

    func commitAmountEntry() {
        guard let value = Double(amountEntryText), value > 0 else { return }
        setDrinkNum(value)
    }
    
    func setDefaultDrinkNum() {
        // A standard single serving.
        self.healthKitManager.drinkNum = config.waterUnit == .ml ? 250.0 : 8.0
    }
    
    func updateTextStr() {
        let drinkNumPair = config.waterUnit.volumeStrPair(self.healthKitManager.drinkNum, isPadded: true)
        self.unitStr = drinkNumPair.unitStr
        self.textStr = LocalizedStringKey("\(drinkNumPair.numStr)\(drinkNumPair.unitStr)")
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
                    // 1 L bottle dimensions. The body is a Capsule whose fill
                    // maps 1:1 to drinkNum / cupCapacity (1000ml), so 500ml is
                    // exactly half full.
                    let bottleWidth = geometry.size.width * 0.40
                    let bottleBodyHeight = geometry.size.height * 0.42
                    VStack{
                        Spacer()
#if !os(watchOS)
                        // Quick-fill presets. Tapping the amount number below
                        // still opens a type-it-in field for anything else.
                        HStack(spacing: 12) {
                            ForEach(quickAmountsML, id: \.self) { amountML in
                                Button {
                                    setDrinkNum(drinkNumForAmountML(amountML))
                                } label: {
                                    Text(verbatim: quickAmountLabel(amountML))
                                        .font(.headline)
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 10)
                                        .background(.regularMaterial)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.bottom)
#endif
                        HStack{

                            Spacer()
                            VStack(spacing: geometry.size.height * 0.008) {
                                // Bottle cap.
                                RoundedRectangle(cornerRadius: bottleWidth * 0.10)
                                    .fill(Color.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: bottleWidth * 0.10)
#if !os(watchOS)
                                            .stroke(Color.black, style: StrokeStyle(lineWidth: 8))
#else
                                            .stroke(Color.black, style: StrokeStyle(lineWidth: 5))
#endif
                                    )
                                    .frame(width: bottleWidth * 0.42, height: geometry.size.height * 0.028)

                                // Bottle body. The Capsule is filled directly by
                                // the wave, so the liquid level is accurate.
                                ZStack{
                                    Capsule()
                                        .fill(Color.white)
                                        .overlay(
                                            WaveAnimation($waveOffset, true, fillColor: selectedDrinkType.waveColor)
                                                .mask(Capsule())
                                        )

                                    Capsule()
#if !os(watchOS)
                                        .stroke(Color.black, style: StrokeStyle(lineWidth: 8))
#else
                                        .stroke(Color.black, style: StrokeStyle(lineWidth: 5))
#endif
                                        .overlay(
                                            InvisibleSlider()
                                        )
                                }
                                .frame(width: bottleWidth, height: bottleBodyHeight)
                            }
                            Spacer()
                        }
                        
                        Spacer()
                        
#if os(iOS)
                        // Pick the drink type from a scrollable row of icons.
                        DrinkTypeIconRow(selectedDrinkType: $selectedDrinkType)
                            .padding(.bottom, 4)
#endif

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

#if os(watchOS)
                            DrinkTypePickerButton(selectedDrinkType: $selectedDrinkType)
#endif

                            Spacer()

#if os(iOS)
                            // Tap the amount to type an exact value.
                            Button {
                                prefillAmountEntry()
                                isShowAmountEntry = true
                            } label: {
                                Text(self.textStr)
                                    .font(.system(size: 300))
                                    .minimumScaleFactor(0.00001)
                                    .foregroundStyle(.black)
                                    .fontWeight(.bold)
                                    .frame(height: geometry.size.width * 0.30, alignment: .center)
                                    .multilineTextAlignment(.center)
                            }
                            .buttonStyle(.plain)
#else
                            Text(self.textStr)
                                .font(.system(size: 300))
                                .minimumScaleFactor(0.00001)
                                .foregroundStyle(.black)
                                .fontWeight(.bold)
                                .frame(height: geometry.size.width * 0.30, alignment: .center)
                                .allowsHitTesting(false)
                                .multilineTextAlignment(.center)
#endif

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
#if os(iOS)
            .alert("Set Amount", isPresented: $isShowAmountEntry) {
                TextField("Amount", text: $amountEntryText)
                    .keyboardType(.decimalPad)
                Button("Cancel", role: .cancel) {}
                Button("Set") { commitAmountEntry() }
            } message: {
                Text("Enter the amount in \(config.getUnitStr()).")
            }
#endif
        }
        .accentColor(.black)
    }
}

#if os(iOS)
struct DrinkTypeIconRow: View {
    /* Horizontal, scrollable row of circular drink-type icons (HidrateSpark
     * style): symbol on the drink's colour, white ring on the selected one,
     * name underneath. Scrolls to the current selection on appear. Replaces
     * the old text menu on iOS. */

    @Binding var selectedDrinkType: DrinkType

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(DrinkType.allCases) { drink in
                        Button {
                            self.selectedDrinkType = drink
                            LastDrinkTypeStore.set(drink)
                        } label: {
                            VStack(spacing: 4) {
                                ZStack {
                                    Circle()
                                        .fill(drink.waveColor)
                                    Image(systemName: drink.symbolName)
                                        .foregroundStyle(.white)
                                        .font(.system(size: 22))
                                        .shadow(color: .black.opacity(0.25), radius: 1)
                                }
                                .frame(width: 52, height: 52)
                                .overlay(
                                    Circle()
                                        .stroke(Color.white, lineWidth: drink == selectedDrinkType ? 3 : 0)
                                )
                                Text(drink.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.black)
                                    .lineLimit(1)
                            }
                            .frame(width: 66)
                            .opacity(drink == selectedDrinkType ? 1.0 : 0.6)
                        }
                        .buttonStyle(.plain)
                        .id(drink)
                    }
                }
                .padding(.horizontal)
            }
            .onAppear {
                proxy.scrollTo(selectedDrinkType, anchor: .center)
            }
        }
    }
}
#endif

struct DrinkTypePickerButton: View {
    /* Sparing extraction from CupView's bottom HStack (see the FIXME above).
     * iOS renders a Menu of drink types; watchOS pushes a list, following
     * UnitPicker's platform split. The amount is set separately (quick-fill
     * presets above the cup, or by tapping the amount number). */

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
                            // Hydration factor as a subtitle; goal credit
                            // stays capped at the poured volume.
                            if drink.factor != 1.0 {
                                Text(String(format: "×%.2f", drink.factor))
                            }
                        }
                    }
                } header: {
                    Text(section.displayName)
                }
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
                                if drink.factor != 1.0 {
                                    Text(String(format: "×%.2f", drink.factor))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
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
