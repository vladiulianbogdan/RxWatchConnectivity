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
    
    private let disposeBag = DisposeBag()

    override func awake(withContext context: Any?) {
        super.awake(withContext: context)

        print(session.activate())
        
        session.activationState
            .subscribe(onNext: { state in
                print("New state is \(state.rawValue)")
            })
            .disposed(by: disposeBag)
        
        session.didReceiveMessageWithReplyHandler
            .subscribe(onNext: { (message, replyHandler) in
                print(message)
                replyHandler(["response": "hello world!"])
            })
            .disposed(by: disposeBag)
        // Configure interface objects here.
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
