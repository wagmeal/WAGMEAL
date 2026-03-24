//
//  DogProfile.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/07/12.
//
import Foundation
import FirebaseFirestoreSwift

struct DogProfile: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var birthDate: Date
    var gender: String
    var breed: String
    var sizeCategory: String  // ← 追加
    var createdAt: Date
    var updatedAt: Date?   // ← 追加（初回追加時にセット、以降更新時に上書き）
    // 追加: プロフィール画像のStorageパス（例: "users/<uid>/dogs/<dogId>.jpg"）
    var imagePath: String? = nil
    // アレルギーフラグ（10項目）：このワンちゃんがNGな成分
    var allergicChicken: Bool? = nil
    var allergicBeef: Bool? = nil
    var allergicPork: Bool? = nil
    var allergicLamb: Bool? = nil
    var allergicFish: Bool? = nil
    var allergicEgg: Bool? = nil
    var allergicDairy: Bool? = nil
    var allergicWheat: Bool? = nil
    var allergicCorn: Bool? = nil
    var allergicSoy: Bool? = nil
    // 削除フラグ（論理削除用）
    var isDeleted: Bool? = false
    // Equatableの実装（idベースで判定）
    static func == (lhs: DogProfile, rhs: DogProfile) -> Bool {
        lhs.id == rhs.id
    }
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case birthDate
        case gender
        case breed
        case sizeCategory
        case createdAt
        case updatedAt
        case imagePath
        case allergicChicken
        case allergicBeef
        case allergicPork
        case allergicLamb
        case allergicFish
        case allergicEgg
        case allergicDairy
        case allergicWheat
        case allergicCorn
        case allergicSoy
        case isDeleted
    }
}
