//
//  STApplePurchaseLogging.swift
//  STApplePurchase
//
//  Created by 寒江孤影 on 2026/11/3.
//

import Foundation

/// 可选的日志注入点，宿主可以接到自己的日志系统（如 STLog），
/// 不注入则 STApplePurchase 内部保持静默。
public protocol STApplePurchaseLogging {
    func log(_ message: String)
}
