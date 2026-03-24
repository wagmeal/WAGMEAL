//
//  MocData.swift
//  Dogfood
//
//  Created by takumi kowatari on 2025/08/05.
//
//

import Foundation
import SwiftUI

struct PreviewMockData {
    // MARK: - モック犬データ
    static let dogs: [DogProfile] = [
        DogProfile(
            id: "dog_001",
            name: "ココ",
            birthDate: Calendar.current.date(from: DateComponents(year: 2020, month: 4, day: 10)) ?? Date(),
            gender: "女の子",
            breed: "マルプー",
            sizeCategory: "小型犬",
            createdAt: Date(),
            allergicChicken: true,
            allergicBeef: false,
            allergicPork: false,
            allergicLamb: true,
            allergicFish: false,
            allergicEgg: false,
            allergicDairy: true,
            allergicWheat: false,
            allergicCorn: true,
            allergicSoy: false
        ),
        DogProfile(
            id: "dog_002",
            name: "モモ",
            birthDate: Calendar.current.date(from: DateComponents(year: 2019, month: 12, day: 1)) ?? Date(),
            gender: "男の子",
            breed: "コーギー",
            sizeCategory: "中型犬",
            createdAt: Date(),
            allergicChicken: false,
            allergicBeef: true,
            allergicPork: false,
            allergicLamb: false,
            allergicFish: true,
            allergicEgg: false,
            allergicDairy: false,
            allergicWheat: true,
            allergicCorn: false,
            allergicSoy: true
        )
    ]
    
    // MARK: - モックユーザーデータ
    struct MockUserProfile {
        let username: String
        let email: String
        let birthday: Date
        let gender: String
    }

    static let userProfile = MockUserProfile(
        username: "たくみ",
        email: "takumi@example.com",
        birthday: Calendar.current.date(from: DateComponents(year: 1995, month: 4, day: 1)) ?? Date(),
        gender: "その他"
    )

    // MARK: - モックドッグフードデータ
    static let dogFood: [DogFood] = [
        DogFood(
            id: "food_001",
            name: "プレミアムドッグプレミアムプレミアムpremium",
            brand: "Royal Canin",
            imagePath: "https://thumbnail.image.rakuten.co.jp/@0_mall/finepet/cabinet/10900730/imgrc0091744026.jpg?_ex=128x128",
            description: "高品質のドッグフードです",
            summary: "栄養バランス抜群",
            keywords: ["オーガニック", "プレミアム"],
            ingredients: "ラム生肉、生サーモン、ドライフィッシュ、えんどう豆、...",
            homepageURL: "https://example.com/food_001",
            amazonURL: "https://www.amazon.co.jp/dp/B000000001",
            yahooURL: "https://store.shopping.yahoo.co.jp/example/food001.html",
            rakutenURL: "https://item.rakuten.co.jp/example/food001/",
            hasChicken: true,
            hasBeef: true,
            hasPork: true,
            hasLamb: true,
            hasFish: true,
            hasEgg: true,
            hasDairy: true,
            hasWheat: true,
            hasCorn: true,
            hasSoy: true
        ),
        DogFood(
            id: "food_002",
            name: "プレミアムドッグ",
            brand: "Hill's",
            imagePath: "https://thumbnail.image.rakuten.co.jp/@0_mall/petwill30/cabinet/03246444/imgrc0078090741.jpg?_ex=128x128",
            description: "高品質のドッグフードです",
            summary: "栄養バランス抜群",
            keywords: ["オーガニック", "プレミアム"],
            ingredients: "ラム生肉、生サーモン、ドライフィッシュ、えんどう豆、...",
            homepageURL: "https://example.com/food_002",
            amazonURL: "https://www.amazon.co.jp/dp/B000000002",
            yahooURL: nil,
            rakutenURL: "https://item.rakuten.co.jp/example/food002/",
            hasChicken: true,
            hasBeef: false,
            hasPork: false,
            hasLamb: true,
            hasFish: true,
            hasEgg: false,
            hasDairy: false,
            hasWheat: false,
            hasCorn: false,
            hasSoy: false
        ),
        DogFood(
            id: "food_003",
            name: "プレミアムドッグ",
            brand: "Nutro",
            imagePath: "testimage/kiaora1.jpg",
            description: "高品質のドッグフードです",
            summary: "栄養バランス抜群",
            keywords: ["オーガニック", "プレミアム"],
            ingredients: "ラム生肉、生サーモン、ドライフィッシュ、えんどう豆、...",
            homepageURL: nil,
            amazonURL: "https://www.amazon.co.jp/dp/B000000003",
            yahooURL: "https://store.shopping.yahoo.co.jp/example/food003.html",
            rakutenURL: nil,
            hasChicken: false,
            hasBeef: false,
            hasPork: false,
            hasLamb: true,
            hasFish: true,
            hasEgg: false,
            hasDairy: false,
            hasWheat: false,
            hasCorn: false,
            hasSoy: false
        ),
        DogFood(
            id: "food_004",
            name: "ナチュラルビーフ",
            brand: "Acana",
            imagePath: "testimage/kiaora1.jpg",
            description: "自然派素材のフード",
            summary: "素材にこだわり",
            keywords: ["ナチュラル", "ビーフ"],
            ingredients: "ラム生肉、生サーモン、ドライフィッシュ、えんどう豆、...",
            homepageURL: "https://example.com/food_004",
            amazonURL: nil,
            yahooURL: "https://store.shopping.yahoo.co.jp/example/food004.html",
            rakutenURL: "https://item.rakuten.co.jp/example/food004/",
            hasChicken: false,
            hasBeef: true,
            hasPork: false,
            hasLamb: false,
            hasFish: false,
            hasEgg: false,
            hasDairy: false,
            hasWheat: false,
            hasCorn: false,
            hasSoy: false
        )
    ]
    
