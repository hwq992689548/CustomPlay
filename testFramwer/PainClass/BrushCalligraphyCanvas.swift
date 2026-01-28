//
//  BrushCalligraphyCanvas.swift (增强版)
//  testFramwer
//
//  Created by feixiang on 2026/1/28.
//

import UIKit
import PencilKit

public class BrushCalligraphyCanvas: UIViewController {
    private var eraserMode: EraserMode = .vector
    private var pixelEraserManager: PixelEraserManager?
    private var eraserPreviewView: UIView?
    private var isPixelEraserActive = false
    private var eraserStrokePoints: [CGPoint] = []
    
    // MARK: - 新增图像层（用于像素擦除）
    private var imageLayer: CALayer?
    private var currentDrawingImage: UIImage?
    private var originalDrawingImage: UIImage?
    
    
    
    // MARK: - 公开属性
    public let canvasView = PKCanvasView()
    public var config = BrushCalligraphyConfig()
    
    // MARK: - 私有属性
    private var engine: BrushCalligraphyEngine
    private var isProcessing = false
    private var lastStrokeChangeCount = 0
    
    // MARK: - 笔刷选择界面
    private var brushSelectionView: BrushSelectionView?
    
    // MARK: - 初始化
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        self.engine = BrushCalligraphyEngine(config: BrushCalligraphyConfig())
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    public convenience init(config: BrushCalligraphyConfig = BrushCalligraphyConfig()) {
        self.init(nibName: nil, bundle: nil)
        self.config = config
        self.engine = BrushCalligraphyEngine(config: config)
    }
    
    required init?(coder: NSCoder) {
        self.engine = BrushCalligraphyEngine(config: BrushCalligraphyConfig())
        super.init(coder: coder)
    }
    
