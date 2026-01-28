//
//  BrushCalligraphyEngine.swift
//  testFramwer
//
//  Created by feixiang on 2026/1/28.
//
//
//  BrushCalligraphyEngine.swift
//  testFramwer
//
//  Created by feixiang on 2026/1/28.
//

import UIKit
import PencilKit

// MARK: - 笔锋算法核心（增强版）
public class BrushCalligraphyEngine {
     var config: BrushCalligraphyConfig
    private var previousPoint: PKStrokePoint?
    private var previousTime: TimeInterval?
    
    public init(config: BrushCalligraphyConfig = BrushCalligraphyConfig()) {
        self.config = config
    }
    
    /// 重置状态（开始新的一笔时调用）
    public func reset() {
        previousPoint = nil
        previousTime = nil
    }
    
    /// 根据笔刷类型计算动态宽度
    public func calculateDynamicWidth(for currentPoint: PKStrokePoint) -> CGFloat {
        // 不同笔刷类型的宽度计算策略
        switch config.brushType {
        case .eraser:
            // 橡皮擦：固定宽度，无变化
            return config.baseWidth
            
        case .pen:
            // 普通笔：轻微宽度变化
            return calculatePenWidth(for: currentPoint)
            
        case .pencil:
            // 铅笔：模拟铅笔效果
            return calculatePencilWidth(for: currentPoint)
            
        case .marker:
            // 马克笔：较大宽度，轻微变化
            return calculateMarkerWidth(for: currentPoint)
            
        case .hardBrush, .softBrush, .calligraphyBrush:
            // 毛笔类：复杂变化
            return calculateBrushWidth(for: currentPoint)
        }
    }
    
    /// 毛笔宽度计算（核心算法）
    private func calculateBrushWidth(for currentPoint: PKStrokePoint) -> CGFloat {
        var width = config.baseWidth
        
        // 1. 压力影响（主要因素）
        let force = max(currentPoint.force, 0.1)
        let normalizedForce = min(force / 6.666, 1.0) // Apple Pencil最大压力约6.666
        let forceFactor = pow(normalizedForce, 0.7) // 非线性映射
        
        width += forceFactor * config.maxWidthRange * config.forceSensitivity
        
        // 2. 速度影响（如果启用）
        if config.enableSpeedEffect, let prevPoint = previousPoint, let prevTime = previousTime {
            let speed = calculateSpeed(currentPoint: currentPoint,
                                     previousPoint: prevPoint,
                                     previousTime: prevTime)
            
            // 速度影响范围：0.3~1.0倍（速度越快，乘数越小）
            let maxSpeed: CGFloat = 1000.0 // 定义最大速度阈值
            let normalizedSpeed = min(speed / maxSpeed, 1.0)
            let speedMultiplier = 1.0 - (0.7 * normalizedSpeed * config.speedSensitivity)
            width *= speedMultiplier
        }
        
        // 3. 方向影响（模拟侧锋效果）
        if config.enableDirectionEffect, let prevPoint = previousPoint {
            let directionFactor = calculateDirectionFactor(currentPoint: currentPoint,
                                                         previousPoint: prevPoint)
            width *= (1.0 + directionFactor * config.directionSensitivity)
        }
        
        // 4. 毛笔特有：起笔收笔变化
        let brushVariation = calculateBrushVariation(for: currentPoint)
        width *= brushVariation
        
        // 更新前一点数据
        previousPoint = currentPoint
        previousTime = currentPoint.timeOffset
        
        // 限制在合理范围
        return min(max(width, config.minWidth), config.maxWidth)
    }
    
    /// 普通笔宽度计算
    private func calculatePenWidth(for currentPoint: PKStrokePoint) -> CGFloat {
        // 普通笔主要受压力影响，变化较小
        let force = max(currentPoint.force, 0.1)
        let normalizedForce = min(force / 6.666, 1.0)
        let forceFactor = normalizedForce * 0.3 // 较小的压力影响
        
        return config.baseWidth + forceFactor * 3.0
    }
    
    /// 铅笔宽度计算
    private func calculatePencilWidth(for currentPoint: PKStrokePoint) -> CGFloat {
        // 铅笔效果：轻微的压力和速度影响
        var width = config.baseWidth
        
        // 压力影响
        let force = max(currentPoint.force, 0.1)
        let forceFactor = min(force / 6.666, 1.0) * 0.5
        width += forceFactor * 2.0
        
        // 轻微的速度影响
        if let prevPoint = previousPoint, let prevTime = previousTime {
            let speed = calculateSpeed(currentPoint: currentPoint,
                                     previousPoint: prevPoint,
                                     previousTime: prevTime)
            if speed > 500 {
                width *= 0.8 // 快速时变细
            }
        }
        
        previousPoint = currentPoint
        previousTime = currentPoint.timeOffset
        
        return width
    }
    