    // MARK: - モック評価データ（全項目入り）
    struct MockEvaluation {
        let dogFoodId: String
        let dogID: String
        let dogName: String
        let breed: String
        let sizeCategory: String
        let overall: Int
        let dogSatisfaction: Int
        let ownerSatisfaction: Int
        let comment: String
        let isReviewPublic: Bool
        let timestamp: Date
        let feedingStartDate: Date?
        let feedingEndDate: Date?
        let userId: String
        
        var ratings: [String: Int] {
            return [
                "総合評価": overall,
                "わんちゃんの満足度": dogSatisfaction,
                "飼い主の満足度": ownerSatisfaction
            ]
        }
        
        var asDictionary: [String: Any] {
            return [
                "dogFoodId": dogFoodId,
                "dogID": dogID,
                "dogName": dogName,
                "breed": breed,
                "sizeCategory": sizeCategory,
                "overall": overall,
                "dogSatisfaction": dogSatisfaction,
                "ownerSatisfaction": ownerSatisfaction,
                "comment": comment,
                "isReviewPublic": isReviewPublic,
                "timestamp": timestamp,
                "feedingStartDate": feedingStartDate as Any,
                "feedingEndDate": feedingEndDate as Any,
                "userId": userId,
                "ratings": ratings
            ]
        }
    }
    