    // MARK: - 生命周期
    public override func viewDidLoad() {
        super.viewDidLoad()
        print("🟢 viewDidLoad")
        setupCanvas()
        setupDrawingObserver()
        setupBrushSelectionUI()
        
    }
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("👁️ viewDidAppear - 画布已显示")
    }
    
    // MARK: - 设置画布
    private func setupCanvas() {
        // 1. 基础设置
        canvasView.frame = view.bounds
        canvasView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        canvasView.backgroundColor = .black  // 改为白色背景更友好
        
        // 2. 关键：设置绘图策略
        canvasView.drawingPolicy = .anyInput
        
        // 3. 根据配置设置初始工具
        updateToolForCurrentConfig()
        
        // 4. 添加到视图
        view.addSubview(canvasView)
        
        // 5. 启用交互
        canvasView.isUserInteractionEnabled = true
        
        print("✅ 画布设置完成")
        print("   - 笔刷类型: \(config.brushType.rawValue)")
        print("   - 基础宽度: \(config.baseWidth)")
        // 6. 初始化像素擦除系统
        setupPixelEraserSystem()
    }
    // MARK: - 设置像素擦除系统
    private func setupPixelEraserSystem() {
        // 初始化像素擦除管理器
        pixelEraserManager = PixelEraserManager(canvasSize: view.bounds.size)
        
        // 创建图像层（用于显示像素擦除效果）
        let layer = CALayer()
        layer.frame = view.bounds
        layer.contentsGravity = .resizeAspect
        layer.isHidden = true  // 默认隐藏，只在像素擦除时显示
        view.layer.insertSublayer(layer, above: canvasView.layer)
        imageLayer = layer
        
        // 创建橡皮擦预览视图
        let previewView = UIView()
        previewView.isUserInteractionEnabled = false
        previewView.layer.cornerRadius = 10
        previewView.layer.borderWidth = 2
        previewView.layer.borderColor = UIColor.red.withAlphaComponent(0.5).cgColor
        previewView.backgroundColor = UIColor.red.withAlphaComponent(0.1)
        previewView.isHidden = true
        view.addSubview(previewView)
        eraserPreviewView = previewView
        
        // 添加手势识别器
        setupEraserGestures()
    }
    
    // MARK: - 设置橡皮擦手势
    private func setupEraserGestures() {
        // 长按手势用于像素擦除
        let longPressGesture = UILongPressGestureRecognizer(target: self, action: #selector(handleEraserLongPress(_:)))
        longPressGesture.minimumPressDuration = 0.1
        canvasView.addGestureRecognizer(longPressGesture)
    }
    
    // MARK: - 处理橡皮擦长按手势
    @objc private func handleEraserLongPress(_ gesture: UILongPressGestureRecognizer) {
        // 只有橡皮擦模式且像素擦除时才处理
        guard config.brushType == .eraser, eraserMode == .pixel else { return }
        
        let location = gesture.location(in: canvasView)
        
        switch gesture.state {
        case .began:
            startPixelErasure(at: location)
            
        case .changed:
            updatePixelErasure(at: location)
            
        case .ended, .cancelled:
            endPixelErasure()
            
        default:
            break
        }
    }
    
    // MARK: - 开始像素擦除
    private func startPixelErasure(at location: CGPoint) {
        print("🎯 开始像素擦除")
        
        isPixelEraserActive = true
        eraserStrokePoints.removeAll()
        
        // 显示橡皮擦预览
        updateEraserPreview(at: location)
        
        // 保存当前画布图像
        captureCurrentDrawing()
        
        // 显示图像层
        imageLayer?.isHidden = false
        
        // 添加第一个点
        eraserStrokePoints.append(location)
    }
    
    // MARK: - 更新像素擦除
    private func updatePixelErasure(at location: CGPoint) {
        guard isPixelEraserActive else { return }
        
        // 更新橡皮擦预览位置
        updateEraserPreview(at: location)
        
        // 记录擦除路径点
        eraserStrokePoints.append(location)
        
        // 实时更新擦除效果
        updateErasureInRealTime()
    }
    
    // MARK: - 结束像素擦除
    private func endPixelErasure() {
        guard isPixelEraserActive else { return }
        
        print("✅ 完成像素擦除，路径点数: \(eraserStrokePoints.count)")
        
        // 隐藏预览
        eraserPreviewView?.isHidden = true
        
        // 应用最终的擦除效果
        applyFinalErasure()
        
        // 重置状态
        isPixelEraserActive = false
        eraserStrokePoints.removeAll()
    }
    // MARK: - 捕获当前绘图
    private func captureCurrentDrawing() {
        // 将 PKCanvasView 的内容渲染为图像
        let renderer = UIGraphicsImageRenderer(size: canvasView.bounds.size)
        currentDrawingImage = renderer.image { context in
            canvasView.drawHierarchy(in: canvasView.bounds, afterScreenUpdates: true)
        }
        
        // 保存原始图像
        originalDrawingImage = currentDrawingImage
        
        // 设置到图像层
        imageLayer?.contents = currentDrawingImage?.cgImage
    }
    
    // MARK: - 实时更新擦除效果
    private func updateErasureInRealTime() {
        guard let eraserManager = pixelEraserManager,
              let currentImage = currentDrawingImage,
              eraserStrokePoints.count >= 2 else { return }
        
        // 添加擦除路径到遮罩
        let radius = config.baseWidth / 2
        eraserManager.addErasurePath(eraserStrokePoints, radius: radius)
        
        // 应用遮罩并更新显示
        if let maskedImage = eraserManager.applyMask(to: currentImage) {
            currentDrawingImage = maskedImage
            imageLayer?.contents = maskedImage.cgImage
        }
    }
    
    // MARK: - 应用最终擦除效果
    private func applyFinalErasure() {
        guard let eraserManager = pixelEraserManager,
              let originalImage = originalDrawingImage else { return }
        
        print("🎨 应用最终擦除效果")
        
        // 应用完整的擦除遮罩
        if let finalImage = eraserManager.applyMask(to: originalImage) {
            currentDrawingImage = finalImage
            
            // 这里需要将擦除后的图像应用到画布
            // 由于 PencilKit 不支持直接修改图像，我们可以通过以下方式：
            // 1. 将图像转换为新的笔画（复杂）
            // 2. 或者显示一个覆盖层
            // 暂时使用覆盖层方案
            imageLayer?.contents = finalImage.cgImage
            
            // 可选：将像素擦除结果转换为笔画（高级功能）
            // convertErasureToStrokes()
        }
        
        // 隐藏图像层（如果用户继续绘制，会覆盖它）
        imageLayer?.isHidden = true
    }
    
    // MARK: - 更新工具配置（增强橡皮擦支持）
    private func updateToolForCurrentConfig() {
        var tool: PKTool
        
        switch config.brushType {
        case .eraser:
            // 根据橡皮擦模式选择工具
            switch eraserMode {
            case .vector:
                // 矢量擦除（整笔擦除）- 使用 PencilKit 原生橡皮擦
                tool = PKEraserTool(.vector)
                print("🛠️ 使用矢量橡皮擦")
                
            case .pixel:
                // 像素擦除 - 使用透明笔刷并启用自定义手势
                tool = PKInkingTool(.pen, color: .clear, width: config.baseWidth)
                print("🛠️ 使用像素橡皮擦（透明笔刷）")
                
            case .smart:
                // 智能擦除 - 根据笔画宽度调整的橡皮擦
                tool = PKEraserTool(.vector)
                print("🛠️ 使用智能橡皮擦")
            }
            
        default:
            // 正常笔刷
            let inkType: PKInkingTool.InkType = config.brushType == .marker ? .marker : .pen
            tool = PKInkingTool(inkType, color: config.inkColor, width: config.baseWidth)
        }
        
        canvasView.tool = tool
    }
    
    // MARK: - 更新橡皮擦预览
    private func updateEraserPreview(at location: CGPoint) {
        guard let previewView = eraserPreviewView else { return }
        
        let size = config.baseWidth
        previewView.frame = CGRect(x: location.x - size/2,
                                   y: location.y - size/2,
                                   width: size,
                                   height: size)
        previewView.isHidden = false
        
        // 根据压力调整预览大小（如果有压力数据）
        if let touch = canvasView.window?.hitTest(location, with: nil)?.gestureRecognizers?.first?.value(forKey: "_touch") as? UITouch {
            let force = touch.force
            if force > 0 {
                let forceMultiplier = 1.0 + force * 0.5
                let newSize = size * forceMultiplier
                previewView.frame = CGRect(x: location.x - newSize/2,
                                           y: location.y - newSize/2,
                                           width: newSize,
                                           height: newSize)
            }
        }
        
    }
    // MARK: - 笔刷选择界面
    private func setupBrushSelectionUI() {
        brushSelectionView = BrushSelectionView()
        brushSelectionView?.delegate = self
        if let brushView = brushSelectionView {
            view.addSubview(brushView)
            
            brushView.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                brushView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                brushView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
                brushView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
                brushView.heightAnchor.constraint(equalToConstant: 80)
            ])
            
            // 设置默认选择
            brushView.selectBrushType(config.brushType)
        }
    }
    
    // MARK: - KVO观察者方法
    private func setupDrawingObserver() {
        // 观察drawing属性的变化
        canvasView.addObserver(self,
                               forKeyPath: #keyPath(PKCanvasView.drawing),
                               options: [.new, .old],
                               context: nil)
        
        print("👀 已设置绘图观察者")
    }
    
    public override func observeValue(forKeyPath keyPath: String?,
                                      of object: Any?,
                                      change: [NSKeyValueChangeKey : Any]?,
                                      context: UnsafeMutableRawPointer?) {
        
        guard keyPath == #keyPath(PKCanvasView.drawing),
              let canvas = object as? PKCanvasView,
              canvas == self.canvasView else {
            return
        }
        
        // 获取新旧drawing
        let oldDrawing = change?[.oldKey] as? PKDrawing ?? PKDrawing()
        let newDrawing = change?[.newKey] as? PKDrawing ?? PKDrawing()
        
        // 检查是否有新笔画添加
        if newDrawing.strokes.count > oldDrawing.strokes.count {
            print("📝 检测到新笔画完成！")
            print("   笔刷类型: \(config.brushType.rawValue)")
            print("   旧笔画数: \(oldDrawing.strokes.count)")
            print("   新笔画数: \(newDrawing.strokes.count)")
            
            // 处理最后一笔（延迟一点点确保数据稳定）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.processLastStroke()
            }
        }
    }
    
    // MARK: - 处理笔画的函数
    private func processLastStroke() {
        // 防重入检查
        guard !isProcessing else {
            print("⏸️ 正在处理中，跳过")
            return
        }
        // 如果是像素擦除模式，已经在手势中处理，这里跳过
        if config.brushType == .eraser && eraserMode == .pixel && isPixelEraserActive {
            print("⏸️ 像素擦除进行中，跳过笔画处理")
            return
        }
        guard let lastStroke = canvasView.drawing.strokes.last else {
            print("⚠️ 没有找到最后一笔")
            return
        }
        
        // 检查是否已经处理过（避免重复处理）
        if canvasView.drawing.strokes.count == lastStrokeChangeCount {
            print("🔄 该笔画已处理过，跳过")
            return
        }
        
        isProcessing = true
        defer { isProcessing = false }
        
        print("🎨 开始处理笔画")
        print("   - 原始点数: \(lastStroke.path.count)")
        
        // 重置引擎状态
        engine.reset()
        
        // 创建完整笔画（包含效果）
        let newStrokes = engine.createCompleteStroke(from: lastStroke)
        
        // 替换原始笔画
        var strokes = canvasView.drawing.strokes
        strokes.removeLast()
        strokes.append(contentsOf: newStrokes)
        
        // 更新画布（在主线程）
        DispatchQueue.main.async {
            let newDrawing = PKDrawing(strokes: strokes)
            
            // 注册撤销操作
            self.canvasView.undoManager?.registerUndo(withTarget: self.canvasView) { canvas in
                let oldDrawing = canvas.drawing
                canvas.drawing = newDrawing
                
                // 为重做注册操作
                canvas.undoManager?.registerUndo(withTarget: canvas) { canvas in
                    canvas.drawing = oldDrawing
                }
            }
            
            self.canvasView.drawing = newDrawing
            self.lastStrokeChangeCount = strokes.count
            
            print("✅ 笔画处理完成")
            print("   - 生成笔画数: \(newStrokes.count)")
            
            // 更新状态
            self.updateUndoRedoState()
        }
    }
    
    //    // MARK: - 更新工具配置
    //    private func updateToolForCurrentConfig() {
    //        var tool: PKTool
    //
    //        switch config.brushType {
    //        case .eraser:
    //            // 橡皮擦
    //            tool = PKEraserTool(.vector)
    //
    //        default:
    //            // 墨水工具
    //            let inkType: PKInkingTool.InkType = config.brushType == .marker ? .marker : .pen
    //
    //            var color = config.inkColor
    //            // 橡皮擦特殊处理
    //            if config.brushType == .eraser {
    //                color = .white
    //            }
    //
    //            tool = PKInkingTool(inkType,
    //                                color: color,
    //                                width: config.baseWidth)
    //        }
    //
    //        canvasView.tool = tool
    //        print("🛠️ 更新工具: \(tool)")
    //    }
    
    // MARK: - 笔刷设置方法（公开API）
    
    /// 切换笔刷类型
    public func setBrushType(_ type: BrushType) {
        config = type.defaultConfig
        engine.config = config
        updateToolForCurrentConfig()
        
        print("🖌️ 切换到: \(type.rawValue)")
        brushSelectionView?.selectBrushType(type)
    }
    
    /// 设置笔刷颜色
    public func setBrushColor(_ color: UIColor) {
        config.inkColor = color
        updateToolForCurrentConfig()
        print("🎨 设置颜色: \(color)")
    }
    
    /// 设置笔刷宽度
    public func setBrushWidth(_ width: CGFloat) {
        config.baseWidth = max(1.0, min(50.0, width))
        updateToolForCurrentConfig()
        print("📏 设置宽度: \(width)")
    }
    
    /// 设置压力敏感度
    public func setForceSensitivity(_ sensitivity: CGFloat) {
        config.forceSensitivity = max(0.0, min(1.0, sensitivity))
        engine.config = config
        print("⚡ 压力敏感度: \(sensitivity)")
    }
    
    /// 启用/禁用飞白效果
    public func setDryBrushEffect(enabled: Bool) {
        config.enableDryBrushEffect = enabled
        engine.config = config
        print(enabled ? "🎨 启用飞白效果" : "🔲 禁用飞白效果")
    }
    
    /// 启用/禁用墨迹晕染
    public func setInkBleeding(enabled: Bool) {
        config.enableInkBleeding = enabled
        engine.config = config
        print(enabled ? "💧 启用墨迹晕染" : "🔲 禁用墨迹晕染")
    }
    
    // MARK: - 清理
    deinit {
        // 移除观察者
        canvasView.removeObserver(self, forKeyPath: #keyPath(PKCanvasView.drawing))
        print("🧹 清理观察者")
    }
    
    // MARK: - 实用方法
    public func clearCanvas() {
        canvasView.drawing = PKDrawing()
        lastStrokeChangeCount = 0
        print("🧹 画布已清除")
    }
    
    public func getStrokeCount() -> Int {
        return canvasView.drawing.strokes.count
    }
}

