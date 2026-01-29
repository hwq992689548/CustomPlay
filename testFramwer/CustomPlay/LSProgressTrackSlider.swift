//
//  LSProgressTrackSlider.swift
//  testFramwer
//
//  Created by feixiang huang on 2026/1/28.
//

import UIKit
import SnapKit
import RxSwift
import RxCocoa

class LSProgressTrackSlider: UIView {
    // MARK: - Properties
    private let progressView = UIProgressView(progressViewStyle: .default)
    let slider = UISlider()
    private let disposeBag = DisposeBag()
    
    // 暴露可观察的属性
    var value: Float {
        get { return slider.value }
        set {
            slider.value = newValue
            syncProgressWithSliderValue(newValue)
        }
    }
    
    var progress: Float {
        get { return progressView.progress }
        set {
            let displayProgress = max(newValue, minVisibleProgress)
            progressView.progress = displayProgress
        }
    }
    
    var minimumValue: Float {
        get { return slider.minimumValue }
        set { slider.minimumValue = newValue }
    }
    
    var maximumValue: Float {
        get { return slider.maximumValue }
        set { slider.maximumValue = newValue }
    }
    
    var trackHeight: CGFloat = 8 {
        didSet {
            updateTrackHeight()
        }
    }
    
    var progressTintColor: UIColor? {
        get { return progressView.progressTintColor }
        set { progressView.progressTintColor = newValue }
    }
    
    var trackTintColor: UIColor? {
        get { return progressView.trackTintColor }
        set { progressView.trackTintColor = newValue }
    }
    
    // 最小可见进度
    private let minVisibleProgress: Float = 0.01
    
    // MARK: - Rx Observables
    var rxValue: ControlProperty<Float> {
        return slider.rx.value
    }
    
    // MARK: - Initialization
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupBindings()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupBindings()
    }
    
    // MARK: - Setup
    private func setupUI() {
        // 设置 ProgressView
        progressView.progressTintColor = .white.withAlphaComponent(0.7)
        progressView.trackTintColor = .gray.withAlphaComponent(0.6)
        progressView.progress = 0
        progressView.layer.cornerRadius = 4
        progressView.clipsToBounds = true
        addSubview(progressView)
        
        // 设置 Slider
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.value = 0
        
        // 透明轨道
        slider.minimumTrackTintColor = .clear
        slider.maximumTrackTintColor = .clear
        
        // 设置滑块
        let thumbImage = UIImage()
        slider.setThumbImage(thumbImage, for: .normal)
        
        // 增加滑块触摸区域
        let largeThumbImage = createThumbImage(size: 24, alpha: 0.1)
        slider.setThumbImage(largeThumbImage, for: .highlighted)
        
        addSubview(slider)
        
        // 使用 SnapKit 布局
        progressView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.height.equalTo(trackHeight)
        }
        
        slider.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
    
    private func setupBindings() {
        // 监听 slider 值变化，同步到 progressView
        slider.rx.value
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] value in
                self?.syncProgressWithSliderValue(value)
            })
            .disposed(by: disposeBag)
        
        // 监听触摸事件
        slider.rx.controlEvent(.touchDown)
            .subscribe(onNext: { [weak self] in
                self?.onSliderTouchDown()
            })
            .disposed(by: disposeBag)
        
        slider.rx.controlEvent([.touchUpInside, .touchUpOutside])
            .subscribe(onNext: { [weak self] in
                self?.onSliderTouchUp()
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Private Methods
    private func updateTrackHeight() {
        progressView.snp.updateConstraints { make in
            make.height.equalTo(trackHeight)
        }
        
        // 更新圆角
        progressView.layer.cornerRadius = trackHeight / 2
    }
    
    private func createThumbImage(size: CGFloat, alpha: CGFloat = 1.0) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            let path = UIBezierPath(ovalIn: rect)
            
            if alpha < 1.0 {
                // 透明的大滑块，用于扩大触摸区域
                UIColor.white.withAlphaComponent(alpha).setFill()
                path.fill()
            } else {
                // 正常显示的小滑块
                UIColor.white.setFill()
                path.fill()
                
                // 添加白色边框
                UIColor.white.setStroke()
                path.lineWidth = 1.5
                path.stroke()
                
                // 添加内部填充
                let innerRect = rect.insetBy(dx: 2, dy: 2)
                let innerPath = UIBezierPath(ovalIn: innerRect)
                UIColor.lightGray.withAlphaComponent(0.7).setFill()
                innerPath.fill()
            }
        }
    }
    
    private func syncProgressWithSliderValue(_ value: Float) {
        // 确保最小显示进度
        let displayProgress = max(value, minVisibleProgress)
        progressView.progress = displayProgress
    }
    
    private func onSliderTouchDown() {
        // 用户开始拖动时，保持进度显示
        print("Slider touch down")
    }
    
    private func onSliderTouchUp() {
        // 用户结束拖动时，如果值很小，确保显示最小进度
        if slider.value < minVisibleProgress {
            progressView.progress = minVisibleProgress
        }
        print("Slider touch up")
    }
    
    // MARK: - Public Methods
    func setProgress(_ progress: Float, animated: Bool) {
        // 更新进度显示，但不改变 slider 的 value（避免触发拖动事件）
        let displayProgress = max(progress, minVisibleProgress)
        progressView.setProgress(displayProgress, animated: animated)
    }
    
    func setValue(_ value: Float, animated: Bool) {
        if animated {
            UIView.animate(withDuration: 0.3) {
                self.slider.value = value
                self.syncProgressWithSliderValue(value)
            }
        } else {
            slider.value = value
            syncProgressWithSliderValue(value)
        }
    }
    
    // 只更新显示，不触发事件
    func updateDisplayOnly(_ progress: Float, animated: Bool = true) {
        let displayProgress = max(progress, minVisibleProgress)
        progressView.setProgress(displayProgress, animated: animated)
    }
    
    func reset() {
        slider.value = 0
        progressView.progress = 0
    }
}

// MARK: - Extension for RxSwift
extension Reactive where Base: LSProgressTrackSlider {
    var value: ControlProperty<Float> {
        return base.rxValue
    }
    
    var progress: Binder<Float> {
        return Binder(base) { slider, progress in
            slider.updateDisplayOnly(progress, animated: true)
        }
    }
}
