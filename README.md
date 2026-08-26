Please note that this AI-assisted project is in preliminary stages, and that there has been limited human oversight of the README and associated explanatory files. Closer to stable release dates, this information will be updated and human oversight will become more present.

If you have any concerns, feel free to raise them, and I will do my best to address them as quickly as possible.

Thank you for your interest in the project, and I hope your own projects bring you as much joy as Animal Buddy has brought me in creating it.

<div align="center">
  <img src="App/AnimalBuddyIcon.png" alt="Animal Buddy logo" width="220">
  <h1>Animal Buddy</h1>
  <p>A tiny, cheerful macOS companion for useful drag-and-drop actions.</p>
</div>

Animal Buddy is a native macOS desktop pet that acts as a calm, physical-feeling drag-and-drop target for useful file actions. It stays above normal windows, understands dropped files and URLs, maps modifier keys to actions, and communicates progress through visual states.

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
- `Pet`: state-driven creature rendering, eye tracking, and charm animations.
- `App`: AppKit application lifecycle and non-activating floating window/drop target.

`App/Info.plist` contains the minimal bundle metadata needed to package the SwiftPM executable as a local `.app` for desktop launching.
`App/AnimalBuddyIcon.png` and `App/AnimalBuddy.icns` contain the Animal Buddy app artwork used by both the Dock and menu-bar status item.

The drop layer classifies input, asks `ActionRegistry` for the binding matching `InputCategory + ModifierCombination`, then executes an action with an `ActionContext`. Pet assets can later be introduced behind the state model without changing automation code.

## Current functionality

The first release includes:

- File, directory, image, URL, and text drops with visual drag feedback.
- Modifier-aware actions: Store in folder, Copy path, Reveal in Finder, Move to Trash, Convert to PNG, Optimise image, and Open URL.
- Safe collision handling for file writes and JSON-backed settings stored in `~/Library/Application Support/AnimalBuddy/settings.json`.
- A blue, icon-matched desktop buddy with breathing, bobbing, independent wing flaps, blinking, rosy cheeks, eye highlights, success sparkles, and nearby mouse-tracking eyes.
- A non-activating floating window that remains available across Spaces and does not take keyboard focus from the app being used. The regular app presence keeps Animal Buddy visible in the Dock and Force Quit Applications.
- A hover-only minimize button and menu-bar controls for minimizing to the Dock or hiding while retaining the Animal Buddy menu-bar logo. The minimize animation respects reduced-motion preferences.
- Free placement after dragging, with optional “Snap to Screen Edges” behavior.
- A PiP-style top/bottom close target. Dragging the buddy near the horizontal center of a screen shows the target; releasing within it hides the buddy, while releasing outside it restores the buddy at the dropped location.
- A unified Macros workshop for configuring the left and right blush buttons, plus drop-specific macros. Dragging macros can be assigned to images, folders, applications, files, URLs, text, mixed items, or unknown drops; they run before the normal drop action and can use `{{path}}`, `{{paths}}`, `{{text}}`, and `{{category}}` placeholders. Macro blocks include shell commands, installed applications, URLs, Apple Shortcuts, and nested macros, with cycle protection.
- Context-aware drag previews that distinguish applications, directories, images, files, URLs, text, and mixed drops. The buddy holds a matching code-drawn prop such as a camera and SD card, envelope, storage box, document, or question mark; ambiguous configured actions can be chosen from a pet-attached popover after release.

Hover over the pet to reveal the minimize button. Use “Show Animal Buddy” from the status-item menu to bring it back after hiding it. Existing single-command macro settings migrate as shell blocks; Shortcut discovery requires the macOS Shortcuts helper service to be available in the logged-in user session.

## Limitations and roadmap

User-editable input bindings, pasteboard monitoring, sandbox entitlement and signing decisions, multi-pet packages, and script/plugin action extensions remain future work. Shortcut discovery depends on the macOS Shortcuts helper service. No extra Accessibility or Input Monitoring permissions are requested; destructive behavior uses macOS Trash, while file writes avoid overwrites.
