//
//  ProgressComponent.swift
//  GrimpossibleMission
//
//  Generic component for tracking progress of any timed activity.
//

import RealityKit

/// Generic component for tracking progress over time (0.0 to 1.0).
/// Can be used for searching, lockpicking, crafting, health bars, etc.
struct ProgressComponent: Component {
    /// Current progress (0.0 = not started, 1.0 = complete)
    var progress: Float = 0.0

    /// Duration in seconds to complete (from 0.0 to 1.0)
    var duration: Float = 2.0

    /// Check if progress is complete
    var isComplete: Bool {
        progress >= 1.0
    }

    /// Check if progress has started
    var hasStarted: Bool {
        progress > 0.0
    }
}
