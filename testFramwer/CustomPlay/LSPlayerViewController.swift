//
//  LSPlayerViewController.swift
//  testFramwer
//
//  Created by feixiang on 2026/1/27.
//

import UIKit
import SnapKit
import AVFoundation
import RxSwift
import RxCocoa

let kScreenWidth = UIScreen.main.bounds.size.width
let kScreenHeight = UIScreen.main.bounds.size.height

protocol LSPlayerViewControllerDelegate: AnyObject {
    func videoPlayerDidStartPlaying(_ player: LSPlayerViewController)
    func videoPlayerDidFinishPlaying(_ player: LSPlayerViewController)
    func videoPlayerDidPause(_ player: LSPlayerViewController)
}

class LSPlayerViewController: UIViewController {
    private lazy var popBkgView: UIButton = {
        let tempView = UIButton()
        tempView.frame = CGRect.init(x: 0, y: 0, width: kScreenWidth, height: kScreenHeight)
        tempView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.1)
        return tempView
        
    }()
    
    private var coverImageView: UIImageView?
    
    var delegate: LSPlayerViewControllerDelegate?
    private var speedMenuView: SpeedMenuView?
    private var disposeBag = DisposeBag()
    private var controlView = LSPlayControllerView()
    private var playerManager = LSPlayManager()
    // private var tapTimer: Timer?
    private lazy var playAndPauseBtn: UIButton = {
        let tempBtn = UIButton()
        let config = UIImage.SymbolConfiguration(pointSize: 28, weight: .bold, scale: .large)
        let playImage = UIImage(systemName: "play.fill", withConfiguration: config)
        let pauseImage = UIImage(systemName: "pause.fill", withConfiguration: config)
        tempBtn.setImage(playImage, for: .normal)
        tempBtn.setImage(pauseImage, for: .selected)
        tempBtn.tintColor = .white
        return tempBtn
    }()
    
    private lazy var playerLayer: AVPlayerLayer = {
        let playerLayer = AVPlayerLayer()
        return playerLayer
    }()
    
    lazy var enterFullBtn: UIButton = {
        let tempBtn = UIButton()
        tempBtn.setImage(UIImage.init(systemName: "arrow.up.left.and.arrow.down.right"), for: .normal)
        tempBtn.tintColor = .white
        tempBtn.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3)
        tempBtn.layer.cornerRadius = 4
        tempBtn.layer.masksToBounds = true
        tempBtn.addTarget(self, action: #selector(enterFullScreen), for: .touchUpInside)
        tempBtn.isHidden = true
        return tempBtn
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .black
        self.setupUI()
        self.setupPlayerLayer()
        self.addRxObserver()
    }
    
    deinit {
        print("LSPlayerViewController deinit")
        //self.tapTimer?.invalidate()
        //self.tapTimer = nil
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.playerLayer.frame = self.view.bounds
    }
    
    private func setupUI() {
        self.controlView.isUserInteractionEnabled = false
        self.view.addSubview(controlView)
        self.view.addSubview(enterFullBtn)
        self.view.addSubview(playAndPauseBtn)
        
        controlView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
            make.height.equalTo(48)
        }
        
        enterFullBtn.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.width.height.equalTo(34)
        }
        
        playAndPauseBtn.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(50)
        }
        
        let tap = UITapGestureRecognizer.init(target: self, action: #selector(tapAction))
        tap.numberOfTouchesRequired = 1
        self.view.addGestureRecognizer(tap)
    }
    
    @objc func tapAction() {
        self.playerManager.tapAction()
    }
    
    private func dismissControl() {
        UIView.animate(withDuration: 0.3) {
            self.playAndPauseBtn.alpha = 0
            self.controlView.alpha = 0
            self.enterFullBtn.alpha = 0
        } completion: { flag in
            self.playAndPauseBtn.isHidden = true
            self.controlView.isHidden = true
            self.enterFullBtn.isHidden = true
        }
    }
    
    private func showControl() {
        self.playAndPauseBtn.isHidden = false
        self.controlView.isHidden = false
        self.enterFullBtn.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.playAndPauseBtn.alpha = 1
            self.controlView.alpha = 1
            self.enterFullBtn.alpha = 1
        }
    }
    private func updateProgress() {
        let duration = self.playerManager.duration.value
        guard duration > 0 else {
            return
        }
        let currentTime = self.playerManager.currentTime.value
        let progress = currentTime / duration
        self.controlView.progress = progress
    }
    
    /// rx监听
    private func addRxObserver() {
        // 监听拖拽开始事件（用于暂停播放）
        self.controlView.progressView.rx.controlEvent([.touchUpInside, .touchUpOutside, .touchCancel])
            .subscribe(onNext: { [weak self] _ in  // 参数是 Void，不是 progress
                guard let self = self else { return }
                let currentProgress = self.controlView.progressView.value
                self.playerManager.setProgress(Double(currentProgress))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                    self.controlView.isPanGesture = false
                    self.playerManager.isDragProgress = false
                    self.playerManager.setNormalDrag()
                })
            })
            .disposed(by: disposeBag)
        
        /// 靠诉manager不要更新time
        self.controlView.progressView.rx.controlEvent([.touchDown])
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                print("touchDown")
                self.controlView.isPanGesture = true
                self.playerManager.isDragProgress = true
            })
            .disposed(by: disposeBag)
        
        // 当前时间
        self.playerManager.currentTime
            .subscribe { [weak self] time in
                guard let `self` = self else { return }
                self.controlView.currentTime = time
                self.updateProgress()
            }.disposed(by: self.disposeBag)
        
        // 总时长
        self.playerManager.duration
            .subscribe { [weak self] time in
                guard let `self` = self else { return }
                self.controlView.totalTime = time
                updateProgress()
            }.disposed(by: self.disposeBag)
        
        self.playerManager.playbackState
            .subscribe(onNext: { [weak self] status in
                guard let self = self else { return }
                switch status {
                case .playing:
                    print("正在播放")
                    self.playAndPauseBtn.isSelected = true
                    // 更新播放按钮为暂停图标
                case .paused:
                    print("已暂停")
                    self.playAndPauseBtn.isSelected = false
                    // 更新播放按钮为播放图标
                case .waitingToPlayAtSpecifiedRate:
                    print("等待播放...")
                    // 可以显示加载动画
                @unknown default:
                    print("未知播放状态")
                }
            })
            .disposed(by: self.disposeBag)
        
        // 播放、暂停事件
        self.playAndPauseBtn.rx.tap.subscribe { [weak self] _ in
            guard let `self` = self else { return }
            let isPlay = self.playerManager.isPlaying.value
            if !isPlay {
                self.playerManager.play()
                self.delegate?.videoPlayerDidStartPlaying(self)
            } else {
                self.playerManager.pause()
                self.delegate?.videoPlayerDidPause(self)
            }
        }.disposed(by: self.disposeBag)
        
        // 倍速按钮
        self.controlView.speedBtn.rx.tap
            .subscribe { [weak self] _ in
                guard let `self` = self else { return }
                self.showSpeedMenuItmes()
            }.disposed(by: self.disposeBag)
        
        // 背景隐藏speed菜单
        self.popBkgView.rx.tap
            .subscribe { [weak self] _ in
                guard let `self` = self else { return }
                self.hideSpeedMenu()
            }.disposed(by: self.disposeBag)
        
        
        // 是否隐藏控制栏
        self.playerManager.controlState
            .subscribe { [weak self] isShow in
                guard let `self` = self else { return }
                if isShow {
                    self.showControl()
                }else{
                    self.dismissControl()
                }
            }.disposed(by: self.disposeBag)
        
        // 播放完成监听
        self.playerManager.playFinishedState
            .subscribe { [weak self] finished in
                guard let `self` = self else { return }
                self.delegate?.videoPlayerDidFinishPlaying(self)
            }.disposed(by: self.disposeBag)
    }
    
    /// 设置playerLayer
    private func setupPlayerLayer() {
        playerLayer.frame = self.view.bounds
        playerLayer.backgroundColor = UIColor.black.cgColor
        
        self.view.layer.insertSublayer(playerLayer, at: 0)
    }
    
    
    
    /// 加载数据
    //    public func loadVideoData(url: URL) {
    //        self.playerManager.loadVideo(url)
    //            .subscribe(onSuccess: { [weak self] player in
    //                guard let `self` = self else { return }
    //                self.playerLayer.player = player
    //                self.playerManager.play()
    //                self.enterFullBtn.isHidden = false
    //                self.controlView.isUserInteractionEnabled = true
    //                self.tapAction()
    //            }, onFailure: { error in
    //                print("视频加载失败: \(error)")
    //            })
    //            .disposed(by: disposeBag)
    //    }
    
    /// 新方法：加载视频、字幕和封面
    public func loadVideo(from videoURL: URL,
                          withSubtitle subtitleURL: URL? = nil,
                          coverImgUrlStr: String? = nil,
                          completed: @escaping () -> Void) {
        
        // 1. 如果有封面图片URL，先加载封面
        if let coverUrlStr = coverImgUrlStr, let coverURL = URL(string: coverUrlStr) {
            loadCoverImage(from: coverURL)
        }
        
        // 2. 加载视频和字幕
        self.playerManager.loadVideo(videoURL, subtitleURL: subtitleURL)
            .subscribe(onSuccess: { [weak self] player in
                guard let self = self else { return }
                
                // 设置播放器
                self.playerLayer.player = player
                
                // 隐藏封面图片
                self.hideCoverImage()
                
                // 开始播放
                self.playerManager.play()
                self.delegate?.videoPlayerDidStartPlaying(self)
                
                // 更新UI
                self.enterFullBtn.isHidden = false
                self.controlView.isUserInteractionEnabled = true
                self.tapAction()
                
                // 回调完成
                completed()
                
            }, onFailure: { error in
                print("视频加载失败: \(error)")
                completed()
            })
            .disposed(by: disposeBag)
    }
    
    /// 进入全屏
    @objc private func enterFullScreen() {
        let vc = LSFullPlayerViewController(manager: self.playerManager, originFrame: self.view.frame)
        vc.modalPresentationStyle = .custom
        vc.delegate = self
        self.present(vc, animated: false) {
            self.playerLayer.isHidden = true
        }
    }
    
    
    /// 加载封面图片
    private func loadCoverImage(from url: URL) {
        // 创建封面图片视图
        let coverImageView = UIImageView()
        coverImageView.contentMode = .scaleAspectFill
        coverImageView.backgroundColor = .black
        coverImageView.clipsToBounds = true
        coverImageView.frame = self.view.bounds
        coverImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // 添加到视图层级
        self.view.insertSubview(coverImageView, belowSubview: playAndPauseBtn)
        self.coverImageView = coverImageView
        
        // 加载图片
        DispatchQueue.global().async {
            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    coverImageView.image = image
                }
            }
        }
    }
    
    /// 隐藏封面图片
    private func hideCoverImage() {
        UIView.animate(withDuration: 0.3, animations: {
            self.coverImageView?.alpha = 0
        }) { _ in
            self.coverImageView?.removeFromSuperview()
            self.coverImageView = nil
        }
    }
    
}

