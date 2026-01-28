//
//  PaintUtils.swift
//  testFramwer
//
//  Created by feixiang on 2026/1/28.
//

import UIKit
import PencilKit

// MARK: - 笔刷类型枚举
public enum BrushType: String, CaseIterable {
    case hardBrush = "硬毛笔"      // 硬毫，笔触锋利
    case softBrush = "软毛笔"      // 软毫，笔触柔和
    case calligraphyBrush = "书法笔" // 书法专用
    case pen = "普通笔"           // 普通画笔
    case pencil = "铅笔"          // 铅笔效果
    case marker = "马克笔"        // 马克笔效果
    case eraser = "橡皮擦"        // 橡皮擦
    
    var iconName: String {
        switch self {
        case .hardBrush: return "hard_brush"
        case .softBrush: return "soft_brush"
        case .calligraphyBrush: return "calligraphy"
        case .pen: return "pen"
        case .pencil: return "pencil"
        case .marker: return "marker"
        case .eraser: return "eraser"
        }
    }
}

// MARK: - 核心配置
public struct BrushCalligraphyConfig {
    /// 笔刷类型
    public var brushType: BrushType = .calligraphyBrush
    /// 基础笔触宽度
    public var baseWidth: CGFloat = 3.0
    /// 最大宽度加成
    public var maxWidthRange: CGFloat = 25.0
    /// 最小宽度限制
    public var minWidth: CGFloat = 1.0
    /// 最大宽度限制
    public var maxWidth: CGFloat = 35.0
    /// 压力敏感度 (0.0~1.0)
    public var forceSensitivity: CGFloat = 1.0
    /// 速度敏感度 (0.0~1.0)
    public var speedSensitivity: CGFloat = 0.5
    /// 方向敏感度 (0.0~1.0)
    public var directionSensitivity: CGFloat = 0.3
    /// 墨色
    public var inkColor: UIColor = .black
    /// 启用速度影响
    public var enableSpeedEffect: Bool = true
    /// 启用方向影响（模拟侧锋）
    public var enableDirectionEffect: Bool = true
    /// 启用毛笔飞白效果
    public var enableDryBrushEffect: Bool = true
    /// 启用墨迹晕染
    public var enableInkBleeding: Bool = false
    /// 启用纹理效果
    public var enableTexture: Bool = true
    /// 笔刷纹理图像
    public var brushTexture: UIImage? = nil
    /// 笔刷不透明度
    public var brushOpacity: CGFloat = 1.0
    /// 飞白效果强度
    public var dryBrushStrength: CGFloat = 0.3
    
    public init() {}
}

// MARK: - 扩展：预置配置
public extension BrushCalligraphyConfig {
    /// 软毛笔配置（压力敏感，速度敏感）
    static var softBrush: BrushCalligraphyConfig {
        var config = BrushCalligraphyConfig()
        config.brushType = .softBrush
        config.baseWidth = 2.0
        config.maxWidthRange = 30.0
        config.forceSensitivity = 1.0
        config.speedSensitivity = 0.7
        config.enableSpeedEffect = true
        config.enableDryBrushEffect = true
        config.dryBrushStrength = 0.2
        config.inkColor = .black
        return config
    }
    
    /// 硬毛笔配置（压力敏感，速度不敏感）
    static var hardBrush: BrushCalligraphyConfig {
        var config = BrushCalligraphyConfig()
        config.brushType = .hardBrush
        config.baseWidth = 4.0
        config.maxWidthRange = 20.0
        config.forceSensitivity = 0.8
        config.speedSensitivity = 0.2
        config.enableSpeedEffect = false
        config.enableTexture = true
        config.dryBrushStrength = 0.4
        config.inkColor = UIColor(red: 0.2, green: 0.1, blue: 0.05, alpha: 1.0)
        return config
    }
    
    /// 书法笔配置（强调方向和速度）
    static var calligraphyBrush: BrushCalligraphyConfig {
        var config = BrushCalligraphyConfig()
        config.brushType = .calligraphyBrush
        config.baseWidth = 5.0
        config.maxWidthRange = 25.0
        config.forceSensitivity = 0.6
        config.speedSensitivity = 0.9
        config.directionSensitivity = 0.8
        config.enableDirectionEffect = true
        config.enableDryBrushEffect = true
        config.dryBrushStrength = 0.5
        config.inkColor = .black
        return config
    }
    
