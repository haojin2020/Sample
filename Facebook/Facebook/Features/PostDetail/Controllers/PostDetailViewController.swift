//
//  PostViewController.swift
//  Facebook
//
//  Created by 김우성 on 2021/12/05.
//

import UIKit
import RxSwift
import RxCocoa
import RxKeyboard
import SnapKit
import RxGesture

class PostDetailViewController: UIViewController, UIGestureRecognizerDelegate {
    var post: Post
    var asFirstResponder: Bool
    let disposeBag = DisposeBag()
    var didConfigurePostDetailView: Bool = false
    
    /// 댓글 셀의 정보를 임시로 저장한다.
    struct FocusedItem {
        let row: Int
        let comment: Comment
        let cell: CommentCell
    }
    
    var focusedItem: FocusedItem? {
        willSet(newVal) {
            if newVal == nil || focusedItem?.row != newVal?.row {
                focusedItem?.cell.unfocus()
            }
        }
        didSet {
            guard let focusedItem = focusedItem else { return }
            focusedItem.cell.focus()
            postView.showFocusedInfo(with: focusedItem.comment.author.username)
        }
    }
    
    lazy var commentViewModel: CommentPaginationViewModel = {
        return CommentPaginationViewModel(endpoint: .comment(postId: post.id))
    }()
    
    init(post: Post, asFirstResponder: Bool = false) {
        self.post = post
        self.asFirstResponder = asFirstResponder
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func loadView() {
        view = PostDetailView()
    }
    
    var postView: PostDetailView {
        guard let view = view as? PostDetailView else { fatalError("PostView가 제대로 초기화되지 않음.") }
        return view
    }
    
    var commentTableView: UITableView {
        return postView.commentTableView
    }
    
    var keyboardAccessory: UIView {
        return postView.keyboardAccessory
    }
    
    var keyboardTextView: FlexibleTextView {
        return postView.textView
    }
    
    lazy var authorHeaderView: AuthorInfoHeaderView = {
        let view = AuthorInfoHeaderView(imageWidth: 40)
        view.configure(with: post)
        return view
    }()
    
    private lazy var leftChevronButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "chevron.backward", withConfiguration: UIImage.SymbolConfiguration(weight: .heavy))
        config.imagePadding = 0
        config.contentInsets = .init(top: 10, leading: 0, bottom: 10, trailing: 8)
        
        
        let button = UIButton.init(configuration: config)
        button.rx.tap.bind { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        }.disposed(by: disposeBag)
        return button
    }()
    
    func setLeftBarButtonItems() {
        let stackview = UIStackView.init(arrangedSubviews: [leftChevronButton, authorHeaderView])
        stackview.distribution = .equalSpacing
        stackview.axis = .horizontal
        stackview.alignment = .center
        stackview.spacing = 0
        
        let leftBarButtons = UIBarButtonItem(customView: stackview)
        navigationItem.leftBarButtonItem = leftBarButtons
    }
    
    // MARK: View LifeCycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bindTableView()
        bindLikeButton()
        bindCommentButton()
        setLeftBarButtonItems()
        setKeyboardToolbar()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.interactivePopGestureRecognizer!.delegate = self
        navigationController?.interactivePopGestureRecognizer!.isEnabled = true
        
        // tableView의 panGesture보다 swipe back 제스쳐가 우선이다.
        if let interactivePopGestureRecognizer = navigationController?.interactivePopGestureRecognizer {
            commentTableView.panGestureRecognizer.require(toFail: interactivePopGestureRecognizer)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        bindKeyboardHeight()
        if self.asFirstResponder && !keyboardTextView.isFirstResponder {
            keyboardTextView.becomeFirstResponder()
            self.asFirstResponder = false
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !didConfigurePostDetailView {
            postView.postContentHeaderView.configure(with: post)
            didConfigurePostDetailView = true
        }
        postView.commentTableView.adjustHeaderHeight()
    }
    
    // MARK: Keyboard Accessory Logics
    
    var toolbarButtonConstraint: NSLayoutConstraint?
    private func setKeyboardToolbar() {
        postView.addSubview(keyboardAccessory)
        keyboardAccessory.snp.makeConstraints { make in
            make.leading.trailing.equalTo(0)
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom)
        }
    }
    
    
    private func bindKeyboardHeight() {
        RxKeyboard.instance.visibleHeight
            .drive(onNext: { [weak self] keyboardVisibleHeight in
                guard let self = self else { return }
                let toolbarHeight = self.keyboardAccessory.frame.height
                self.keyboardAccessory.snp.remakeConstraints { make in
                    make.left.right.equalTo(0)
                    make.bottom.equalTo(keyboardVisibleHeight == 0 ? self.view.safeAreaLayoutGuide.snp.bottom : self.view.snp.bottom).offset(-keyboardVisibleHeight)
                }
                self.view.setNeedsLayout()
                UIView.animate(withDuration: 0) {
                    self.commentTableView.contentInset.bottom = (keyboardVisibleHeight == 0 ? toolbarHeight : keyboardVisibleHeight + toolbarHeight - self.view.safeAreaInsets.bottom) + CGFloat.standardTopMargin + 7
                    self.commentTableView.verticalScrollIndicatorInsets.bottom = self.commentTableView.contentInset.bottom
                    self.view.layoutIfNeeded()
                }
            })
            .disposed(by: disposeBag)
    }
}

