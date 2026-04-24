import SwiftUI

// TopNavBar was removed in favor of the macOS-native NavigationSplitView
// + window toolbar idiom. It attempted to literally replicate the web's
// horizontal top icon strip, but that chrome read as foreign on macOS —
// Mac users expect a sidebar for primary navigation and a title-bar
// toolbar for app-wide controls (theme, user). The web's layout is
// emulated inside the detail view instead (DataStrip + tabs + right
// Tracks/Cars sidebar), which matches content density without fighting
// platform conventions.
//
// This file is intentionally empty; delete when convenient.