    /// 普通笔配置（均一宽度）
    static var pen: BrushCalligraphyConfig {
        var config = BrushCalligraphyConfig()
        config.brushType = .pen
        config.baseWidth = 2.0
        config.maxWidthRange = 0.0  // 无宽度变化
        config.forceSensitivity = 0.0
        config.speedSensitivity = 0.0
        config.enableSpeedEffect = false
        config.enableDryBrushEffect = false
        config.inkColor = .black
        return config
    }
    
    /// 铅笔配置（轻微变化）
    static var pencil: BrushCalligraphyConfig {
        var config = BrushCalligraphyConfig()
        config.brushType = .pencil
        config.baseWidth = 1.5
        config.maxWidthRange = 5.0
        config.forceSensitivity = 0.3
        config.speedSensitivity = 0.4
        config.enableDryBrushEffect = false
        config.inkColor = UIColor(white: 0.2, alpha: 1.0)
        config.brushOpacity = 0.9
        return config
    }
    
    /// 马克笔配置（半透明效果）
    static var marker: BrushCalligraphyConfig {
        var config = BrushCalligraphyConfig()
        config.brushType = .marker
        config.baseWidth = 8.0
        config.maxWidthRange = 10.0
        config.forceSensitivity = 0.1
        config.brushOpacity = 0.5
        config.enableDryBrushEffect = false
        config.inkColor = .blue
        return config
    }
    
    /// 橡皮擦配置
    static var eraser: BrushCalligraphyConfig {
        var config = BrushCalligraphyConfig()
        config.brushType = .eraser
        config.baseWidth = 10.0
        config.maxWidthRange = 0.0
        config.forceSensitivity = 0.0
        config.enableDryBrushEffect = false
        config.inkColor = .white  // 橡皮擦用白色
        return config
    }
}

// MARK: - 笔刷效果应用器
public class BrushEffectApplier {
    
    /// 应用笔刷纹理效果（通过创建新的点）
    public static func applyBrushTexture(to points: [PKStrokePoint],
                                       config: BrushCalligraphyConfig) -> [PKStrokePoint] {
        
        switch config.brushType {
        case .hardBrush:
            return applyHardBrushTexture(points, config: config)
        case .softBrush:
            return applySoftBrushTexture(points, config: config)
        case .calligraphyBrush:
            return applyCalligraphyTexture(points, config: config)
        default:
            return points
        }
    }
    
    /// 硬毛笔纹理 - 强调笔锋
    private static func applyHardBrushTexture(_ points: [PKStrokePoint],
                                            config: BrushCalligraphyConfig) -> [PKStrokePoint] {
        return points.enumerated().map { index, point in
            let progress = CGFloat(index) / CGFloat(points.count - 1)
            
            // 硬毛笔：起笔收笔有纹理变化
            let textureStrength = progress < 0.1 || progress > 0.9 ? 0.8 : 0.3
            
            // 创建新的点，应用透明度变化
            return PKStrokePoint(
                location: point.location,
                timeOffset: point.timeOffset,
                size: point.size,
                opacity: point.opacity * (1.0 - textureStrength * config.dryBrushStrength * 0.5),
                force: point.force,
                azimuth: point.azimuth,
                altitude: point.altitude
            )
        }
    }
    
    /// 软毛笔纹理 - 柔和变化
    private static func applySoftBrushTexture(_ points: [PKStrokePoint],
                                            config: BrushCalligraphyConfig) -> [PKStrokePoint] {
        return points.map { point in
            // 软毛笔：整体透明度略低
            return PKStrokePoint(
                location: point.location,
                timeOffset: point.timeOffset,
                size: point.size,
                opacity: point.opacity * 0.95 * config.brushOpacity,
                force: point.force,
                azimuth: point.azimuth,
                altitude: point.altitude
            )
        }
    }
    
