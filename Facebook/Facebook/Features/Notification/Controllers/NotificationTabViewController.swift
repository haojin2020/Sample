//
//  NotificationTabViewController.swift
//  Facebook
//
//  Created by 최유림 on 2021/11/24.
//

import UIKit
import RxSwift
import RxCocoa
import RxGesture

class NotificationTabViewController: BaseTabViewController<NotificationTabView>, UIScrollViewDelegate {

    var tableView: UITableView {
        tabView.notificationTableView
    }
    
    private let isShowingBottomSheet: BehaviorRelay<Bool> = BehaviorRelay(value: false)
    
    let viewModel = PaginationViewModel<Notification>(endpoint: .notification())
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(customView: tabView.largeTitleLabel)

        bind()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.tabView.layoutIfNeeded()
    }
    
    private func bind() {
        tableView.rx.setDelegate(self).disposed(by: disposeBag)
        
        viewModel.dataList
            .observe(on: MainScheduler.instance)
            .bind(to: tableView.rx.items(cellIdentifier: NotificationCell.reuseIdentifier, cellType: NotificationCell.self)) { [weak self] _, notification, cell in
                self?.configure(cell: cell, with: notification)
            }.disposed(by: disposeBag)

        StateManager.of.notification.bind(with: viewModel.dataList).disposed(by: disposeBag)
        
        /// `isLoading` 값이 바뀔 때마다 하단 스피너를 토글합니다.
        viewModel.isLoading
            .asDriver()
            .drive(onNext: { [weak self] isLoading in
                if isLoading {
                    self?.tableView.showBottomSpinner()
                } else {
                    self?.tableView.hideBottomSpinner()
                }
            })
            .disposed(by: disposeBag)
        
        /// 새로고침 제스쳐가 인식될 때마다 `refresh` 함수를 실행합니다.
        tabView.refreshControl.rx.controlEvent(.valueChanged)
            .subscribe(onNext: { [weak self] in
                self?.viewModel.refresh()
            })
            .disposed(by: disposeBag)
        
        /// 새로고침이 완료될 때마다 `refreshControl`의 애니메이션을 중단시킵니다.
        viewModel.refreshComplete
            .asDriver(onErrorJustReturn: false)
            .drive(onNext : { [weak self] refreshComplete in
                if refreshComplete {
                    self?.tabView.refreshControl.endRefreshing()
                }
            })
            .disposed(by: disposeBag)
        
        tabView.bottomSheetView.rx.tapGesture().bind { [weak self] _ in
            self?.isShowingBottomSheet.accept(false)
        }.disposed(by: disposeBag)
        
        isShowingBottomSheet
            .observe(on: MainScheduler.instance)
            .bind { [weak self] isShowing in
            isShowing ? self?.tabView.showBottomSheetView() : self?.tabView.dismissBottomSheetView()
        }.disposed(by: disposeBag)

        /// cell을 탭하면 알림을 확인한 것으로 간주함
        Observable.zip(tableView.rx.modelSelected(Notification.self), tableView.rx.itemSelected).bind { [weak self] (notification, indexPath) in
            if !notification.is_checked {
                self?.check(notification: notification)
            }
            if let cell = self?.tableView.cellForRow(at: indexPath) {
                cell.isSelected = false
                self?.tableView.layoutIfNeeded()
            }
            if let post = notification.post {
                self?.push(viewController: PostDetailViewController(post: post))
            }
        }.disposed(by: disposeBag)
    }
}

extension NotificationTabViewController {
    private func configure(cell: NotificationCell, with notification: Notification) {
        cell.configure(with: notification)
        
        cell.detailButton.rx.tap.bind { [weak self] in
            self?.isShowingBottomSheet.accept(true)
        }.disposed(by: disposeBag)
    }
    
    private func check(notification: Notification) {
        NetworkService.get(endpoint: .notification(id: notification.id), as: Notification.self)
            .bind { [weak self] response in
                print(response)
                self?.tableView.layoutIfNeeded()
            }.disposed(by: disposeBag)
    }
}
