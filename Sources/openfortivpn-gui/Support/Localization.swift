import Foundation

/// UI strings are authored in Traditional Chinese (this app's original
/// language) and looked up in Resources/Localizable.xcstrings, which also
/// carries the English translations. Always routes through `Bundle.module`
/// rather than the SwiftUI-default `Bundle.main` — as a manually-packaged
/// SwiftPM executable (not a real Xcode app target), `Bundle.main` never
/// contains the compiled string catalog; only the generated resource bundle
/// (copied into Contents/Resources by Scripts/run.sh and install.sh) does.
func L(_ key: String.LocalizationValue) -> String {
    String(localized: key, bundle: .module)
}
