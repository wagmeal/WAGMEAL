# WAGMEAL（ワグミール）

> 愛犬に合うドッグフード選びに、もう迷わない。

WAGMEAL は、愛犬ごとにドッグフードの記録・評価ができる iOS アプリです。
「このフード、本当に合っているのかな？」という日々の悩みを、食べた記録と評価を残すことで、少しずつ解決していきます。

---

## 主な機能

| 機能 | 説明 |
|------|------|
| **ドッグフード検索** | 名前・ブランド・成分（10種アレルゲン）・カロリーなどでフィルタリング |
| **愛犬プロフィール管理** | 複数の犬を登録。犬種・体格・アレルギー情報をまとめて管理 |
| **フード記録・評価** | 食いつき・体調・コスパなど5項目で評価。給与期間も記録 |
| **お気に入り登録** | 気になるフードをワンタップで保存 |
| **ランキング** | ユーザーの評価をもとに、人気フードをランキング表示 |
| **ゲスト利用** | 未ログインでも検索・ランキング閲覧が可能 |

---


## 技術スタック

### アーキテクチャ
- **MVVM** + `@EnvironmentObject` によるアプリ全体の状態共有
- `@MainActor` による UI 更新の安全な非同期処理
- `ObservableObject` + `@Published` でリアクティブなデータバインディング

### フレームワーク・ライブラリ

| カテゴリ | 使用技術 |
|----------|----------|
| UI | SwiftUI |
| 認証 | Firebase Authentication（メール/パスワード・Google・Apple） |
| データベース | Cloud Firestore（リアルタイムリスナー） |
| ストレージ | Firebase Storage（犬プロフィール画像・フード画像） |
| アナリティクス | Firebase Analytics |
| 画像 | カスタム `actor` ベースのインメモリキャッシュ + ダウンサンプリング |
| パッケージ管理 | Swift Package Manager |

### 対応環境
- iOS 16.0 以上
- Xcode 15 以上
- Swift 5.9 以上

---

## プロジェクト構成

```
WAGMEAL/
├── Main/               # App エントリーポイント、タブルーター、共通モデル
│   ├── DogFoodApp.swift
│   ├── MainTabView.swift
│   ├── SplashView.swift
│   └── DogFood.swift / Evaluation.swift
│
├── Login/              # 認証フロー（メール・Google・Apple Sign-In）
│   ├── AuthViewModel.swift
│   ├── LoginView.swift
│   └── ProfileSetupView.swift
│
├── DogProfile/         # 愛犬管理・評価履歴
│   ├── DogProfileViewModel.swift
│   ├── MyDogView.swift
│   ├── DogDetailView.swift
│   └── DogFormView.swift
│
├── Search/             # フード検索・フィルタリング
│   ├── DogFoodViewModel.swift
│   ├── EvaluationAverage.swift
│   └── DogFoodPage/
│
├── Favorites/          # お気に入り管理
├── Ranking/            # ランキング表示
└── Settings/           # アカウント設定・利用規約
```

---

## セットアップ

> **注意**: `GoogleService-Info.plist` はセキュリティ上リポジトリに含まれていません。
> 動作確認には Firebase プロジェクトのセットアップが必要です。

### 1. リポジトリのクローン

```bash
git clone https://github.com/wagmeal/WAGMEAL.git
cd WAGMEAL
```

### 2. Firebase の設定

1. [Firebase Console](https://console.firebase.google.com/) でプロジェクトを作成
2. iOS アプリを追加（Bundle ID: プロジェクトに合わせて設定）
3. `GoogleService-Info.plist` をダウンロードし、`WAGMEAL/` ディレクトリに配置
4. Firebase Console で以下のサービスを有効化:
   - Authentication（メール/パスワード・Google・Apple）
   - Cloud Firestore
   - Cloud Storage
   - Analytics

### 3. Xcode でビルド

```bash
open WAGMEAL.xcodeproj
```

Swift Package Manager の依存関係は Xcode が自動解決します。

---

## 設計上のこだわり

### ゲストファースト設計
未ログインでも検索・ランキング閲覧ができるよう設計。ログインが必要な機能（記録・お気に入り）は、操作時に自然なタイミングでサインインを促します。

### ソフトデリート
愛犬を削除してもデータは `isDeleted = true` でマークするだけで、評価記録は保持されます。過去の記録を振り返れる UX を重視しました。

### 画像読み込みの最適化
Firebase Storage の画像を `actor` ベースのスレッドセーフなキャッシュで管理。ダウンサンプリングとプリデコードでスクロール時のパフォーマンスを改善しています。

### アレルギー対応フィルター
チキン・牛肉・豚肉・ラム・魚・卵・乳製品・小麦・とうもろこし・大豆の10種類のアレルゲンを「含む」「含まない」両方向でフィルタリング可能。アレルギーのある犬でも安心してフード探しができます。

### リアルタイム同期
お気に入りや評価データは Firestore のリアルタイムリスナーで即時反映。複数デバイス間でも常に最新状態を保ちます。

---

## Firestore データ構造

```
users/{uid}
  └── dogs/{dogId}          # 愛犬プロフィール
  └── favorites/{foodId}    # お気に入りフード

dogfood/{foodId}            # ドッグフードマスタ（グローバル）

evaluations/{evalId}        # 評価データ（全ユーザー共通）
```

---

## 今後の改善予定

- [ ] Firestore クエリのページネーション対応
- [ ] プッシュ通知（給与期間の終了リマインダー）
- [ ] 体重・健康記録との連携

---

## 作者

**Takumi Kowatari**
- GitHub: [@wagmeal](https://github.com/wagmeal)

---

## ライセンス

このリポジトリのコードは個人のポートフォリオ目的で公開しています。
商用利用・再配布はご遠慮ください。
