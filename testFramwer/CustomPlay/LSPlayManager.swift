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
    // MARK: - Properties
    public var player: AVPlayer = AVPlayer()
    private var timeObserverToken: Any?
    private let disposeBag = DisposeBag()
    
    var speed: CGFloat = 1
    
    // MARK: - Observables
    let currentTime = BehaviorRelay<Double>(value: 0)
    let duration = BehaviorRelay<Double>(value: 0)
    let isPlaying = BehaviorRelay<Bool>(value: false)
    let isFullScreen = BehaviorRelay<Bool>(value: false)
    let playbackState = PublishRelay<AVPlayer.TimeControlStatus>()
    
    
    /// 加载video数据
    func loadVideo(_ url: URL) -> Single<AVPlayer> {
        return Single.create { single in
            let asset = AVAsset(url: url)
            let keysToLoad = ["duration", "playable"]
            
            asset.loadValuesAsynchronously(forKeys: keysToLoad) {
                var durationError: NSError?
                let durationStatus = asset.statusOfValue(forKey: "duration", error: &durationError)
                
                DispatchQueue.main.async {
                    switch durationStatus {
                    case .loaded:
                        // 检查视频时长是否有效
                        let totalSeconds = asset.duration.seconds
                        guard totalSeconds > 0, !totalSeconds.isNaN, !totalSeconds.isInfinite else {
                            //single(.error(VideoError.invalidDuration))
                            single(.failure(VideoError.invalidDuration))
                            return
                        }
                        
                        // 更新duration（假设这是类的一个属性）
                        self.duration.accept(totalSeconds)
                        
                        // 创建playerItem并设置
                        let playerItem = AVPlayerItem(asset: asset)
                        self.player.replaceCurrentItem(with: playerItem)
                        self.player.externalPlaybackVideoGravity = .resizeAspect
                        self.setupObservers()
                        
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
                        // 处理其他状态
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
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
        player.pause()
    }
    
}
