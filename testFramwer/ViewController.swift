//
//  ViewController.swift
//  testFramwer
//
//  Created by feixiang on 2026/1/23.
//

import UIKit
import RxSwift
import RxCocoa
import SnapKit


class ViewController: UIViewController {
    lazy var playerVC: LSPlayerViewController = {
        let temp = LSPlayerViewController()
        temp.delegate = self
        return temp
    }()
    lazy var loadBtn: UIButton = {
        let btn = UIButton()
        btn.backgroundColor = UIColor.orange
        btn.addTarget(self, action: #selector(loadBtnAction), for: .touchUpInside)
        return btn
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        view.addSubview(loadBtn)
        view.addSubview(playerVC.view)
        
        loadBtn.snp.makeConstraints { make in
            make.width.height.equalTo(100)
            make.top.equalTo(300)
            make.leading.equalTo(100)
        }
        
        playerVC.view.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top)
            make.height.equalTo(200)
        }
    }
    
    /// 在加里添加视频URL
    @objc private func loadBtnAction() {
        guard let url = URL.init(string: "https://oss.laserpecker.net/app/lso/video/LSO_VIDEO_260120.mp4?preview=2") else {
            return
        }
        playerVC.loadVideo(from: url) {
            
        }
    }
}

extension ViewController: LSPlayerViewControllerDelegate {
    
    func videoPlayerDidStartPlaying(_ player: LSPlayerViewController) {
        print("播放开始")
    }
    
    func videoPlayerDidFinishPlaying(_ player: LSPlayerViewController) {
        print("播放完成")
    }
    
    func videoPlayerDidPause(_ player: LSPlayerViewController) {
        print("播放暂停")
    }
    
    
}