    static let evaluations: [MockEvaluation] = [
        MockEvaluation(
            dogFoodId: "food_001",
            dogID: "dog_001",
            dogName: "ココ",
            breed: "マルプー",
            sizeCategory: "小型犬",
            overall: 4,
            dogSatisfaction: 5,
            ownerSatisfaction: 4,
            comment: "食いつき抜群で毛並みも良くなった",
            isReviewPublic: true,
            timestamp: Date(),
            feedingStartDate: Date().addingTimeInterval(-86400 * 10),
            feedingEndDate: nil,
            userId: "user_001"
        ),
        MockEvaluation(
            dogFoodId: "food_001",
            dogID: "dog_003",
            dogName: "メロ",
            breed: "マルプー",
            sizeCategory: "小型犬",
            overall: 3,
            dogSatisfaction: 5,
            ownerSatisfaction: 4,
            comment: "食いつき抜群で毛並みも良くなった",
            isReviewPublic: false,
            timestamp: Date(),
            feedingStartDate: Date().addingTimeInterval(-86400 * 10),
            feedingEndDate: nil,
            userId: "user_001"
        ),
        MockEvaluation(
            dogFoodId: "food_001",
            dogID: "dog_004",
            dogName: "ポチ",
            breed: "ゴールデンレトリバー",
            sizeCategory: "大型犬",
            overall: 5,
            dogSatisfaction: 5,
            ownerSatisfaction: 2,
            comment: "食いつき抜群で毛並みも良くなった",
            isReviewPublic: true,
            timestamp: Date(),
            feedingStartDate: Date().addingTimeInterval(-86400 * 10),
            feedingEndDate: nil,
            userId: "user_001"
        ),
        MockEvaluation(
            dogFoodId: "food_002",
            dogID: "dog_002",
            dogName: "モモ",
            breed: "コーギー",
            sizeCategory: "中型犬",
            overall: 3,
            dogSatisfaction: 3,
            ownerSatisfaction: 3,
            comment: "普通。可もなく不可もなく",
            isReviewPublic: true,
            timestamp: Date().addingTimeInterval(-86400),
            feedingStartDate: Date().addingTimeInterval(-86400 * 10),
            feedingEndDate: nil,
            userId: "user_002"
        ),
        MockEvaluation(
            dogFoodId: "food_003",
            dogID: "dog_001",
            dogName: "ココ",
            breed: "マルプー",
            sizeCategory: "小型犬",
            overall: 2,
            dogSatisfaction: 2,
            ownerSatisfaction: 2,
            comment: "うんちがゆるくなったので合わなかったかも",
            isReviewPublic: true,
            timestamp: Date().addingTimeInterval(-86400 * 2),
            feedingStartDate: Date().addingTimeInterval(-86400 * 10),
            feedingEndDate: nil,
            userId: "user_003"
        ),
        MockEvaluation(
            dogFoodId: "food_004",
            dogID: "dog_002",
            dogName: "モモ",
            breed: "コーギー",
            sizeCategory: "中型犬",
            overall: 5,
            dogSatisfaction: 5,
            ownerSatisfaction: 5,
            comment: "ずっとこれを食べてます！",
            isReviewPublic: true,
            timestamp: Date().addingTimeInterval(-86400 * 3),
            feedingStartDate: Date().addingTimeInterval(-86400 * 10),
            feedingEndDate: nil,
            userId: "user_004"
        ),
        MockEvaluation(
            dogFoodId: "food_001",
            dogID: "dog_002",
            dogName: "モモ",
            breed: "チワワ",
            sizeCategory: "小型犬",
            overall: 4,
            dogSatisfaction: 4,
            ownerSatisfaction: 5,
            comment: "飼い主的には扱いやすく、続けたい",
            isReviewPublic: true,
            timestamp: Date().addingTimeInterval(-86400 * 4),
            feedingStartDate: Date().addingTimeInterval(-86400 * 10),
            feedingEndDate: nil,
            userId: "user_005"
        )
    ]
    
    // MARK: - モックお気に入り
        struct MockFavorite {
            let userId: String
            let dogFoodId: String
            let createdAt: Date
        }

        // user_001 が 001,004 をお気に入り、user_002 が 002 をお気に入り…など
        static let favorites: [MockFavorite] = [
            MockFavorite(userId: "user_001", dogFoodId: "food_001", createdAt: Date().addingTimeInterval(-60)),
            MockFavorite(userId: "user_001", dogFoodId: "food_004", createdAt: Date().addingTimeInterval(-120)),
            MockFavorite(userId: "user_002", dogFoodId: "food_002", createdAt: Date().addingTimeInterval(-300)),
            MockFavorite(userId: "user_003", dogFoodId: "food_003", createdAt: Date().addingTimeInterval(-600))
        ]

        // ユーティリティ：ユーザーのお気に入りID一覧
        static func favoriteIds(for userId: String) -> [String] {
            favorites
                .filter { $0.userId == userId }
                .sorted { $0.createdAt > $1.createdAt } // 新しい順など
                .map { $0.dogFoodId }
        }

        // ユーティリティ：ユーザーのお気に入り DogFood 一覧
        static func favoriteDogFoods(for userId: String) -> [DogFood] {
            let ids = Set(favoriteIds(for: userId))
            return dogFood.filter { ids.contains($0.id ?? "") }
        }
}
