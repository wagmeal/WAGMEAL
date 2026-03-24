//
//  DogfoodApp.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/06/20.
//
import Foundation
import FirebaseFirestoreSwift

struct DogFood: Identifiable, Codable, Hashable {
    @DocumentID var id: String?   // ← これが必要
    let name: String
    /// ブランド名（未移行データに配慮してオプショナル）
    let brand: String?
    let imagePath: String
    let description: String
    let summary: String
    let keywords: [String]
    let ingredients: String?
    let homepageURL: String?
    let amazonURL: String?
    let yahooURL: String?
    let rakutenURL: String?
    // アレルギーフラグ（10項目）
    let hasChicken: Bool?
    let hasBeef: Bool?
    let hasPork: Bool?
    let hasLamb: Bool?
    let hasFish: Bool?
    let hasEgg: Bool?
    let hasDairy: Bool?
    let hasWheat: Bool?
    let hasCorn: Bool?
    let hasSoy: Bool?
    /// 表示用ブランド名（未設定の場合は空）
    var brandDisplay: String {
        brand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

enum IngredientFilter: String, CaseIterable, Identifiable {
    case chicken
    case beef
    case pork
    case lamb
    case fish
    case egg
    case dairy
    case wheat
    case corn
    case soy

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chicken: return "鶏肉"
        case .beef:    return "牛肉"
        case .pork:    return "豚肉"
        case .lamb:    return "羊/ラム"
        case .fish:    return "魚"
        case .egg:     return "卵"
        case .dairy:   return "乳製品"
        case .wheat:   return "小麦"
        case .corn:    return "トウモロコシ"
        case .soy:     return "大豆"
        }
    }
}

extension DogFood {
    func contains(_ filter: IngredientFilter) -> Bool {
        switch filter {
        case .chicken: return hasChicken ?? false
        case .beef:    return hasBeef ?? false
        case .pork:    return hasPork ?? false
        case .lamb:    return hasLamb ?? false
        case .fish:    return hasFish ?? false
        case .egg:     return hasEgg ?? false
        case .dairy:   return hasDairy ?? false
        case .wheat:   return hasWheat ?? false
        case .corn:    return hasCorn ?? false
        case .soy:     return hasSoy ?? false
        }
    }
}
