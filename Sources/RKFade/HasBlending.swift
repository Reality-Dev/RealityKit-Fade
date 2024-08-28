#if !os(visionOS)
import RealityKit

public protocol HasBlending: RealityKit.Material {
    var opacityBlending: CustomMaterial.Blending { get set }

    /// The amount of opacity specified as a single value. The final rendered opacity could also potentially be affected by the opacity texture, if any.
    var opacityScale: Float { get set }
}

public extension HasBlending {
    var opacityScale: Float {
        get {
            switch opacityBlending {
            case .opaque:
                return 1.0
            case let .transparent(opacity: opacity):
                return opacity.scale
            @unknown default:
                return 1.0
            }
        }
        set {
            switch opacityBlending {
            case .opaque:
                opacityBlending = .transparent(opacity: .init(scale: newValue, texture: nil))
            case let .transparent(opacity: opacity):
                opacityBlending = .transparent(opacity: .init(scale: newValue, texture: opacity.texture))
            @unknown default:
                break
            }
        }
    }
}

extension CustomMaterial: HasBlending {
    public var opacityBlending: Blending {
        get {
            return blending
        }
        set {
            blending = newValue
        }
    }
}

extension PhysicallyBasedMaterial: HasBlending {
    public var opacityBlending: CustomMaterial.Blending {
        get {
            return .init(blending: blending)
        }
        set {
            blending = .init(blending: newValue)
        }
    }
}

extension UnlitMaterial: HasBlending {
    public var opacityBlending: CustomMaterial.Blending {
        get {
            return .init(blending: blending)
        }
        set {
            blending = .init(blending: newValue)
        }
    }
}
#endif
