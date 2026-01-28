//
//  LSControllerView.swift
//  testFramwer
//
//  Created by feixiang on 2026/1/27.
//

import UIKit
import RxSwift
import RxCocoa
import SnapKit

class LSPlayControllerView: UIView {
    
    // MARK: - Properties
    var disposeBag = DisposeBag()
    
    // MARK: - Relays
    let playRelay = PublishRelay<Bool>()
    let fullScreenRelay = PublishRelay<Bool>()
    
    // MARK: - UI Components
    private lazy var progressView: UIProgressView = {
        let progress = UIProgressView()
        progress.backgroundColor = .clear
        progress.progressTintColor = .white
        progress.trackTintColor = .gray
        return progress
    }()
    
    private lazy var currentTimeLab: UILabel = {
        let tempLab = UILabel()
        tempLab.text = "00:00 "
        tempLab.textColor = .white
        tempLab.font = UIFont.systemFont(ofSize: 14)
        return tempLab
    }()
    
    private lazy var totalTimeLab: UILabel = {
        let tempLab = UILabel()
        tempLab.text = " / 00:00"
        tempLab.textColor = .white
        tempLab.font = UIFont.systemFont(ofSize: 14)
        return tempLab
    }()
    
    //    lazy var playAndPauseBtn: UIButton = {
    //        let tempBtn = UIButton()
    //        tempBtn.setImage(UIImage(systemName: "play.fill"), for: .normal)
    //        tempBtn.setImage(UIImage(systemName: "pause.fill"), for: .selected)
    //        tempBtn.tintColor = .white
    //        return tempBtn
    //    }()
    
    lazy var speedBtn: UIButton = {
        let tempBtn = UIButton()
        tempBtn.setImage(UIImage.init(systemName: "speedometer"), for: .normal)
        tempBtn.tintColor = .white
        return tempBtn
    }()
    
    // MARK: - Public Properties
    var progress: Double = 0 {
        didSet {
            progressView.progress = Float(progress)
        }
    }
    
    var currentTime: Double = 0 {
        didSet {
            currentTimeLab.text = formatTime(currentTime)
            
        }
    }
    
    var totalTime: Double = 0 {
        didSet {
            totalTimeLab.text = " / \(formatTime(totalTime))"
        }
    }
    
    // MARK: - Lifecycle
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        bindActions()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    
    
    // MARK: - Setup
    private func setupUI() {
        backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.4)
        
        //  addSubview(playAndPauseBtn)
        addSubview(progressView)
        addSubview(currentTimeLab)
        addSubview(totalTimeLab)
        addSubview(speedBtn)
        //        addSubview(fullBtn)
        setupConstraints()
    }
    
    private func setupConstraints() {
        progressView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalToSuperview()
            make.height.equalTo(4)
        }
        
        //        playAndPauseBtn.snp.makeConstraints { make in
        //            make.leading.equalToSuperview().offset(8)
        //            make.centerY.equalToSuperview()
        //            make.width.height.equalTo(30)
        //        }
        
        currentTimeLab.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview()
        }
        
        totalTimeLab.snp.makeConstraints { make in
            make.leading.equalTo(currentTimeLab.snp.trailing)
            make.centerY.equalToSuperview()
        }
        
        speedBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview()
            make.centerY.equalToSuperview()
            make.width.equalTo(50)
            make.height.equalTo(34)
        }
    }
    
    private func bindActions() {
        //        playAndPauseBtn.rx.tap
        //            .subscribe(onNext: { [weak self] in
        //                guard let self = self else { return }
        //                let select = !self.playAndPauseBtn.isSelected
        //                self.playAndPauseBtn.isSelected = select
        //                self.playRelay.accept(select)
        //            })
        //            .disposed(by: disposeBag)
    }
    
    // MARK: - Public Methods
    func updateFullScreenState(_ isFullScreen: Bool) {
        self.layoutIfNeeded()
    }
    
    // MARK: - Helper
    private func formatTime(_ seconds: Double) -> String {
        let intSeconds = Int(seconds.rounded())
        let minutes = intSeconds / 60
        let seconds = intSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
