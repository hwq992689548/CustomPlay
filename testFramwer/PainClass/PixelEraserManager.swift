//
//  PixelEraserManager.swift
//  testFramwer
//
//  Created by feixiang on 2026/1/28.
//

import UIKit

// MARK: - 增强橡皮擦模式枚举
public enum EraserMode: String, CaseIterable {
    case vector = "矢量擦除"    // PencilKit 原生擦除（整笔擦除）
    case pixel = "像素擦除"    // 像素级擦除（通过遮罩实现）
    case smart = "智能擦除"    // 智能分割擦除
    
    var description: String {
        switch self {
        case .vector: return "整笔擦除"
        case .pixel: return "像素擦除"
        case .smart: return "智能擦除"
        }
    }
}

// MARK: - 像素擦除配置
public extension BrushCalligraphyConfig {
    /// 像素橡皮擦配置
    static var pixelEraser: BrushCalligraphyConfig {
        var config = BrushCalligraphyConfig()
        config.brushType = .eraser
        config.baseWidth = 15.0
        config.maxWidthRange = 0.0
        config.forceSensitivity = 0.0
        config.enableDryBrushEffect = false
        config.inkColor = .clear
        config.brushOpacity = 1.0
        return config
    }
    
    /// 智能橡皮擦配置
    static var smartEraser: BrushCalligraphyConfig {
        var config = BrushCalligraphyConfig()
        config.brushType = .eraser
        config.baseWidth = 10.0
        config.maxWidthRange = 20.0
        config.forceSensitivity = 0.5
        config.speedSensitivity = 0.3
        config.enableSpeedEffect = true
        config.inkColor = .clear
        config.brushOpacity = 1.0
        return config
    }
}

// MARK: - 新增：像素擦除管理器
public class PixelEraserManager {
    /// 擦除遮罩图像
    public private(set) var eraserMask: UIImage?
    
    /// 画布尺寸
    private var canvasSize: CGSize
    
    /// 遮罩绘制上下文
    private var maskContext: CGContext?
    
    public init(canvasSize: CGSize) {
        self.canvasSize = canvasSize
        setupMaskContext()
    }
    
    /// 设置遮罩绘制上下文
    private func setupMaskContext() {
        let scale = UIScreen.main.scale
        let size = CGSize(width: canvasSize.width * scale, height: canvasSize.height * scale)
        
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGImageAlphaInfo.alphaOnly.rawValue
        
        guard let context = CGContext(data: nil,
                                     width: Int(size.width),
                                     height: Int(size.height),
                                     bitsPerComponent: 8,
                                     bytesPerRow: Int(size.width),
                                     space: colorSpace,
                                     bitmapInfo: bitmapInfo) else {
            return
        }
        
        // 设置初始遮罩为全透明（完全不擦除）
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        maskContext = context
        updateMaskImage()
    }
    
    /// 添加擦除区域
    public func addErasure(at point: CGPoint, radius: CGFloat) {
        guard let context = maskContext else { return }
        
        let scale = UIScreen.main.scale
        let scaledPoint = CGPoint(x: point.x * scale, y: point.y * scale)
        let scaledRadius = radius * scale
        
        // 在遮罩上绘制白色（表示擦除）
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: CGRect(x: scaledPoint.x - scaledRadius,
                                     y: scaledPoint.y - scaledRadius,
                                     width: scaledRadius * 2,
                                     height: scaledRadius * 2))
        
        updateMaskImage()
    }
    
    /// 添加擦除路径
    public func addErasurePath(_ points: [CGPoint], radius: CGFloat) {
        guard points.count > 1, let context = maskContext else { return }
        
        let scale = UIScreen.main.scale
        let path = CGMutablePath()
        
        for i in 0..<points.count {
            let point = points[i]
            let scaledPoint = CGPoint(x: point.x * scale, y: point.y * scale)
            let scaledRadius = radius * scale
            
            let rect = CGRect(x: scaledPoint.x - scaledRadius,
                            y: scaledPoint.y - scaledRadius,
                            width: scaledRadius * 2,
                            height: scaledRadius * 2)
            
            if i == 0 {
                path.move(to: scaledPoint)
                path.addEllipse(in: rect)
            } else {
                path.addLine(to: scaledPoint)
                path.addEllipse(in: rect)
            }
        }
        
        // 填充擦除路径
        context.setFillColor(UIColor.white.cgColor)
        context.addPath(path)
        context.fillPath(using: .winding)
        
        updateMaskImage()
    }
    
    /// 清除遮罩
    public func clearMask() {
        guard let context = maskContext else { return }
        
        let size = CGSize(width: context.width, height: context.height)
        context.clear(CGRect(origin: .zero, size: size))
        
        // 重置为全透明
        context.setFillColor(UIColor.clear.cgColor)
        context.fill(CGRect(origin: .zero, size: size))
        
        updateMaskImage()
    }
    
    /// 更新遮罩图像
    private func updateMaskImage() {
        guard let context = maskContext,
              let cgImage = context.makeImage() else { return }
        
        eraserMask = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: .up)
    }
    
    /// 应用遮罩到图像
    public func applyMask(to image: UIImage) -> UIImage? {
        guard let mask = eraserMask,
              let inputCGImage = image.cgImage,
              let maskCGImage = mask.cgImage else { return nil }
        
        let size = image.size
        let rect = CGRect(origin: .zero, size: size)
        
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        defer { UIGraphicsEndImageContext() }
        
        guard let context = UIGraphicsGetCurrentContext() else { return nil }
        
        // 绘制原始图像
        context.draw(inputCGImage, in: rect)
        
        // 应用遮罩
        context.clip(to: rect, mask: maskCGImage)
        context.clear(rect)
        
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}
