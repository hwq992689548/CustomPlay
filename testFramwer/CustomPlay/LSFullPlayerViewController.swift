//
//  LSFullPlayerViewController.swift
//  testFramwer
//
//  Created by feixiang on 2026/1/27.
//

import UIKit
import AVFoundation
import RxSwift
import RxCocoa
import SnapKit

protocol LSFullPlayerViewControllerDelegate: NSObject {
    func didExitFullScreen()
}

class LSFullPlayerViewController: UIViewController {
    weak var delegate: LSFullPlayerViewControllerDelegate?
    
    /// 弹出倍速菜单背景整个屏幕
    private lazy var popBkgView: UIButton = {
        let tempView = UIButton()
        tempView.frame = CGRect.init(x: 0, y: 0, width: kScreenWidth, height: kScreenHeight)
        tempView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.1)
        return tempView
        
    }()
    
    private lazy var bkgView: UIButton = {
        let tempView = UIButton()
        tempView.frame = CGRect.init(x: 0, y: 0, width: kScreenWidth, height: kScreenHeight)
        tempView.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0)
        tempView.addTarget(self, action: #selector(tapAction), for: .touchUpInside)
        return tempView
    }()

    private var speedMenuView: SpeedMenuView?
    private var fullScreenPlayerLayer: AVPlayerLayer
    private var disposeBag = DisposeBag()
    private var animationContainer = UIView()
    private var originFrame: CGRect = .zero
    private var toFrame: CGRect = .zero
    private var timeObserver: Any?
    private var playerManager: LSPlayManager
    lazy var closeBtn: UIButton = {
        let btn = UIButton()
        btn.setImage(UIImage.init(systemName: "arrow.down.right.and.arrow.up.left"), for: .normal)
        btn.tintColor = .white
        btn.backgroundColor = .clear
        btn.addTarget(self, action: #selector(exitFullScreen), for: .touchUpInside)
        return btn
    }()
    
    private let fullScreenControlView: LSPlayControllerView = {
        let controlView = LSPlayControllerView()
        controlView.updateFullScreenState(true)
        controlView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        controlView.alpha = 0 // 初始隐藏
        return controlView
    }()
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.black
        self.view.addSubview(animationContainer)
        self.setupUI()
    }
    
    public init(manager: LSPlayManager, originFrame: CGRect) {
        self.originFrame = originFrame
        self.playerManager = manager
        fullScreenPlayerLayer = AVPlayerLayer(player: manager.player)
        fullScreenPlayerLayer.frame = originFrame
        super.init(nibName: nil, bundle: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.enterFullScreen()
    }
    
    /// rx监听
    private func addRxObserver() {
        // 监听拖拽开始事件（用于暂停播放）
        self.fullScreenControlView.progressView.slider.rx.controlEvent([.touchUpInside, .touchUpOutside, .touchCancel])
            .subscribe(onNext: { [weak self] _ in  // 参数是 Void，不是 progress
                guard let self = self else { return }
                let currentProgress = self.fullScreenControlView.progressView.value
                self.playerManager.setProgress(Double(currentProgress))
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
                    self.fullScreenControlView.isPanGesture = false
                    self.playerManager.isDragProgress = false
                    self.playerManager.setNormalDrag()
                })
            })
            .disposed(by: disposeBag)
        
        /// 靠诉manager不要更新time
        self.fullScreenControlView.progressView.slider.rx.controlEvent([.touchDown])
            .subscribe(onNext: { [weak self] _ in
                guard let self = self else { return }
                self.fullScreenControlView.isPanGesture = true
                self.playerManager.isDragProgress = true
            })
            .disposed(by: disposeBag)
        
        // 当前时间
        self.playerManager.currentTime
            .subscribe { [weak self] time in
                guard let `self` = self else { return }
                self.fullScreenControlView.currentTime = time
                self.updateProgress()
            }.disposed(by: self.disposeBag)
        
        // 总时长
        self.playerManager.duration
            .subscribe { [weak self] time in
                guard let `self` = self else { return }
                self.fullScreenControlView.totalTime = time
                self.updateProgress()
            }.disposed(by: self.disposeBag)
        
        // 播放状态监听
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
        
        // 播放\暂停
        self.playAndPauseBtn.rx.tap.subscribe { [weak self] _ in
            guard let `self` = self else { return }
            let isPlay = self.playerManager.isPlaying.value
            if !isPlay {
                self.playerManager.play()
            } else {
                self.playerManager.pause()
            }
        }.disposed(by: self.disposeBag)
        
        // 倍速按钮
        self.fullScreenControlView.speedBtn.rx.tap
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
        
    }
    
    /// 更新进度
    private func updateProgress() {
        let duration = self.playerManager.duration.value
        guard duration > 0 else {
            return
        }
        let currentTime = self.playerManager.currentTime.value
        let progress = currentTime / duration
        self.fullScreenControlView.progress = progress
    }
    
    private func setupUI() {
        view.addSubview(bkgView)
        view.addSubview(closeBtn)
        view.addSubview(playAndPauseBtn)
        closeBtn.snp.makeConstraints { make in
            make.leading.equalToSuperview()
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.width.height.equalTo(40)
        }
        
        bkgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    @objc func tapAction() {
        self.playerManager.tapAction()
    }
    
    
    private func dismissControl() {
        UIView.animate(withDuration: 0.3) {
            self.playAndPauseBtn.alpha = 0
            self.fullScreenControlView.alpha = 0
            self.closeBtn.alpha = 0
        } completion: { flag in
            self.playAndPauseBtn.isHidden = true
            self.fullScreenControlView.isHidden = true
            self.closeBtn.isHidden = true
        }
    }
    
    private func showControl() {
        self.playAndPauseBtn.isHidden = false
        self.fullScreenControlView.isHidden = false
        self.closeBtn.isHidden = false
        UIView.animate(withDuration: 0.3) {
            self.playAndPauseBtn.alpha = 1
            self.fullScreenControlView.alpha = 1
            self.closeBtn.alpha = 1
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func enterFullScreen() {
        guard originFrame.width > 0, originFrame.height > 0 else {
            return
        }
        animationContainer.removeFromSuperview()
        animationContainer = UIView(frame: originFrame)
        animationContainer.clipsToBounds = true
        animationContainer.layer.insertSublayer(fullScreenPlayerLayer, at: 0)
        view.insertSubview(animationContainer, at: 0)
        // 初始设置 layer frame
        fullScreenPlayerLayer.frame = animationContainer.bounds
        
        // 计算目标 frame
        let screenWidth = view.bounds.width
        let originalAspectRatio = originFrame.width / originFrame.height
        let targetWidth = screenWidth
        let targetHeight = targetWidth / originalAspectRatio
        let targetY = (view.bounds.height - targetHeight) / 2
        let targetFrame = CGRect(x: 0, y: targetY, width: targetWidth, height: targetHeight)
        
        // 关键：使用 animateKeyframes 精确控制 layer 动画
        UIView.animateKeyframes(withDuration: 0.3, delay: 0, options: [.calculationModeCubic]) {
            // 添加关键帧：在动画过程中同步更新 layer
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 1.0) {
                self.animationContainer.frame = targetFrame
                // 强制 layer 同步更新 frame
                CATransaction.begin()
                CATransaction.setDisableActions(false) // 允许隐式动画
                self.fullScreenPlayerLayer.frame = self.animationContainer.bounds
                CATransaction.commit()
            }
        } completion: { _ in
            print("✅ FullScreen动画完成")
            self.playerManager.isFullScreen.accept(true)
            self.setupFullScreenControls()
            self.addRxObserver()
            self.tapAction()
            if self.playerManager.isPlaying.value {
                self.playAndPauseBtn.isSelected = true
            }
        }
    }
    
    private func setupFullScreenControls() {
        // 创建全屏控制视图
        fullScreenControlView.updateFullScreenState(true)
        fullScreenControlView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        fullScreenControlView.alpha = 0 // 初始隐藏
        view.addSubview(fullScreenControlView)
        view.addSubview(playAndPauseBtn)
        
        playAndPauseBtn.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(40)
        }
        
        closeBtn.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.width.height.equalTo(40)
        }
        
        fullScreenControlView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview().offset(-40) // 为Home Indicator留出空间
            make.height.equalTo(60)
        }
        
        playAndPauseBtn.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.height.equalTo(40)
        }
        
        // 绑定事件
        fullScreenControlView.playRelay
            .subscribe(onNext: { [weak self] shouldPlay in
                self?.handlePlayPause(shouldPlay)
            })
            .disposed(by: disposeBag)
        
        fullScreenControlView.fullScreenRelay
            .subscribe(onNext: { [weak self] _ in
                self?.exitFullScreen()
            })
            .disposed(by: disposeBag)
        
        // 显示控制视图
        UIView.animate(withDuration: 0.3) {
            self.fullScreenControlView.alpha = 1
        }
    }
    
    private func handlePlayPause(_ shouldPlay: Bool) {
        
    }
    
    /// 退出全屏
    @objc private func exitFullScreen() {
        // 隐藏全屏控件
        hideFullScreenControls()
        let originalFrame = self.originFrame
        // 使用关键帧动画返回
        self.view.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 1)
        UIView.animateKeyframes(withDuration: 0.3, delay: 0, options: [.calculationModeCubic]) {
            self.view.backgroundColor = UIColor.init(red: 0, green: 0, blue: 0, alpha: 0.3)
            UIView.addKeyframe(withRelativeStartTime: 0.0, relativeDuration: 1.0) {
                // 动画回到原始位置和大小
                self.animationContainer.frame = originalFrame
                // 同步更新 player layer
                CATransaction.begin()
                CATransaction.setDisableActions(false)
                self.fullScreenPlayerLayer.frame = self.animationContainer.bounds
                CATransaction.commit()
            }
        } completion: { _ in
            // 动画完成后，将 player layer 放回原来的位置
            self.playerManager.isFullScreen.accept(false)
            self.animationContainer.removeFromSuperview()
            self.fullScreenPlayerLayer.removeFromSuperlayer()
            self.dismiss(animated: false) {
                self.delegate?.didExitFullScreen()
            }
        }
    }
    
    private func hideFullScreenControls() {
        self.playAndPauseBtn.removeFromSuperview()
        self.fullScreenControlView.alpha = 0
    }
    
    private func cleanupFullScreen() {
        // 显示原视图
        self.dismiss(animated: false) {
            self.delegate?.didExitFullScreen()
        }
    }
}


extension LSFullPlayerViewController {
    
    private func showSpeedMenuItmes() {
        if self.playerManager.isFullScreen.value {
            self.showSpeedMenu()
        }
    }
    
    @objc private func showSpeedMenu() {
        let speeds: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]
        let currentSpeed: Float = self.playerManager.player.rate
        popBkgView.removeFromSuperview()
        popBkgView.frame = CGRect.init(x: 0, y: 0, width: kScreenWidth, height: kScreenHeight)
        view.addSubview(popBkgView)
        
        // 创建菜单
        let menuView = SpeedMenuView(speeds: speeds, currentSpeed: currentSpeed)
        menuView.alpha = 0
        menuView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        popBkgView.addSubview(menuView)
        
        // 计算位置（在按钮上方居中）
        let menuWidth: CGFloat = 140
        let menuHeight: CGFloat = CGFloat(speeds.count) * 44
        
        // 将按钮位置转换到 view 坐标系
        let buttonFrameInView = self.fullScreenControlView.speedBtn.convert(self.fullScreenControlView.speedBtn.bounds, to: popBkgView)
        
        // 计算菜单位置
        let menuX = buttonFrameInView.midX - menuWidth + 10
        var menuY = buttonFrameInView.minY - menuHeight - 20
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
