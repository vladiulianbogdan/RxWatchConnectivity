//
//  InterfaceController.swift
//  ProjectExample WatchKit Extension
//
//  Created by Bogdan Vlad on 8/14/19.
//  Copyright © 2019 Bogdan Vlad. All rights reserved.
//

import WatchKit
import Foundation
import RxSwift
import RxWatchConnectivity

class InterfaceController: WKInterfaceController {
    let session = RxWCSession()

    var counter = 0
    
    @IBOutlet weak var activationStateLabel: WKInterfaceLabel!
    @IBOutlet weak var lastMessageReceived: WKInterfaceLabel!
    
    private let disposeBag = DisposeBag()

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        session.activationState
            .subscribe(onNext: { [weak self] state in
                let stateString = state == .activated ? "Activated!" : "Not activated"
                self?.activationStateLabel.setText(stateString)
            })
            .disposed(by: disposeBag)

        session.didReceiveMessageWithReplyHandler
            .subscribe(onNext: { [weak self] (message, replyHandler) in
                guard let self = self else { return }
                print(message)
                self.counter += 1
                replyHandler(["response": "Message reply\(self.counter)"])
            })
            .disposed(by: disposeBag)
        // Configure interface objects here.
    }
    
    @IBAction func activateSessionButtonPressed() {
        session.activate()
    }

    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }

}
