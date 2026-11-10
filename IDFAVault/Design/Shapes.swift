//
//  Shapes.swift
//  IDFAVault
//
//  角丸を使わないための形（仕様書 6.4）。カード・ボタン・アイコン台は ChamferedRect、バッジは PointedCapsule で作る。
//

import SwiftUI

/// 四隅を斜めに落とした八角形（面取り）。面取りの大きさだけ変えて使い回す。
/// 状態を持たない値の型なので MainActor に閉じ込めない（Xcode 27 では、Shape への準拠が MainActor をまたぐとエラーになる）
nonisolated struct ChamferedRect: InsettableShape {
    var chamfer: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: insetAmount, dy: insetAmount)
        // 縁の内側に重ねる形は、縁の太さぶん斜辺が内側に寄るので、面取りもそのぶん小さくする（tan 22.5° ≒ 0.414）
        let corner = min(max(chamfer - insetAmount * 0.414, 0), min(rect.width, rect.height) / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + corner))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - corner))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> ChamferedRect {
        var shape = self
        shape.insetAmount += amount
        return shape
    }
}

/// 左右を尖らせた六角形（バッジ）
nonisolated struct PointedCapsule: Shape {
    var point: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        let point = min(point, rect.width / 2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + point, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - point, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX - point, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + point, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
        path.closeSubpath()
        return path
    }
}