// MARK: Handle Buttons

extension PostDetailViewController {
    private func bindLikeButton() {
        postView.likeButton.rx.tap
            .bind { [weak self] _ in
                guard let self = self else { return }
                self.postView.postContentHeaderView.like()
                NetworkService.put(endpoint: .newsfeedLike(postId: self.post.id), as: LikeResponse.self)
                    .bind { response in
                        self.postView.postContentHeaderView.like(syncWith: response.1)
                    }
                    .disposed(by: self.disposeBag)
            }
            .disposed(by: disposeBag)
    }
    
    private func bindCommentButton() {
        postView.commentButton.rx.tap
            .bind { [weak self] _ in
                guard let self = self else { return }
                self.keyboardTextView.becomeFirstResponder()
            }
            .disposed(by: disposeBag)
    }
}

// MARK: Handle Comments

extension PostDetailViewController {
    
    
    
    
    func bindTableView(){
        
        /// 댓글 데이터 테이블뷰 바인딩
        commentViewModel.dataList
            .observe(on: MainScheduler.instance)
            .bind(to: commentTableView.rx.items(cellIdentifier: CommentCell.reuseIdentifier, cellType: CommentCell.self)) { [weak self] row, comment, cell in
                guard let self = self else { return }
                
                cell.configure(with: comment)
                if row == self.focusedItem?.row {
                    cell.focus()
                }
                
                cell.likeButton.rx.tap
                    .bind { [weak self] _ in
                        
                    }
                    .disposed(by: cell.disposeBag)
                
                cell.replyButton.rx.tap
                    .bind { [weak self] _ in
                        guard let self = self else { return }
                        self.postView.textView.becomeFirstResponder()
                        self.commentTableView.scrollToRow(at: IndexPath(row: row, section: 0), at: .bottom, animated: true)
                        self.focusedItem = .init(row: row, comment: comment, cell: cell)
                    }
                    .disposed(by: cell.disposeBag)
                
            }
            .disposed(by: disposeBag)
        
        /// `isLoading` 값이 바뀔 때마다 하단 스피너를 토글합니다.
        commentViewModel.isLoading
            .asDriver()
            .drive(onNext: { [weak self] isLoading in
                if isLoading {
                    self?.commentTableView.showBottomSpinner()
                } else {
                    self?.commentTableView.hideBottomSpinner()
                }
            })
            .disposed(by: disposeBag)
        
        /// 테이블 맨 아래까지 스크롤할 때마다 `loadMore` 함수를 실행합니다.
        commentTableView.rx.didScroll
            .subscribe { [weak self] _ in
                guard let self = self else { return }
                let offSetY = self.commentTableView.contentOffset.y
                let contentHeight = self.commentTableView.contentSize.height
                if offSetY > (contentHeight - self.commentTableView.frame.size.height - 100) {
                    self.commentViewModel.loadMore()
                }
            }
            .disposed(by: disposeBag)
        
        /// 댓글 전송 버튼의 활성화 여부를 바인딩합니다.
        keyboardTextView.isEmptyObservable.map({ !$0 }).bind(to: postView.sendButton.rx.isEnabled).disposed(by: disposeBag)
        
        /// 전송 버튼을 누르면 댓글을 등록합니다.
        postView.sendButton.rx.tap
            .bind { [weak self] _ in
                guard let self = self else { return }
                let focused = self.focusedItem?.comment
                let parentId = focused?.depth == 2 ? focused?.parent : focused?.id  // 대댓글에는 댓글을 달 수 없다.
                
                NetworkService.upload(endpoint: .comment(postId: self.post.id, to: parentId, content: self.keyboardTextView.text))
                    .subscribe(onNext: { data in
                        data.responseDecodable(of: Comment.self) { dataResponse in
                            guard let comment = dataResponse.value else { return }
                            let indexPath = self.commentViewModel.findInsertionIndexPath(of: comment)
                            self.commentViewModel.insert(comment, at: indexPath)
                            self.commentTableView.scrollToRow(at: indexPath, at: .bottom, animated: true)
                        }
                    }, onError: { error in
                        print(error)
                    })
                    .disposed(by: self.disposeBag)
                self.keyboardTextView.text = ""
                self.postView.hideFocusedInfo()
                self.focusedItem = nil
            }
            .disposed(by: disposeBag)
        
        /// 답글 남기기 취소 버튼
        postView.cancelFocusingButton.rx.tapGesture().when(.recognized)
            .bind { [weak self] _ in
                guard let self = self else { return }
                self.postView.hideFocusedInfo()
                self.focusedItem = nil
            }
            .disposed(by: disposeBag)
    }
    
}
