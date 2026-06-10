import Foundation

/// Pure stick-shaping math: radial deadzone plus an expo blend between
/// linear and cubic response, so small deflections give fine cursor control
/// while full deflection keeps full speed.
public enum Curves {
    /// - Parameters:
    ///   - deadzone: radial deadzone in 0..<1; deflections below it produce no output
    ///   - expo: 0 = linear, 1 = fully cubic response
    /// - Returns: shaped vector; magnitude is 0...1, direction matches the input
    public static func shape(x: Float, y: Float, deadzone: Float, expo: Float) -> SIMD2<Float> {
        let magnitude = (x * x + y * y).squareRoot()
        guard magnitude > deadzone, deadzone < 1 else { return .zero }
        // rescale so the deadzone edge maps to 0 and full deflection to 1
        let scaled = min((magnitude - deadzone) / (1 - deadzone), 1)
        let shaped = (1 - expo) * scaled + expo * scaled * scaled * scaled
        return SIMD2(x / magnitude, y / magnitude) * shaped
    }
}
