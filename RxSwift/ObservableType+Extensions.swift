//
//  ObservableType+Extensions.swift
//  RxSwift
//
//  Created by Krunoslav Zaher on 2/21/15.
//  Copyright © 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

extension ObservableType {
    /**
    Subscribes an event handler to an observable sequence.

    - parameter on: Action to invoke for each event in the observable sequence.
    - returns: Subscription object used to unsubscribe from the observable sequence.
    */
    // @warn_unused_result(message: "http://git.io/rxs.ud")
    public func subscribe(_ on: @escaping (Event<E>) -> Void)
        -> Disposable {
        let observer = AnonymousObserver { e in
            on(e)
        }
        return self.subscribeSafe(observer)
    }

    #if DEBUG
    /**
    Subscribes an element handler, an error handler, a completion handler and disposed handler to an observable sequence.

    - parameter onNext: Action to invoke for each element in the observable sequence.
    - parameter onError: Action to invoke upon errored termination of the observable sequence.
    - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
    - parameter onDisposed: Action to invoke upon any type of termination of sequence (if the sequence has
        gracefully completed, errored, or if the generation is cancelled by disposing subscription).
    - returns: Subscription object used to unsubscribe from the observable sequence.
    */
    // @warn_unused_result(message: "http://git.io/rxs.ud")
    public func subscribe(file: String = #file, line: UInt = #line, function: String = #function, onNext: ((E) -> Void)? = nil, onError: ((Swift.Error) -> Void)? = nil, onCompleted: (() -> Void)? = nil, onDisposed: (() -> Void)? = nil)
        -> Disposable {

        let disposable: Disposable

        if let disposed = onDisposed {
            disposable = Disposables.create(with: disposed)
        }
        else {
            disposable = Disposables.create()
        }

        let observer = AnonymousObserver<E> { e in
            switch e {
            case .next(let value):
                onNext?(value)
            case .error(let e):
                if let onError = onError {
                    onError(e)
                }
                else {
                    print("Received unhandled error: \(file):\(line):\(function) -> \(e)")
                }
                disposable.dispose()
            case .completed:
                onCompleted?()
                disposable.dispose()
            }
        }
        return Disposables.create(
            self.subscribeSafe(observer),
            disposable
        )
    }
    #else
    /**
    Subscribes an element handler, an error handler, a completion handler and disposed handler to an observable sequence.

    - parameter onNext: Action to invoke for each element in the observable sequence.
    - parameter onError: Action to invoke upon errored termination of the observable sequence.
    - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
    - parameter onDisposed: Action to invoke upon any type of termination of sequence (if the sequence has
        gracefully completed, errored, or if the generation is cancelled by disposing subscription).
    - returns: Subscription object used to unsubscribe from the observable sequence.
    */
    // @warn_unused_result(message: "http://git.io/rxs.ud")
    public func subscribe(onNext: ((E) -> Void)? = nil, onError: ((Swift.Error) -> Void)? = nil, onCompleted: (() -> Void)? = nil, onDisposed: (() -> Void)? = nil)
        -> Disposable {

        let disposable: Disposable

        if let disposed = onDisposed {
            disposable = Disposables.create(with: disposed)
        }
        else {
            disposable = Disposables.create()
        }

        let observer = AnonymousObserver<E> { e in
            switch e {
            case .next(let value):
                onNext?(value)
            case .error(let e):
                onError?(e)
                disposable.dispose()
            case .completed:
                onCompleted?()
                disposable.dispose()
            }
        }
        return Disposables.create(
            self.subscribeSafe(observer),
            disposable
        )
    }
    #endif

    /**
    Subscribes an element handler to an observable sequence.

    - parameter onNext: Action to invoke for each element in the observable sequence.
    - returns: Subscription object used to unsubscribe from the observable sequence.
    */
    // @warn_unused_result(message: "http://git.io/rxs.ud")
    @available(*, deprecated, renamed: "subscribe(onNext:)")
    public func subscribeNext(_ onNext: @escaping (E) -> Void)
        -> Disposable {
        let observer = AnonymousObserver<E> { e in
            if case .next(let value) = e {
                onNext(value)
            }
        }
        return self.subscribeSafe(observer)
    }

    /**
    Subscribes an error handler to an observable sequence.

    - parameter onError: Action to invoke upon errored termination of the observable sequence.
    - returns: Subscription object used to unsubscribe from the observable sequence.
    */
    // @warn_unused_result(message: "http://git.io/rxs.ud")
    @available(*, deprecated, renamed: "subscribe(onError:)")
    public func subscribeError(_ onError: @escaping (Swift.Error) -> Void)
        -> Disposable {
        let observer = AnonymousObserver<E> { e in
            if case .error(let error) = e {
                onError(error)
            }
        }
        return self.subscribeSafe(observer)
    }

    /**
    Subscribes a completion handler to an observable sequence.

    - parameter onCompleted: Action to invoke upon graceful termination of the observable sequence.
    - returns: Subscription object used to unsubscribe from the observable sequence.
    */
    // @warn_unused_result(message: "http://git.io/rxs.ud")
    @available(*, deprecated, renamed: "subscribe(onCompleted:)")
    public func subscribeCompleted(_ onCompleted: @escaping () -> Void)
        -> Disposable {
        let observer = AnonymousObserver<E> { e in
            if case .completed = e {
                onCompleted()
            }
        }
        return self.subscribeSafe(observer)
    }
}

public extension ObservableType {
    /**
    All internal subscribe calls go through this method.
    */
    // @warn_unused_result(message: "http://git.io/rxs.ud")
    func subscribeSafe<O: ObserverType>(_ observer: O) -> Disposable where O.E == E {
        return self.asObservable().subscribe(observer)
    }
}
