//
//  LSPlayManager.swift
//  testPro
//
//  Created by feixiang huang on 2026/1/27.
//

import UIKit
import AVFoundation
import RxSwift
import RxCocoa

// 定义错误类型
enum VideoError: Error {
    case invalidDuration
    case cancelled
    case unknown
}
class LSPlayManager: NSObject {
    /// 播放player
    public var player: AVPlayer = AVPlayer()
    /// 用来获取plyer的播放时长以及当前时间
    private var timeObserverToken: Any?
    private let disposeBag = DisposeBag()
    
    /// 默认1倍速度播放
    var speed: CGFloat = 1
    
    /// 监听
    let currentTime = BehaviorRelay<Double>(value: 0)
    let duration = BehaviorRelay<Double>(value: 0)
    let isPlaying = BehaviorRelay<Bool>(value: false)
    let isFullScreen = BehaviorRelay<Bool>(value: false)
    let playbackState = PublishRelay<AVPlayer.TimeControlStatus>()
    let playFinishedState = PublishRelay<Bool>()

    /// 显示控件状态的定时器
    private var tapTimer: Timer?
    /// 控件隐藏-显示
    let controlState = BehaviorRelay<Bool>(value: false)
    private var controlIsShow: Bool = true
    
    /// 加载video数据
//    func loadVideo(_ url: URL, subtitleURL: URL?) -> Single<AVPlayer> {
//        return Single.create { single in
//            let asset = AVAsset(url: url)
//            let keysToLoad = ["duration", "playable"]
//            
//            asset.loadValuesAsynchronously(forKeys: keysToLoad) {
//                var durationError: NSError?
//                let durationStatus = asset.statusOfValue(forKey: "duration", error: &durationError)
//                
//                DispatchQueue.main.async {
//                    switch durationStatus {
//                    case .loaded:
//                        // 检查视频时长是否有效
//                        let totalSeconds = asset.duration.seconds
//                        guard totalSeconds > 0, !totalSeconds.isNaN, !totalSeconds.isInfinite else {
//                            //single(.error(VideoError.invalidDuration))
//                            single(.failure(VideoError.invalidDuration))
//                            return
//                        }
//                        
//                        // 更新duration（假设这是类的一个属性）
//                        self.duration.accept(totalSeconds)
//                        
//                        // 创建playerItem并设置
//                        let playerItem = AVPlayerItem(asset: asset)
//                        self.player.replaceCurrentItem(with: playerItem)
//                        self.player.externalPlaybackVideoGravity = .resizeAspect
//                        self.setupObservers()
//                        self.setupNotifications()
//                        
//                        // 发出成功事件
//                        single(.success(self.player))
//                        
//                    case .failed:
//                        let error = durationError ?? NSError(
//                            domain: "VideoLoader",
//                            code: -1,
//                            userInfo: [NSLocalizedDescriptionKey: "加载视频元数据失败"]
//                        )
//                        single(.failure(error))
//                    case .cancelled:
//                        single(.failure(VideoError.cancelled))
//                        
//                    default:
//                        // 处理其他状态
//                        single(.failure(VideoError.unknown))
//                    }
//                }
//            }
//            
//            // 返回Disposable，处理取消
//            return Disposables.create {
//                asset.cancelLoading()
//            }
//        }
//    }
//
    /// 加载video数据
    func loadVideo(_ url: URL, subtitleURL: URL? = nil) -> Single<AVPlayer> {
        return Single.create { [weak self] single in
            guard let self = self else {
                single(.failure(VideoError.unknown))
                return Disposables.create()
            }
            
            let asset = AVAsset(url: url)
            let keysToLoad = ["duration", "playable"]
            
            asset.loadValuesAsynchronously(forKeys: keysToLoad) { [weak self] in
                var durationError: NSError?
                let durationStatus = asset.statusOfValue(forKey: "duration", error: &durationError)
                
                DispatchQueue.main.async {
                    guard let self = self else {
                        single(.failure(VideoError.unknown))
                        return
                    }
                    
                    switch durationStatus {
                    case .loaded:
                        // 检查视频时长是否有效
                        let totalSeconds = asset.duration.seconds
                        guard totalSeconds > 0, !totalSeconds.isNaN, !totalSeconds.isInfinite else {
                            single(.failure(VideoError.invalidDuration))
                            return
                        }
                        
                        // 更新duration
                        self.duration.accept(totalSeconds)
                        
                        // 创建播放器项目
                        let playerItem: AVPlayerItem
                        
                        if let subtitleURL = subtitleURL {
                            // 如果有字幕，尝试加载字幕
                            playerItem = self.createPlayerItemWithSubtitle(videoAsset: asset, subtitleURL: subtitleURL)
                        } else {
                            // 没有字幕，直接创建普通播放器项目
                            playerItem = AVPlayerItem(asset: asset)
                        }
                        
                        // 设置播放器
                        self.player.replaceCurrentItem(with: playerItem)
                        self.player.externalPlaybackVideoGravity = .resizeAspect
                        self.setupObservers()
                        self.setupNotifications()
                        
                        // 发出成功事件
                        single(.success(self.player))
                        
                    case .failed:
                        let error = durationError ?? NSError(
                            domain: "VideoLoader",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "加载视频元数据失败"]
                        )
                        single(.failure(error))
                    case .cancelled:
                        single(.failure(VideoError.cancelled))
                        
                    default:
                        single(.failure(VideoError.unknown))
                    }
                }
            }
            
            // 返回Disposable，处理取消
            return Disposables.create {
                asset.cancelLoading()
            }
        }
    }

    /// 创建带字幕的播放器项目
    private func createPlayerItemWithSubtitle(videoAsset: AVAsset, subtitleURL: URL) -> AVPlayerItem {
        // 方法1: 使用AVMutableComposition组合视频和字幕
        let composition = AVMutableComposition()
        let videoDuration = videoAsset.duration
        
        do {
            // 添加视频轨道
            if let videoTrack = videoAsset.tracks(withMediaType: .video).first {
                let compositionVideoTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
                try compositionVideoTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: videoDuration),
                    of: videoTrack,
                    at: .zero
                )
                
                // 保留原始变换
                compositionVideoTrack?.preferredTransform = videoTrack.preferredTransform
            }
            
            // 添加音频轨道
            if let audioTrack = videoAsset.tracks(withMediaType: .audio).first {
                let compositionAudioTrack = composition.addMutableTrack(
                    withMediaType: .audio,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
                try compositionAudioTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: videoDuration),
                    of: audioTrack,
                    at: .zero
                )
            }
            
            // 添加字幕轨道（如果字幕是有效的视频格式）
            let subtitleAsset = AVAsset(url: subtitleURL)
            let subtitleTracks = subtitleAsset.tracks(withMediaType: .text) + subtitleAsset.tracks(withMediaCharacteristic: .legible)
            
            if let subtitleTrack = subtitleTracks.first {
                let compositionSubtitleTrack = composition.addMutableTrack(
                    withMediaType: .text,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                )
                try compositionSubtitleTrack?.insertTimeRange(
                    CMTimeRange(start: .zero, duration: videoDuration),
                    of: subtitleTrack,
                    at: .zero
                )
            } else {
                // 如果字幕不是标准格式，使用外部关联方式
                print("字幕不是标准格式，使用外部关联")
            }
            
            return AVPlayerItem(asset: composition)
            
        } catch {
            print("添加字幕轨道失败: \(error)")
            // 如果组合失败，返回普通播放器项目
            return AVPlayerItem(asset: videoAsset)
        }
    }
    
    /// 设置倍速
    public func setPlaybackRate(speed: CGFloat) {
        let currentTime = player.currentTime()
        let wasPlaying = self.isPlaying.value
        // 选暂停
        player.pause()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let `self` = self else { return }
            // 使用 playImmediately(atRate:) 设置倍速
            //self.player.playImmediately(atRate: Float(speed))
            // 确保时间准确
            self.player.seek(to: currentTime, toleranceBefore: .zero, toleranceAfter: .zero)
            self.speed = speed
            if wasPlaying {
                self.play()
            }
            print("✅ 成功应用倍速播放: \(speed)x (playImmediately)")
        }
        
    }
    
    /// 添加监听
    private func setupObservers() {
        // 播放状态观察
        player.rx.observe(AVPlayer.TimeControlStatus.self, "timeControlStatus")
            .compactMap { $0 }
            .bind(to: playbackState)
            .disposed(by: disposeBag)
        
        // 当前时间观察
        let interval = CMTime(seconds: 0.5, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            let currentSeconds = time.seconds
            self.currentTime.accept(currentSeconds)
            
            if let duration = self.player.currentItem?.duration, duration.isValid {
                self.duration.accept(duration.seconds)
            }
        }
    }
    
    
    private func setupNotifications() {
        // 动移除后，再添加，防止添加多次
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerDidFinishPlaying),
            name: .AVPlayerItemDidPlayToEndTime,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }
    
    @objc private func playerDidFinishPlaying() {
        self.pause()
        player.seek(to: CMTime.zero)
        playFinishedState.accept(true)
    }
    
    @objc private func applicationWillResignActive() {
        if self.isPlaying.value {
            self.play()
        }
    }
    
    /// 播放
    func play() {
        player.playImmediately(atRate: Float(speed))
        isPlaying.accept(true)
    }
    
    /// 暂停
    func pause() {
        player.pause()
        isPlaying.accept(false)
    }
    
    /// 跳转到播放时间
    func seek(to time: Double) {
        let time = CMTime(seconds: time, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
        player.seek(to: time)
    }
    
    // MARK: - Cleanup
    deinit {
        if self.tapTimer != nil {
            self.tapTimer?.invalidate()
            self.tapTimer = nil
        }
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        player.pause()
    }
    
    /// 是否显示控件逻辑
    public func tapAction() {
        if let time = self.tapTimer {
            time.invalidate()
        }
        
        if self.controlIsShow {
            self.controlIsShow = false
            controlState.accept(self.controlIsShow)
            return
        }
        
        self.controlIsShow = true
        controlState.accept(self.controlIsShow)
        tapTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false, block: { [weak self] pTime in
            guard let `self` = self else { return }
            self.controlIsShow = false
            controlState.accept(self.controlIsShow)
        })
    }
    
}
