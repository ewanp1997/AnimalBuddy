# Animal Buddy

Animal Buddy is a native macOS desktop pet that acts as a calm, physical-feeling drag-and-drop target for useful file actions. The MVP uses a placeholder creature, stays above normal windows, understands dropped files/URLs, maps modifier keys to actions, and communicates progress through visual states.

## Build and run

Requires macOS 13+ and Swift 6 (Apple Silicon development target). With the Swift command-line tools installed:

```sh
swift build
swift test
swift run AnimalBuddy
```

`swift run` launches an accessory app with a transparent floating pet window. Full Xcode is not required for the SwiftPM build; an Xcode project can be added later for signing and distribution.

On the current machine, `swift build -c release` succeeds. `swift test` is configured with XCTest but cannot run with the installed Command Line Tools alone because the XCTest module is supplied by the full Xcode installation; run it after installing/selecting Xcode.

## Architecture

- `Models`: input categories, modifier bindings, pet states, action context, and settings.
- `Services`: UTType/resource-value classification and JSON settings persistence.
- `Actions`: protocol-based actions and registry, independent of UI.
- `Pet`: state-driven placeholder creature rendering.
- `App`: AppKit application lifecycle and non-activating floating window/drop target.

`App/Info.plist` contains the minimal bundle metadata needed to package the SwiftPM executable as a local `.app` for desktop launching.

The drop layer classifies input, asks `ActionRegistry` for the binding matching `InputCategory + ModifierCombination`, then executes an action with an `ActionContext`. Pet assets can later be introduced behind the state model without changing automation code.

## Current functionality

Supports file/directory/image drops, URL text drops, drag feedback, modifier-aware bindings, Store, Copy path, Reveal, Trash, PNG conversion, JPEG optimisation, a URL opener, safe collision names, persisted settings, nearby mouse-tracking eyes, a hover-only minimize control, a menu-bar status item, Dock/menu-bar minimize destinations, and top/bottom-center drag dismissal.

Hover over the pet to reveal the minimize button. The status-item menu controls whether minimizing goes to the Dock or hides the pet while leaving the Animal Buddy logo in the menu bar. Animal Buddy remains a regular macOS application so it is available in Force Quit Applications. Dragging the pet to the horizontal center near the top or bottom edge of its current screen closes/hides it; use “Show Animal Buddy” from the status-item menu to bring it back.

## Limitations and roadmap

The creature is intentionally a drawn placeholder. Settings UI, user-editable bindings, pasteboard monitoring, Shortcuts invocation, sandbox entitlement decisions, reduced-motion animation, multi-pet packages, and script/plugin actions remain future work. The current settings model is JSON-backed in `~/Library/Application Support/AnimalBuddy/settings.json`; no extra permissions are requested. Destructive behaviour uses macOS Trash, while file writes avoid overwrites.
