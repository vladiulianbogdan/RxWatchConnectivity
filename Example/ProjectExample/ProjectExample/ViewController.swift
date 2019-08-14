//
//  ViewController.swift
//  ProjectExample
//
//  Created by Bogdan Vlad on 8/14/19.
//  Copyright © 2019 Bogdan Vlad. All rights reserved.
//

import UIKit
import RxSwift
import RxCocoa
import RxWatchConnectivity

class ViewController: UIViewController {
    
    @IBOutlet var messageTextField: UITextField!
    @IBOutlet var sessionStateLabel: UILabel!
    @IBOutlet var reachableStateLabel: UILabel!

    var session = RxWCSession()
    
    private let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        session.isReachable
            .map { $0 ? "Is reachable" : "Is not reachable" }
            .bind(to: reachableStateLabel.rx.text)
            .disposed(by: disposeBag)

        session.activationState
            .map { $0 == .activated ? "Activated" : "Not activated" }
            .bind(to: sessionStateLabel.rx.text)
            .disposed(by: disposeBag)
    }

    @IBAction func activateSessionButtonPressed() {
        let result = session.activate()
        print("Session was activated \(result)")
    }

    @IBAction func sendMessageButtonPressed() {
        session.sendMessage(["text": messageTextField.text!])
            .subscribe(onNext: { messageReceived in
                print(messageReceived)
            })
    }
}

