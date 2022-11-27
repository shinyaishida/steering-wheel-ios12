//
//  ViewController.swift
//  Steering Wheel iOS12
//
//  Created by Shinya Ishida on 2022/09/23.
//

import UIKit
import CoreBluetooth
import CoreMotion

enum GestureState: String {
    case Neutral = "Neutral"
    case Forward = "Forward"
    case Backward = "Backward"
}

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralDelegate, CBPeripheralManagerDelegate {

    private let RadianToDegree = 180 / Double.pi
    private let OverrotationThreshold = 90
    private var gestureState: GestureState
    private var steeringState: NSInteger
    @IBOutlet weak var drivingStateLabel: UILabel!
    @IBOutlet weak var steeringStateLabel: UILabel!
//    @IBOutlet weak var pitchLabel: UILabel!
//    @IBOutlet weak var rollLabel: UILabel!
//    @IBOutlet weak var yawLabel: UILabel!

    private var centralManager: CBCentralManager!
    private let motionManager = CMMotionManager()
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscapeLeft
    }
    
    init() {
        gestureState = GestureState.Neutral
        steeringState = 0
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        gestureState = GestureState.Neutral
        steeringState = 0
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setBluetoothCentralManager()
        setDrivingState(state: GestureState.Neutral)
        enableSteeringSensor()
        Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(ViewController.sendDrivingState), userInfo: nil, repeats: true)
    }
    
    private func setBluetoothCentralManager() {
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    private func setDrivingState(state: GestureState) {
        gestureState = state
        drivingStateLabel.text = "\(gestureState)"
    }
    
    private func enableSteeringSensor() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: OperationQueue.current!,
                                               withHandler: { (motion, error) in
            guard let motion = motion, error == nil else { return }
            self.setSteeringState(yaw: motion.attitude.yaw)
//            self.dumpMotion(motion)
        })
    }
    
    private func setSteeringState(yaw: Double) {
        let yawInDegree = Int(yaw * 180 / Double.pi)
        if !overrotated(yawInDegree) && (yawInDegree != steeringState) {
            updateSteeringState(yawInDegree)
        }
    }
    
    private func updateSteeringState(_ yawInDegree: Int) {
        steeringState = yawInDegree
        writeOutgoingValue(data: "Steering \(steeringState)")
        steeringStateLabel.text = "\(steeringState)"
    }
    
    private func overrotated(_ yawInDegree: Int) -> Bool {
        let switched = yawInDegree * steeringState < 0
        return switched && abs(yawInDegree) > OverrotationThreshold && abs(steeringState) > OverrotationThreshold
    }
    
//    private func dumpMotion(_ motion: CMDeviceMotion) {
//        let attitude = motion.attitude
//        pitchLabel.text = "\(Int(attitude.pitch * RadianToDegree))"
//        rollLabel.text = "\(Int(attitude.roll * RadianToDegree))"
//        yawLabel.text = "\(Int(attitude.yaw * RadianToDegree))"
//    }
    
    @objc private func sendDrivingState() {
        writeOutgoingValue(data: gestureState.rawValue)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.setAnimationsEnabled(false)
        UIDevice.current.setValue(UIInterfaceOrientation.landscapeLeft.rawValue, forKey: "orientation")
        UIView.setAnimationsEnabled(true)
    }

    @IBAction func ForwardButtonPressed(_ sender: UIButton) {
        setDrivingState(state: GestureState.Forward)
        writeOutgoingValue(data: GestureState.Forward.rawValue)
    }
    
    @IBAction func ForwardButtonReleased(_ sender: UIButton) {
        setDrivingState(state: GestureState.Neutral)
        writeOutgoingValue(data: GestureState.Neutral.rawValue)
    }
    
    @IBAction func BackwardButtonPressed(_ sender: UIButton) {
        setDrivingState(state: GestureState.Backward)
        writeOutgoingValue(data: GestureState.Backward.rawValue)
    }
    
    @IBAction func BackwardButtonReleased(_ sender: UIButton) {
        setDrivingState(state: GestureState.Neutral)
        writeOutgoingValue(data: GestureState.Neutral.rawValue)
    }
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            print("Is Powered Off.")
        case .poweredOn:
            print("Is Powered On.")
            startScanning()
        case .unsupported:
            print("Is Unsupported.")
        case .unauthorized:
            print("Is Unauthorized.")
        case .unknown:
            print("Unknown")
        case .resetting:
            print("Resetting")
        @unknown default:
            print("Error")
        }
    }
    
    func startScanning() -> Void {
        print("Start scanning periferals...")
        centralManager?.scanForPeripherals(withServices: [CBUUIDs.Service_UUID])
    }
    
    private var blePeripheral: CBPeripheral!
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        blePeripheral = peripheral
        blePeripheral.delegate = self
        print("Peripheral Discovered: \(peripheral)")
        print("Peripheral name: \(peripheral.name)")
        print ("Advertisement Data : \(advertisementData)")
        centralManager?.stopScan()
        centralManager?.connect(blePeripheral, options: nil)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        blePeripheral.discoverServices([CBUUIDs.Service_UUID])
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        print("*******************************************************")
        if ((error) != nil) {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        guard let services = peripheral.services else {
            return
        }
        //We need to discover the all characteristic
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
        print("Discovered Services: \(services)")
    }
    
    private var txCharacteristic: CBCharacteristic!
    private var rxCharacteristic: CBCharacteristic!
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            return
        }
        print("Found \(characteristics.count) characteristics.")
        for characteristic in characteristics {
            print("Found characteristic: \(characteristic.description)")
            if characteristic.uuid.isEqual(CBUUIDs.Control_Char_UUID) {
                rxCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: rxCharacteristic!)
                peripheral.readValue(for: characteristic)
                print("RX Characteristic: \(rxCharacteristic.uuid)")
            }
            if characteristic.uuid.isEqual(CBUUIDs.Drive_Char_UUID) {
                txCharacteristic = characteristic
                print("TX Characteristic: \(txCharacteristic.uuid)")
                updateSteeringState(0)
            }
        }
    }
    
    func disconnectFromDevice () {
        if blePeripheral != nil {
            centralManager?.cancelPeripheralConnection(blePeripheral!)
        }
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            print("Peripheral Is Powered On.")
        case .unsupported:
            print("Peripheral Is Unsupported.")
        case .unauthorized:
            print("Peripheral Is Unauthorized.")
        case .unknown:
            print("Peripheral Unknown")
        case .resetting:
            print("Peripheral Resetting")
        case .poweredOff:
            print("Peripheral Is Powered Off.")
        @unknown default:
            print("Error")
        }
    }
    
    func writeOutgoingValue(data: String) {
        let valueString = (data as NSString).data(using: String.Encoding.utf8.rawValue)
        if let peripheral = blePeripheral {
            if let txCharacteristic = txCharacteristic {
                print("Sending \(data)")
                peripheral.writeValue(valueString!, for: txCharacteristic, type: CBCharacteristicWriteType.withResponse)
            }
        }
    }
}
