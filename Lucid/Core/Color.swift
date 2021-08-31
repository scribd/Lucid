//
//  Color.swift
//  Lucid
//
//  Created by Théophane Rupin on 1/4/19.
//  Copyright © 2019 Scribd. All rights reserved.
//

import Foundation

#if canImport(UIKit)
import UIKit

private extension UIColor {

    enum HexNotation: Int {
        case hexPair = 6 // #aabbcc
        case shortHex = 3 // #abc
    }

    convenience init(hex: String) {
        let trimmedHex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        let hexValue = trimmedHex.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0

        guard let hexNotation = HexNotation(rawValue: hexValue.count) else {
            self.init(white: 0, alpha: 1)
            return
        }

        guard Scanner(string: hexValue).scanHexInt64(&rgb) else {
            self.init(white: 0, alpha: 1)
            return
        }

        switch hexNotation {
        case .hexPair:
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        case .shortHex:
            r = CGFloat((rgb & 0xF00) >> 8) / 15.0
            g = CGFloat((rgb & 0x0F0) >> 4) / 15.0
            b = CGFloat(rgb & 0x00F) / 15.0
        }

        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
#endif

public struct Color: Equatable, Hashable {

    public let hex: String

    public init(hex: String) {
        self.hex = hex
    }

    #if canImport(UIKit)
    public var colorValue: UIColor {
        return UIColor(hex: hex)
    }
    #endif
}

@objc public final class SCColorObjc: NSObject {
    public let value: Color

    public init(_ value: Color) {
        self.value = value
    }

    @objc public var hex: String {
        return value.hex
    }
}