extension LSPlayerViewController: LSFullPlayerViewControllerDelegate {
    func didExitFullScreen() {
        self.playerLayer.isHidden = false
    }
}


extension LSPlayerViewController: UIGestureRecognizerDelegate {
    /// 倍速菜单
    private func showSpeedMenuItmes() {
        if !self.playerManager.isFullScreen.value {
            self.showSpeedMenu()
        }
    }
    
    @objc private func showSpeedMenu() {
        let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        let currentSpeed: Float = self.playerManager.player.rate
        popBkgView.removeFromSuperview()
        popBkgView.frame = CGRect.init(x: 0, y: 0, width: kScreenWidth, height: kScreenHeight)
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let keyScene = windowScene?.windows.first { $0.isKeyWindow }
        keyScene?.addSubview(popBkgView)
        // self.view.addSubview(popBkgView)
        
        // 创建菜单
        let menuView = SpeedMenuView(speeds: speeds, currentSpeed: currentSpeed)
        menuView.alpha = 0
        menuView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        popBkgView.addSubview(menuView)
        
        // 计算位置（在按钮上方居中）
        let menuWidth: CGFloat = 140
        let menuHeight: CGFloat = CGFloat(speeds.count) * 44
        
        // 将按钮位置转换到 view 坐标系
        let buttonFrameInView = self.controlView.speedBtn.convert(self.controlView.speedBtn.bounds, to: popBkgView)
        
        // 计算菜单位置
        let menuX = buttonFrameInView.midX - menuWidth + 20
        var menuY = buttonFrameInView.minY + 60
        // 确保不会超出屏幕顶部
        let minY = view.safeAreaInsets.top + 16
        menuY = max(minY, menuY)
        
        menuView.frame = CGRect(x: menuX, y: menuY, width: menuWidth, height: menuHeight)
        // 处理速度选择
        menuView.onSpeedSelected = { [weak self] speed in
            self?.playerManager.setPlaybackRate(speed: speed)
            self?.hideSpeedMenu()
        }
        
        // 动画显示
        UIView.animate(withDuration: 0.2) {
            menuView.alpha = 1
            menuView.transform = .identity
        }
        // 保存引用
        self.speedMenuView = menuView
    }
    
    @objc private func hideSpeedMenu() {
        guard let menuView = speedMenuView else { return }
        popBkgView.removeFromSuperview()
        UIView.animate(withDuration: 0.2) {
            menuView.alpha = 0
            menuView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        } completion: { _ in
            menuView.removeFromSuperview()
            self.speedMenuView = nil
        }
    }
}


extension LSPlayerViewController {
    
}
