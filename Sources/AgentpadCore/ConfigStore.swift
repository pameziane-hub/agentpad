import Foundation

/// Single source of truth for the live mapping: holds the current Config,
/// applies in-app remapping, persists every change to disk, and notifies
/// the UI. Swap semantics (the two buttons exchange actions) so no action
/// is ever lost by rebinding.
public final class ConfigStore {
    public private(set) var config: Config
    public var onChange: (() -> Void)?
    private let url: URL

    public init(config: Config, url: URL = ConfigLoader.defaultURL) {
        self.config = config
        self.url = url
    }

    public func setSounds(_ enabled: Bool) {
        guard config.fx.sounds != enabled else { return }
        config.fx.sounds = enabled
        ConfigLoader.write(config, to: url)
        onChange?()
    }

    public func setShotVariant(_ variant: String) {
        guard config.fx.shotVariant != variant else { return }
        config.fx.shotVariant = variant
        ConfigLoader.write(config, to: url)
        onChange?()
    }

    public func setReloadVariant(_ variant: String) {
        guard config.fx.reloadVariant != variant else { return }
        config.fx.reloadVariant = variant
        ConfigLoader.write(config, to: url)
        onChange?()
    }

    public func setVolume(_ volume: Float) {
        let clamped = min(max(volume, 0), 1)
        guard config.fx.volume != clamped else { return }
        config.fx.volume = clamped
        ConfigLoader.write(config, to: url)
        onChange?()
    }

    public func swapBinding(_ first: String, _ second: String) {
        guard first != second else { return }
        let firstAction = config.buttons[first]
        let secondAction = config.buttons[second]
        config.buttons[first] = secondAction
        config.buttons[second] = firstAction
        ConfigLoader.write(config, to: url)
        onChange?()
    }
}
