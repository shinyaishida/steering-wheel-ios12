//
//  CBUUIDs.swift
//  Steering Wheel iOS12
//
//  Created by Shinya Ishida on 2022/10/01.
//

import Foundation
import CoreBluetooth

struct CBUUIDs {

    static let Service_UUID = CBUUID(string: Environment.serviceUUID)
    // read/notify
    static let Control_Char_UUID = CBUUID(string: Environment.controlUUID)
    // write without response
    static let Drive_Char_UUID = CBUUID(string: Environment.driveUUID)
}
