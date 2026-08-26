# Development notes

Animal Buddy uses SwiftPM because this machine has Swift command-line tools but no full Xcode installation. AppKit is used for the transparent non-activating `NSPanel`, window level, Spaces/full-screen behaviour, accessibility, and native dragging APIs. Foundation and UniformTypeIdentifiers provide persistence and input classification; AppKit provides image conversion, Finder reveal, Trash, pasteboard, and URL opening.

Actions conform to a small protocol and are registered separately from the pet view. Bindings use a serializable raw modifier value so preferences can evolve without UI coupling. File operations are conservative: copies use unique destination names, and deletion means moving to Trash.

The drag implementation reads file URLs and string data from the drag pasteboard and builds a rich context during `draggingEntered`, `draggingUpdated`, and drop. It preserves per-item kinds, handles mixed drops explicitly, previews a matching held prop, and uses the configured modifier bindings to propose actions. Ambiguous configured actions are selected from a pet-attached popover after release. Shortcuts are configured explicitly through the macro workshop and invoked through the macOS `shortcuts` tool.