    /// 马克笔宽度计算
    private func calculateMarkerWidth(for currentPoint: PKStrokePoint) -> CGFloat {
        // 马克笔：固定为主，轻微变化
        var width = config.baseWidth
        
        // 轻微压力影响
        let force = max(currentPoint.force, 0.1)
        if force > 3.0 {
            width *= 1.2 // 压力大时稍宽
        }
        
        return width
    }
    
    /// 计算毛笔起笔收笔变化
    private func calculateBrushVariation(for currentPoint: PKStrokePoint) -> CGFloat {
        // 这个函数应该在处理整个笔画时调用，这里简化为基本变化
        guard let previousPoint = previousPoint else { return 1.0 }
        
        // 简化的起笔收笔逻辑
        let distance = hypot(currentPoint.location.x - previousPoint.location.x,
                           currentPoint.location.y - previousPoint.location.y)
        
        // 根据距离判断是否是起笔或收笔阶段
        if distance < 5.0 {
            return 0.7 // 起笔收笔阶段变细
        }
        
        return 1.0
    }
    
    /// 计算运笔速度
    private func calculateSpeed(currentPoint: PKStrokePoint,
                               previousPoint: PKStrokePoint,
                               previousTime: TimeInterval) -> CGFloat {
        let distance = hypot(currentPoint.location.x - previousPoint.location.x,
                           currentPoint.location.y - previousPoint.location.y)
        let timeDelta = CGFloat(currentPoint.timeOffset - previousTime)
        
        guard timeDelta > 0 else { return 0 }
        return distance / timeDelta
    }
    
    /// 计算方向因子（模拟侧锋）
    private func calculateDirectionFactor(currentPoint: PKStrokePoint,
                                         previousPoint: PKStrokePoint) -> CGFloat {
        let dx = currentPoint.location.x - previousPoint.location.x
        let dy = currentPoint.location.y - previousPoint.location.y
        
        // 计算运笔方向角度（弧度）
        let angle = atan2(dy, dx)
        
        // 计算笔尖方位角与运笔方向的关系
        let azimuth = currentPoint.azimuth
        
        // 侧锋效果：当笔尖方向与运笔方向垂直时，笔画变宽
        let angleDiff = abs(sin(angle - azimuth))
        return angleDiff * 0.5 // 返回0.0~0.5之间的因子
    }
    
    /// 批量处理笔画点，应用笔刷效果
    public func processStrokePoints(_ points: [PKStrokePoint]) -> [PKStrokePoint] {
        reset()
        
        // 计算每个点的动态宽度
        let widthAdjustedPoints = points.map { point in
            let newWidth = calculateDynamicWidth(for: point)
            
            // 根据笔刷类型调整不透明度
            var opacity = point.opacity * config.brushOpacity
            
            // 毛笔效果：随机飞白
            if config.brushType.isBrushType && config.enableDryBrushEffect {
                let randomValue = CGFloat.random(in: 0...1)
                if randomValue < 0.05 { // 5%的概率出现飞白
                    opacity *= 0.3
                }
            }
            
            return PKStrokePoint(
                location: point.location,
                timeOffset: point.timeOffset,
                size: CGSize(width: newWidth, height: newWidth),
                opacity: opacity,
                force: point.force,
                azimuth: point.azimuth,
                altitude: point.altitude
            )
        }
        
        // 应用纹理效果
        if config.enableTexture && config.brushTexture != nil {
            return BrushEffectApplier.applyBrushTexture(to: widthAdjustedPoints, config: config)
//            return BrushEffectApplier.applyBrushTexture(
//                to: widthAdjustedPoints,
//                texture: config.brushTexture,
//                type: config.brushType
//            )
        }
        
        return widthAdjustedPoints
    }
    
    /// 创建完整笔画（包含可能的效果笔画）
    public func createCompleteStroke(from originalStroke: PKStroke) -> [PKStroke] {
        let points = Array(originalStroke.path)
        let processedPoints = processStrokePoints(points)
        
        // 创建主笔画
        let newPath = PKStrokePath(controlPoints: processedPoints, creationDate: Date())
        let mainStroke = PKStroke(ink: originalStroke.ink, path: newPath)
        
        var strokes = [mainStroke]
        
        // 如果启用墨迹晕染，添加效果笔画
        if config.enableInkBleeding && config.brushType.isBrushType {
            let bleedingStrokes = BrushEffectApplier.createInkBleedingEffect(for: mainStroke, config: config)
            strokes.append(contentsOf: bleedingStrokes)
        }
        
        return strokes
    }
}

// MARK: - BrushType 扩展
extension BrushType {
    /// 判断是否为毛笔类型
    var isBrushType: Bool {
        return self == .hardBrush || self == .softBrush || self == .calligraphyBrush
    }
    
    /// 获取对应的默认配置
    var defaultConfig: BrushCalligraphyConfig {
        switch self {
        case .hardBrush: return .hardBrush
        case .softBrush: return .softBrush
        case .calligraphyBrush: return .calligraphyBrush
        case .pen: return .pen
        case .pencil: return .pencil
        case .marker: return .marker
        case .eraser: return .eraser
        }
    }
}
