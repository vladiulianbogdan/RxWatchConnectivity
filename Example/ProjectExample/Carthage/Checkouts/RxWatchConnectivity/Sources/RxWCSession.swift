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
    public var activationState: Observable<WCSessionActivationState> {
        return .deferred { [delegate, session] in
            return delegate.activationDidComplete
                .map { $0.0 }
                .startWith(session.activationState)
        }
    }

    public var isReachable: Observable<Bool> {
        return .deferred { [delegate, session] in
            return delegate.sessionReachabilityDidChange
                .map { $0.isReachable }
                .startWith(session.isReachable)
        }
    }

    public var outstandingFileTransfers: Observable<[WCSessionFileTransfer]> {
        return .deferred { [delegate, session] in
            return delegate.didFinishFileTransfer
                .map { [session] _ in session.outstandingFileTransfers }
                .startWith(session.outstandingFileTransfers)
        }
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

    public func sendMessage(_ message: [String: Any], waitForSession: Bool = true) -> Observable<Void> {
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

    public func send(messageData: Data, waitForSession: Bool = true) -> Observable<Void> {
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