    /// 书法毛笔纹理 - 飞白效果
    private static func applyCalligraphyTexture(_ points: [PKStrokePoint],
                                              config: BrushCalligraphyConfig) -> [PKStrokePoint] {
        return points.enumerated().map { index, point in
            let progress = CGFloat(index) / CGFloat(points.count - 1)
            
            var opacity = point.opacity * config.brushOpacity
            
            // 创建飞白效果：中间段有随机透明区域
            if config.enableDryBrushEffect && progress > 0.3 && progress < 0.7 {
                let randomValue = CGFloat.random(in: 0...1)
                let dryBrushThreshold = config.dryBrushStrength * 0.3
                
                if randomValue < dryBrushThreshold {
                    opacity *= 0.3 // 飞白区域更透明
                }
            }
            
            // 起笔收笔效果
            if progress < 0.1 {
                // 起笔阶段：逐渐变不透明
                opacity *= (progress / 0.1)
            } else if progress > 0.9 {
                // 收笔阶段：逐渐变透明
                opacity *= ((1.0 - progress) / 0.1)
            }
            
            return PKStrokePoint(
                location: point.location,
                timeOffset: point.timeOffset,
                size: point.size,
                opacity: opacity,
                force: point.force,
                azimuth: point.azimuth,
                altitude: point.altitude
            )
        }
    }
    
    /// 创建墨迹晕染效果
    public static func createInkBleedingEffect(for stroke: PKStroke,
                                              config: BrushCalligraphyConfig) -> [PKStroke] {
        guard config.enableInkBleeding && config.brushType.isBrushType else {
            return []
        }
        
        var additionalStrokes: [PKStroke] = []
        let points = Array(stroke.path)
        
        if points.count > 1 {
            for offsetIndex in 1...2 {
                let offsetAmount = CGFloat(offsetIndex) * 0.5
                
                let offsetPoints = points.map { point in
                    // 轻微偏移和放大
                    return PKStrokePoint(
                        location: CGPoint(
                            x: point.location.x + offsetAmount,
                            y: point.location.y + offsetAmount
                        ),
                        timeOffset: point.timeOffset,
                        size: CGSize(
                            width: point.size.width * (1.2 + CGFloat(offsetIndex) * 0.1),
                            height: point.size.height * (1.2 + CGFloat(offsetIndex) * 0.1)
                        ),
                        opacity: point.opacity * (0.3 / CGFloat(offsetIndex)),
                        force: point.force,
                        azimuth: point.azimuth,
                        altitude: point.altitude
                    )
                }
                
                let offsetPath = PKStrokePath(controlPoints: offsetPoints, creationDate: Date())
                let offsetStroke = PKStroke(ink: stroke.ink, path: offsetPath)
                additionalStrokes.append(offsetStroke)
            }
        }
        
        return additionalStrokes
    }
    
    /// 应用铅笔纹理效果
    public static func applyPencilTexture(_ points: [PKStrokePoint],
                                         config: BrushCalligraphyConfig) -> [PKStrokePoint] {
        return points.enumerated().map { index, point in
            let progress = CGFloat(index) / CGFloat(points.count - 1)
            
            // 铅笔效果：轻微的不均匀
            let randomVariation = CGFloat.random(in: 0.9...1.1)
            var opacity = point.opacity * config.brushOpacity * randomVariation
            
            // 铅笔尾迹效果
            if progress > 0.8 {
                opacity *= (1.0 - (progress - 0.8) / 0.2 * 0.5)
            }
            
            return PKStrokePoint(
                location: point.location,
                timeOffset: point.timeOffset,
                size: point.size,
                opacity: min(opacity, 1.0),
                force: point.force,
                azimuth: point.azimuth,
                altitude: point.altitude
            )
        }
    }
    
    /// 应用马克笔效果
    public static func applyMarkerEffect(_ points: [PKStrokePoint],
                                       config: BrushCalligraphyConfig) -> [PKStrokePoint] {
        return points.map { point in
            // 马克笔：恒定半透明
            return PKStrokePoint(
                location: point.location,
                timeOffset: point.timeOffset,
                size: point.size,
                opacity: config.brushOpacity,
                force: point.force,
                azimuth: point.azimuth,
                altitude: point.altitude
            )
        }
    }
}