// MARK: - 撤销/重做功能
extension BrushCalligraphyCanvas {
    public func undo() {
        if canvasView.undoManager?.canUndo == true {
            canvasView.undoManager?.undo()
            print("↩️ 撤销操作")
            updateUndoRedoState()
        } else {
            print("⚠️ 无法撤销")
        }
    }
    
    public func redo() {
        if canvasView.undoManager?.canRedo == true {
            canvasView.undoManager?.redo()
            print("↪️ 重做操作")
            updateUndoRedoState()
        } else {
            print("⚠️ 无法重做")
        }
    }
    
    public func canUndo() -> Bool {
        return canvasView.undoManager?.canUndo ?? false
    }
    
    public func canRedo() -> Bool {
        return canvasView.undoManager?.canRedo ?? false
    }
    
    private func updateUndoRedoState() {
        print("📊 状态更新 - 可撤销: \(canUndo()), 可重做: \(canRedo())")
        print("📊 当前笔画数: \(canvasView.drawing.strokes.count)")
    }
}

// MARK: - 笔刷选择视图代理
extension BrushCalligraphyCanvas: BrushSelectionDelegate {
    func didSelectBrushType(_ type: BrushType) {
        setBrushType(type)
    }
}

// MARK: - 笔刷选择视图
protocol BrushSelectionDelegate: AnyObject {
    func didSelectBrushType(_ type: BrushType)
}

