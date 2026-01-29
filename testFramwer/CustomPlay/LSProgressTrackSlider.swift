//
//  LSProgressTrackSlider.swift
//  testFramwer
//
//  Created by feixiang huang on 2026/1/28.
//

import UIKit

class LSProgressTrackSlider: UISlider {
    var trackHeight: CGFloat = 8
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setThumbImage(UIImage(), for: .normal)
        self.setThumbImage(UIImage(), for: .highlighted)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        // 设置轨道的尺寸和位置
        let defaultRect = super.trackRect(forBounds: bounds)
        return CGRect(
            x: defaultRect.origin.x,
            y: (bounds.height - trackHeight) / 2,  // 垂直居中
            width: defaultRect.width,
            height: trackHeight  // 自定义高度
        )
    }
}
