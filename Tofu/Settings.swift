import Foundation

enum Setting: Hashable {
    case useBiometricAuth
}

typealias ListOfSettings = [Setting: Any]

class Settings {
    var allSettings: ListOfSettings = Settings.makeDefault()

    init(_ toSet: ListOfSettings) {
        _ = self.updateSettings(withChanges: toSet)
    }

    func updateSettings(withChanges changes: ListOfSettings) -> Bool {
        return true
    }
}

extension Settings {
    class func makeDefault() -> ListOfSettings {
        let default_settings: ListOfSettings = [
            Setting.useBiometricAuth: false,
        ]
        return default_settings
    }
    
    class func validate(_ toValidate: ListOfSettings) -> Bool {
        return true
    }
}
