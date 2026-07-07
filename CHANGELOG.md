# Changelog

All notable changes to this fork of [WaterTracker](https://github.com/SteveLeungYL/WaterTracker) ("Pocket Water Tracker") are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). The fork tracks upstream `main` (v1.8) and stages its work on `dev`; the intent is to offer the whole body of work upstream once it is polished.

## [Unreleased]

### Added

- Unit-test target `WaterTrackerTests` (Swift Testing) covering units, date handling, and the drink catalog, plus a GitHub Actions workflow building the iOS and watchOS schemes (pinned to Xcode 16) and running the tests. (`ci/actions-and-tests`)
- Auto-scaling liter display: in ml mode, volumes of 1000 ml and above render as liters ("2.4L") in the summary sentence, daily-goal picker, lock-screen and watch widgets, and the Siri dialog. Sub-liter ml and all oz output stay byte-identical to v1.8, and no localization keys changed. (`feat/liter-formatting`)
- Drink catalog with evidence-based hydration factors: 21 drink types (alcohol deliberately excluded to keep the 4+ age rating) with factors anchored to the Beverage Hydration Index (Maughan et al. 2016). A drink picker with serving-size shortcuts joins the cup screen, the cup wave tints to the selected drink, a "Today's Drinks" card in the summary shows poured → counted volumes per drink, Siri accepts an optional drink type, and a one-time alert explains the factor on the first discounted log. All new strings ship with en + zh-Hans values (machine-translated, flagged for native review). (`feat/drink-catalog`)
- HealthKit samples now carry write-once metadata (drink type, raw volume in ml, applied and strict factor snapshots, catalog version). The sample quantity stores the effective hydration volume, capped at the poured volume — the app never records more water than was actually drunk. Pre-existing and third-party samples keep counting as plain water at face value.
- Set the amount by tapping the number (type an exact value) or the quick-fill presets (250ml / 500ml / 1L) above the cup. The default pending amount is a standard 250ml serving. The drink menu is now just drink types. (`feat/drink-catalog`)
- Redesigned the on-screen vessel from an abstract cup into a 1 L water bottle (rounded cap + capsule body). The fill is now literal: 500 ml sits at exactly half the bottle, because the default vessel capacity is 1000 ml (34 oz). (`feat/drink-catalog`)
- Drink types are now picked from a horizontal row of colour-coded icons (SF Symbol on a tinted circle) below the bottle instead of a text menu, matching the tap-driven feel of the rest of the screen. The row scrolls to the current selection on appear and rings the active drink. (`feat/drink-catalog`)
- Customizable Quick Add amounts: a "Quick Add Amounts" editor in Settings lets the user set the preset buttons above the bottle to whatever they like (default 250 ml / 500 ml / 1 L, up to six, swipe to delete). Values are stored canonically in ml and shown in the active unit. (`feat/drink-catalog`)
- Pace engine (`PaceCalculator`, Foundation-only, unit-tested): a daily tracking window (default 08:00–22:00, with night-shift windows that cross midnight), an expected-intake curve that reaches the goal 90 min before the window closes, and a nudge planner that decides when to remind — goal-met guard, ≥45 min after the last drink, ≥60 min apart, capped at 5/day, always future-dated, 250 ml / 8 oz behind-pace threshold. This is the tested core for HidrateSpark-style "smart" reminders; the settings UI, notification scheduling, and on-ring pace indicator are a follow-up. (`feat/drink-catalog`)

### Fixed

- The cup fill no longer sloshes wildly for several seconds on launch (the maintainer's "animation glitches" FIXME). The wave's continuous `repeatForever` ripple ran an always-active animation transaction that leaked into the fill offset; the wave surface is now static and the level is rock-solid, while deliberate amount changes still animate. (`feat/drink-catalog`)
- Cup fill now rises from the bottom instead of pouring in from the top: `WaveWithCupHeight` was missing the fill-fraction clamp its sibling `WaveWithBodyHeight` already had. (`feat/drink-catalog`)
- `getStartOfDate(date:)` ignored its argument and always returned the start of *today*. (`fix/readme-todo-bugs`)
- Force-unwrap crash risk on the today-total HealthKit statistics read; it now publishes 0 like the neighbouring nil-statistics branch. (`fix/readme-todo-bugs`)
- Day/week chart data was mutated off the main thread (the README's known SwiftUI bug); assignments now use `await MainActor.run`, which also keeps widget providers from reading stale data immediately after awaiting. (`fix/readme-todo-bugs`)
- The Siri shortcut no longer races widget reloads and notification re-registration against the HealthKit save. (`fix/readme-todo-bugs`)
- `import SwiftUICore` (a non-public umbrella framework, and a hard build error on Xcode 26) replaced with `import SwiftUI`. (`fix/readme-todo-bugs`)

### Changed

- Per-user Xcode state (`xcuserdata`) is no longer tracked. (`ci/actions-and-tests`)
