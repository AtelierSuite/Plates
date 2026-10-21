import SwiftUI

/// Where one line of a checklist has got to: still to come, being worked on, or finished.
enum ProgressMarkerState: Equatable {
    case waiting
    case working
    case done
}
