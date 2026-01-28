//
//  EraserSelectionView.swift
//  testFramwer
//
//  Created by feixiang on 2026/1/28.
//

import UIKit

// MARK: - 橡皮擦选择视图
class EraserSelectionView: UIView {
    weak var delegate: BrushSelectionDelegate?
    
    private var modeButtons: [EraserMode: UIButton] = [:]
    private var selectedMode: EraserMode = .vector
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = UIColor(white: 0.95, alpha: 0.9)
        layer.cornerRadius = 10
        layer.masksToBounds = true
        
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 5
        
        for eraserMode in EraserMode.allCases {
            let button = createModeButton(for: eraserMode)
            modeButtons[eraserMode] = button
            stackView.addArrangedSubview(button)
        }
        
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }
    
    private func createModeButton(for mode: EraserMode) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(mode.rawValue, for: .normal)
        button.setTitle(mode.description, for: .selected)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        button.setTitleColor(.gray, for: .normal)
        button.setTitleColor(.blue, for: .selected)
        button.backgroundColor = .white
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.tag = mode.hashValue
        
        // 添加图标
        let iconSize: CGFloat = 20
        let iconView = UIImageView(frame: CGRect(x: 0, y: 0, width: iconSize, height: iconSize))
        iconView.contentMode = .scaleAspectFit
        
        switch mode {
        case .vector:
            iconView.image = UIImage(systemName: "pencil.tip.crop.circle")
        case .pixel:
            iconView.image = UIImage(systemName: "circle.dashed")
        case .smart:
            iconView.image = UIImage(systemName: "brain.head.profile")
        }
        
        iconView.tintColor = .gray
        button.addSubview(iconView)
        
        // 添加点击事件
        button.addTarget(self, action: #selector(modeButtonTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    @objc private func modeButtonTapped(_ sender: UIButton) {
        guard let eraserMode = EraserMode.allCases.first(where: { $0.hashValue == sender.tag }) else { return }
        
        selectMode(eraserMode)
        // 通知代理（需要扩展协议）
        // delegate?.didSelectEraserMode(eraserMode)
    }
    
    func selectMode(_ mode: EraserMode) {
        selectedMode = mode
        
        for (eraserMode, button) in modeButtons {
            button.isSelected = (eraserMode == mode)
            button.layer.borderColor = (eraserMode == mode) ? UIColor.blue.cgColor : UIColor.lightGray.cgColor
            
            // 更新图标颜色
            if let iconView = button.subviews.first as? UIImageView {
                iconView.tintColor = (eraserMode == mode) ? .blue : .gray
            }
        }
    }
}
