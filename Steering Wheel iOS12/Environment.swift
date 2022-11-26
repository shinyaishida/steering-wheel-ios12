//
//  Environment.swift
//  Steering Wheel iOS12
//
//  Created by Shinya Ishida on 2022/11/26.
//

import Foundation

public enum Environment {
    enum Keys {
        enum Plist {
            static let serviceUUID = "SERVICE_UUID"
            static let controlUUID = "CONTROL_CHAR_UUID"
            static let driveUUID = "DRIVE_CHAR_UUID"
        }
    }
    
    private static let infoDictionary: [String: Any] = {
        guard let dict = Bundle.main.infoDictionary else {
            fatalError("Plist file not found")
        }
        return dict
    }()
    
    static let serviceUUID: String = {
        guard let uuid = Environment.infoDictionary[Keys.Plist.serviceUUID] as? String else {
            fatalError("Service UUID not set in plist")
        }
        return uuid
    }()
    
    static let controlUUID: String = {
        guard let uuid = Environment.infoDictionary[Keys.Plist.controlUUID] as? String else {
            fatalError("Control Characteristic UUID not set in plist")
        }
        return uuid
    }()
    
    static let driveUUID: String = {
        guard let uuid = Environment.infoDictionary[Keys.Plist.driveUUID] as? String else {
            fatalError("Drive Characteristic UUID not set in plist")
        }
        return uuid
    }()
}
