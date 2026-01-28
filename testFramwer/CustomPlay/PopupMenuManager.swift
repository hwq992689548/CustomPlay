// MARK: - 自定义速度菜单视图
import UIKit

class SpeedMenuView: UIView {
    
    private let speeds: [Float]
    private let currentSpeed: Float
    var onSpeedSelected: ((CGFloat) -> Void)?
    
    private let tableView: UITableView = {
        let tableView = UITableView(frame: .zero, style: .plain)
        tableView.backgroundColor = UIColor(white: 0.15, alpha: 0.95)
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.1)
        tableView.layer.cornerRadius = 8
        tableView.layer.masksToBounds = true
        tableView.isScrollEnabled = false
        tableView.showsVerticalScrollIndicator = false
        tableView.register(SpeedCell.self, forCellReuseIdentifier: "SpeedCell")
        tableView.tableFooterView = UIView()
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        return tableView
    }()
    
    init(speeds: [Float], currentSpeed: Float) {
        self.speeds = speeds
        self.currentSpeed = currentSpeed
        super.init(frame: .zero)
        self.isUserInteractionEnabled = true 
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        backgroundColor = .clear
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 12
        layer.shadowOpacity = 0.3
        
        tableView.delegate = self
        tableView.dataSource = self
        addSubview(tableView)
        tableView.frame = bounds
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
}

extension SpeedMenuView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return speeds.count
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SpeedCell", for: indexPath) as! SpeedCell
        let speed = speeds[indexPath.row]
        let isSelected = abs(speed - currentSpeed) < 0.01
        
        cell.configure(with: speed, isSelected: isSelected)
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let speed = speeds[indexPath.row]
        onSpeedSelected?(CGFloat(speed))
    }
}

// MARK: - 自定义速度单元格
class SpeedCell: UITableViewCell {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    private let checkmarkImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.image = UIImage(systemName: "checkmark")
        imageView.tintColor = .systemBlue
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        return imageView
    }()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(checkmarkImageView)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        checkmarkImageView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            
            checkmarkImageView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            checkmarkImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            checkmarkImageView.widthAnchor.constraint(equalToConstant: 16),
            checkmarkImageView.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func configure(with speed: Float, isSelected: Bool) {
        titleLabel.text = "\(speed)x"
        
        if isSelected {
            titleLabel.textColor = .systemBlue
            titleLabel.font = .systemFont(ofSize: 16, weight: .medium)
            checkmarkImageView.isHidden = false
        } else {
            titleLabel.textColor = .white
            titleLabel.font = .systemFont(ofSize: 16, weight: .regular)
            checkmarkImageView.isHidden = true
        }
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        contentView.backgroundColor = highlighted ? UIColor.white.withAlphaComponent(0.1) : .clear
    }
}
