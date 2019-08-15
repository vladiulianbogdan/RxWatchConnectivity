//
//  RxWCSession.swift
//  RxWatchConnectivity
//
//  Created by Bogdan Vlad on 8/13/19.
//

import WatchConnectivity
import RxSwift

public enum RxWCSessionError: Error {
    case watchAppIsNotInstalled
    case sessionIsNotActivated
    case counterpartAppIsNotReachable
}

public class RxWCSession {
    // Session states

    /// Observable that emits whenever the activation state of the session changes. On subscription it emits the current state.
    public var activationState: Observable<WCSessionActivationState> {
        return .deferred { [delegate, session] in
            return delegate.activationDidComplete
                .map { $0.0 }
                .startWith(session.activationState)
        }
    }

    /// Observable that emits whenever the rechability state of the session changes. On subscription it emits the current state.
    public var isReachable: Observable<Bool> {
        return .deferred { [delegate, session] in
            return delegate.sessionReachabilityDidChange
                .map { $0.isReachable }
                .startWith(session.isReachable)
        }
    }

    /// Observable that emits whenever the value of the outstanding file transfer array changes. On subscription it emits the current state.
    public var outstandingFileTransfers: Observable<[WCSessionFileTransfer]> {
        return .deferred { [delegate, session] in
            return delegate.didFinishFileTransfer
                .map { [session] _ in session.outstandingFileTransfers }
                .startWith(session.outstandingFileTransfers)
        }
    }
    
    // Receiving data

    /// Observable that emits whenever a message without reply handler is received.
    public var didReceiveMessage: Observable<[String: Any]> {
        return delegate.didReceiveMessage
    }

    /// Observable that emits whenever a message with a reply handler is received.
    /// The emited value is a tupple containing the received message and a reply callback.
    public var didReceiveMessageWithReplyHandler: Observable<([String: Any], ([String : Any]) -> Void)> {
        return delegate.didReceiveMessageWithReplyHandler
    }

    /// Observable that emits whenever a data message without a reply handler is received.
    public var didReceiveMessageData: Observable<Data> {
        return delegate.didReceiveMessageData
    }

    /// Observable that emits whenever a data message with a reply handler is received.
    /// The emited value is a tupple containing the received data message and a reply callback.
    public var didReceiveMessageDataWithReplyHandler: Observable<(Data, (Data) -> Void)> {
        return delegate.didReceiveMessageDataWithReplyHandler
    }

    private let session: WCSession
    private let delegate: RxWCSessionDelegate

    public init(session: WCSession = WCSession.default) {
        self.session = session
        self.delegate = RxWCSessionDelegate()

        session.delegate = delegate
    }

    public func activate() -> Bool {
        guard WCSession.isSupported() else {
            return false
        }

        session.activate()

        return true
    }

    public func sendMessage(_ message: [String: Any], waitForSession: Bool = true) -> Single<[String: Any]> {
        let sendMessage = Single<[String: Any]>.create { [session] observer in
            session.sendMessage(message, replyHandler: { message in
                observer(.success(message))
            }, errorHandler: { error in
                observer(.error(error))
            })

            return Disposables.create()
        }

        return isAbleToSendData(waitForSession: true)
            .flatMap { _ in
                sendMessage
            }
    }

    public func sendMessageWithoutReply(_ message: [String: Any], waitForSession: Bool = true) -> Observable<Void> {
        let sendMessage = Observable<Void>.create { [session] observer in
            session.sendMessage(message, replyHandler: nil, errorHandler: { error in
                observer.onError(error)
            })

            return Disposables.create()
        }

        return isAbleToSendData(waitForSession: true)
            .asObservable()
            .flatMap { _ in
                return sendMessage
            }
    }

    public func send(messageData: Data, waitForSession: Bool = true) -> Single<Data> {
        let sendMessageData = Single<Data>.create { [session] observer in
            session.sendMessageData(messageData, replyHandler: { data in
                observer(.success(data))
            }, errorHandler: { error in
                observer(.error(error))
            })

            return Disposables.create()
        }

        return isAbleToSendData(waitForSession: true)
            .flatMap { _ in
                sendMessageData
            }
    }

    public func sendWithoutReply(messageData: Data, waitForSession: Bool = true) -> Observable<Void> {
        let sendMessageData = Observable<Void>.create { [session] observer in
            session.sendMessageData(messageData, replyHandler: nil, errorHandler: { error in
                observer.onError(error)
            })

            return Disposables.create()
        }

        return isAbleToSendData(waitForSession: true)
            .asObservable()
            .flatMap { _ in
                sendMessageData
            }
    }

    public func transferFile(_ file: URL, metadata: [String : Any]?) -> Observable<Progress> {
        return .create { [session, delegate] observer in
            let fileTransfer = session.transferFile(file, metadata: metadata)
            let compositeDisposable = CompositeDisposable()

            observer.onNext(fileTransfer.progress)

            let monitorFileTransfersDispsoable = delegate.didFinishFileTransfer
                .subscribe(onNext: { transfer, error in
                    guard transfer == fileTransfer else {
                        return
                    }

                    if let error = error {
                        observer.onError(error)
                    }

                    observer.onCompleted()
                })

            let fileTransferDisposable = Disposables.create {
                fileTransfer.cancel()
            }
            
            _ = compositeDisposable.insert(monitorFileTransfersDispsoable)
            _ = compositeDisposable.insert(fileTransferDisposable)

            return compositeDisposable
        }
    }

    public func transferUserInfo(_ userInfo: [String : Any] = [:]) -> Observable<Void> {
        return .create { [session, delegate] observer in
            let userInfoTransfer = session.transferUserInfo(userInfo)
            let compositeDisposable = CompositeDisposable()

            let monitorFileTransfersDispsoable = delegate.didFinishWithUserInfoTransfer
                .subscribe(onNext: { transfer, error in
                    guard transfer == userInfoTransfer else {
                        return
                    }

                    if let error = error {
                        observer.onError(error)
                    }

                    observer.onCompleted()
                })

            let fileTransferDisposable = Disposables.create {
                userInfoTransfer.cancel()
            }

            _ = compositeDisposable.insert(monitorFileTransfersDispsoable)
            _ = compositeDisposable.insert(fileTransferDisposable)

            return compositeDisposable
        }
    }
}

private extension RxWCSession {
    func isAbleToSendData(waitForSession: Bool) -> Single<Bool> {
        return .deferred { [session, activationState, isReachable] in
            guard waitForSession else {
                switch (session.activationState, session.isReachable) {
                case (.activated, true):
                    return .just(true)
                case (.activated, false):
                    throw RxWCSessionError.counterpartAppIsNotReachable
                case (.inactive, _),
                     (.notActivated, _),
                     (_, _):
                    throw RxWCSessionError.sessionIsNotActivated
                }
            }

            return activationState.filter { $0 == .activated }
                .flatMapLatest { [isReachable] _ in return isReachable }
                .filter {  $0 == true }
                .take(1)
                .asSingle()
            }
    }

    #if os(iOS)
    func checkAppIsInstalled() throws {
        guard session.isWatchAppInstalled else {
            throw RxWCSessionError.watchAppIsNotInstalled
        }
    }
    #endif
}
