//
//  DispatchQueueScheduler.swift
//  Rx
//
//  Created by Krunoslav Zaher on 2/8/15.
//  Copyright (c) 2015 Krunoslav Zaher. All rights reserved.
//

import Foundation

// This is a scheduler that wraps dispatch queue.
// It can wrap both serial and concurrent dispatch queues.
//
// It is extemely important that this scheduler is serial, because
// certain operator perform optimizations that rely on that property.
//
// Because there is no way of detecting is passed dispatch queue serial or
// concurrent, for every queue that is being passed, worst case (concurrent)
// will be assumed, and internal serial proxy dispatch queue will be created.
//
// This scheduler can also be used with internal serial queue alone.
// In case some customization need to be made on it before usage,
// internal serial queue can be customized using `serialQueueConfiguration` 
// callback.
//
public class DispatchQueueScheduler: Scheduler {
    public typealias TimeInterval = NSTimeInterval
    public typealias Time = NSDate
    
    private let serialQueue : dispatch_queue_t
    
    public var now : NSDate {
        get {
            return NSDate()
        }
    }
    
    init(serialQueue: dispatch_queue_t) {
        self.serialQueue = serialQueue
    }

    // Creates new serial queue named `name` for internal scheduler usage
    public convenience init(internalSerialQueueName: String) {
        self.init(internalSerialQueueName: internalSerialQueueName, serialQueueConfiguration: { _ -> Void in })
    }
    
    // Creates new serial queue named `name` for internal scheduler usage
    public convenience init(internalSerialQueueName: String, serialQueueConfiguration: (dispatch_queue_t) -> Void) {
        let queue = dispatch_queue_create(internalSerialQueueName, DISPATCH_QUEUE_SERIAL)
        serialQueueConfiguration(queue)
        self.init(serialQueue: queue)
    }
    
    public convenience init(queue: dispatch_queue_t, internalSerialQueueName: String) {
        let serialQueue = dispatch_queue_create(internalSerialQueueName, DISPATCH_QUEUE_SERIAL)
        dispatch_set_target_queue(serialQueue, queue)
        self.init(serialQueue: serialQueue)
    }
    
    // Convenience init for scheduler that wraps one of the global concurrent dispatch queues.
    //
    // DISPATCH_QUEUE_PRIORITY_DEFAULT
    // DISPATCH_QUEUE_PRIORITY_HIGH
    // DISPATCH_QUEUE_PRIORITY_LOW
    public convenience init(globalConcurrentQueuePriority: Int) {
        self.init(globalConcurrentQueuePriority: globalConcurrentQueuePriority, internalSerialQueueName: "rx.global_dispatch_queue.serial.\(globalConcurrentQueuePriority)")
    }

    public convenience init(globalConcurrentQueuePriority: Int, internalSerialQueueName: String) {
        self.init(queue: dispatch_get_global_queue(globalConcurrentQueuePriority, UInt(0)), internalSerialQueueName: internalSerialQueueName)
    }
    
    class func convertTimeIntervalToDispatchTime(timeInterval: NSTimeInterval) -> dispatch_time_t {
        return dispatch_time(DISPATCH_TIME_NOW, Int64(timeInterval * Double(NSEC_PER_SEC) / 1000))
    }
    
    public final func schedule<StateType>(state: StateType, action: (/*ImmediateScheduler,*/ StateType) -> RxResult<Disposable>) -> RxResult<Disposable> {
        return self.scheduleInternal(state, action: action)
    }
    
    func scheduleInternal<StateType>(state: StateType, action: (/*ImmediateScheduler,*/ StateType) -> RxResult<Disposable>) -> RxResult<Disposable> {
        let cancel = SingleAssignmentDisposable()
        
        dispatch_async(self.serialQueue) {
            if cancel.disposed {
                return
            }
            
            _ = ensureScheduledSuccessfully(action(/*self,*/ state).map { disposable in
                cancel.setDisposable(disposable)
            })
        }
        
        return success(cancel)
    }
    
    public final func scheduleRelative<StateType>(state: StateType, dueTime: NSTimeInterval, action: (/*Scheduler<NSTimeInterval, NSDate>,*/ StateType) -> RxResult<Disposable>) -> RxResult<Disposable> {
        let timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.serialQueue)
        
        let dispatchInterval = MainScheduler.convertTimeIntervalToDispatchTime(dueTime)
        
        let compositeDisposable = CompositeDisposable()
        
        dispatch_source_set_timer(timer, dispatchInterval, DISPATCH_TIME_FOREVER, 0)
        dispatch_source_set_event_handler(timer, {
            if compositeDisposable.disposed {
                return
            }
            ensureScheduledSuccessfully(action(/*self,*/ state).map { disposable in
                compositeDisposable.addDisposable(disposable)
            })
        })
        dispatch_resume(timer)
        
        compositeDisposable.addDisposable(AnonymousDisposable {
            dispatch_source_cancel(timer)
        })
        
        return success(compositeDisposable)
    }
}