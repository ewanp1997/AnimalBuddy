# Development notes

Animal Buddy uses SwiftPM because this machine has Swift command-line tools but no full Xcode installation. AppKit is used for the transparent non-activating `NSPanel`, window level, Spaces/full-screen behaviour, accessibility, and native dragging APIs. Foundation and UniformTypeIdentifiers provide persistence and input classification; AppKit provides image conversion, Finder reveal, Trash, pasteboard, and URL opening.

Actions conform to a small protocol and are registered separately from the pet view. Bindings use a serializable raw modifier value so preferences can evolve without UI coupling. File operations are conservative: copies use unique destination names, and deletion means moving to Trash.

The current drag implementation reads file URLs and string data from the drag pasteboard. A production version should add a dedicated drag monitor for reliable modifier previews, handle mixed drops explicitly, and expose settings for destination folders and bindings. Shortcuts should be added as an action implementation that invokes the user-selected shortcut through the macOS `shortcuts` tool only after explicit configuration.
