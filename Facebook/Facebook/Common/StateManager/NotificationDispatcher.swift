//
//  NotificationDispatcher.swift
//  Facebook
//
//  Created by 최유림 on 2022/01/20.
//

import RxSwift
import RxRelay

class NotificationDispatcher: Dispatcher<Notification> {
    
    // 알림을 확인한 경우
    func dispatch(_ notification: Notification, isChecked: Bool) {
        var notification = notification
        notification.is_checked = isChecked
        dispatchedSignals.accept(.init(data: notification, operation: .edit))
    }
}