class BrushSelectionView: UIView {
    weak var delegate: BrushSelectionDelegate?
    
    private var brushButtons: [BrushType: UIButton] = [:]
    private var selectedType: BrushType = .calligraphyBrush
    
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
        
        for brushType in BrushType.allCases {
            let button = createBrushButton(for: brushType)
            brushButtons[brushType] = button
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
    
    private func createBrushButton(for type: BrushType) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(type.rawValue, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        button.setTitleColor(.gray, for: .normal)
        button.setTitleColor(.blue, for: .selected)
        button.backgroundColor = .white
        button.layer.cornerRadius = 8
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.lightGray.cgColor
        button.tag = type.hashValue
        
        button.addTarget(self, action: #selector(brushButtonTapped(_:)), for: .touchUpInside)
        
        return button
    }
    
    @objc private func brushButtonTapped(_ sender: UIButton) {
        guard let brushType = BrushType.allCases.first(where: { $0.hashValue == sender.tag }) else { return }
        
        selectBrushType(brushType)
        delegate?.didSelectBrushType(brushType)
    }
    
    func selectBrushType(_ type: BrushType) {
        selectedType = type
        
        for (brushType, button) in brushButtons {
            button.isSelected = (brushType == type)
            button.layer.borderColor = (brushType == type) ? UIColor.blue.cgColor : UIColor.lightGray.cgColor
        }
    }
}




// MARK: - 新增：像素擦除到笔画的转换（可选高级功能）
extension BrushCalligraphyCanvas {
    /// 将像素擦除结果转换为笔画（高级功能）
    private func convertErasureToStrokes() {
        // 这是一个高级功能，将擦除后的图像边缘检测为笔画
        // 由于实现复杂，这里只提供框架
        
        /*
         步骤：
         1. 获取擦除后的图像
         2. 使用边缘检测算法（如Canny）找出轮廓
         3. 将轮廓转换为PKStroke路径
         4. 添加到画布
         */
        
        print("⚠️ 像素擦除到笔画转换需要实现边缘检测算法")
    }
    
    /// 设置橡皮擦模式
    public func setEraserMode(_ mode: EraserMode) {
        eraserMode = mode
        
        // 根据模式更新配置
        switch mode {
        case .vector:
            config = .eraser
            imageLayer?.isHidden = true  // 隐藏图像层
            
        case .pixel:
            config = .pixelEraser
            imageLayer?.isHidden = true  // 默认隐藏，擦除时显示
            
        case .smart:
            config = .smartEraser
            imageLayer?.isHidden = true
        }
        
        engine.config = config
        updateToolForCurrentConfig()
        
        print("🧹 设置橡皮擦模式: \(mode.rawValue)")
    }
    
    /// 设置橡皮擦大小
    public func setEraserSize(_ size: CGFloat) {
        config.baseWidth = max(1.0, min(100.0, size))
        updateToolForCurrentConfig()
        print("📏 设置橡皮擦大小: \(size)")
    }
    
    /// 启用/禁用像素擦除预览
    public func setPixelEraserPreview(enabled: Bool) {
        eraserPreviewView?.isHidden = !enabled
        print(enabled ? "👁️ 启用像素擦除预览" : "👁️ 禁用像素擦除预览")
    }
    
    /// 清除像素擦除历史
    public func clearPixelErasure() {
        pixelEraserManager?.clearMask()
        imageLayer?.isHidden = true
        print("🧹 清除像素擦除历史")
    }
    
    // MARK: - 视图布局更新
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // 更新图像层和像素擦除管理器的大小
        imageLayer?.frame = view.bounds
        
        if let pixelEraserManager = pixelEraserManager {
            // 重新创建管理器以适应新的大小
            self.pixelEraserManager = PixelEraserManager(canvasSize: view.bounds.size)
        }
    }
    
}
