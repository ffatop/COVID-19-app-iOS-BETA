//
//  BTLEBroadcaster.swift
//  CoLocate
//
//  Created by NHSX.
//  Copyright © 2020 NHSX. All rights reserved.
//

import Foundation
import CoreBluetooth
import UIKit
import Logging

protocol BTLEBroadcasterStateDelegate {
    func btleBroadcaster(_ broadcaster: BTLEBroadcaster, didUpdateState state: CBManagerState)
}

protocol BTLEBroadcaster {
    func tryStartAdvertising()
}

class ConcreteBTLEBroadcaster: NSObject, BTLEBroadcaster, CBPeripheralManagerDelegate {
    
    static let sonarServiceUUID = CBUUID(nsuuid: UUID(uuidString: "c1f5983c-fa94-4ac8-8e2e-bb86d6de9b21")!)
    static let sonarIdCharacteristicUUID = CBUUID(nsuuid: UUID(uuidString: "85BF337C-5B64-48EB-A5F7-A9FED135C972")!)

    var peripheral: CBPeripheralManager?
    var stateDelegate: BTLEBroadcasterStateDelegate?
    let idGenerator: BroadcastIdGenerator = ConcreteBroadcastIdGenerator.shared

    func tryStartAdvertising() {
        guard let peripheral = peripheral else { return }
        guard idGenerator.broadcastIdentifier() != nil else { return }

        startAdvertising(peripheral: peripheral)
    }

    // MARK: CBPeripheralManagerDelegate

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        logger.info("state: \(peripheral.state)")
        
        stateDelegate?.btleBroadcaster(self, didUpdateState: peripheral.state)

        switch (peripheral.state) {
            
        case .poweredOn:
            self.peripheral = peripheral
            tryStartAdvertising()
            
        default:
            break
        }
    }
    
    private func startAdvertising(peripheral: CBPeripheralManager) {
        guard peripheral.isAdvertising == false else {
            logger.error("Peripheral is already advertising. Will not advertise twice")
            return
        }

        let valueToBroadcast = idGenerator.broadcastIdentifier()
        let service = CBMutableService(type: ConcreteBTLEBroadcaster.sonarServiceUUID, primary: true)

        let identityCharacteristic = CBMutableCharacteristic(type: ConcreteBTLEBroadcaster.sonarIdCharacteristicUUID,
                                                             properties: CBCharacteristicProperties([.read]),
                                                             value: valueToBroadcast,
                                                             permissions: .readable)

        service.characteristics = [identityCharacteristic]
        peripheral.add(service)
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        guard error == nil else {
            logger.info("error: \(error!))")
            return
        }

        logger.info("now advertising our sonarId")
        
        peripheral.startAdvertising([
            CBAdvertisementDataLocalNameKey: "CoLocate",
            CBAdvertisementDataServiceUUIDsKey: [service.uuid]
        ])
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        guard let services = dict[CBPeripheralManagerRestoredStateServicesKey] as? [CBMutableService],
              let sonarIdService = services.first else {
            logger.info("No services to restore!")
            return
        }

        logger.info("restoring \(sonarIdService)")
    }
}

fileprivate let logger = Logger(label: "BTLE")
