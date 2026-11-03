# STApplePurchase

基于 StoreKit 2 的内购（IAP）工具包，零外部依赖，iOS 16+。

## 能力范围

- 商品查询、购买、恢复购买、交易更新监听（`Transaction.updates`）。
- 本地签名校验：所有交易都先经过 StoreKit 2 的 `VerificationResult` 校验，未通过直接抛 `STApplePurchaseError.verificationFailed`，这是强制网关。
- 订阅状态查询（`Product.SubscriptionInfo.status(for:)`）。
- 两个可选协议钩子，由宿主 App 自己实现，**包内不包含任何具体网络请求、不假设任何后端 API 契约**：
  - `STApplePurchaseReceiptValidating`：把本地已校验交易的 `signedPayload`（JWS）发给自有后端做二次校验。
  - `STApplePurchasePurchaseStatusSyncing`：把购买/订阅状态同步给自有后端。

## 用法

```swift
import STApplePurchase

let manager = STApplePurchaseManager.shared
manager.receiptValidator = MyBackendReceiptValidator()
manager.statusSyncer = MyBackendStatusSyncer()
manager.logger = MyLogAdapter()

manager.startListeningForTransactionUpdates()

let products = try await manager.loadProducts(productIDs: ["com.example.pro_monthly"])
let result = try await manager.purchase(products[0])

switch result {
case .success(let transaction):
    // 本地校验已通过；是否需要再做一次后端校验由宿主决定：
    try await manager.validateReceiptIfNeeded(for: transaction)
case .userCancelled, .pending:
    break
}
```

## 组合方式

- `receiptValidator` 不会被自动调用。本地签名校验通过后，是否需要再发给自有后端校验，由宿主在恰当的时机（如解锁内容前）主动调用 `validateReceiptIfNeeded(for:)`。
- `statusSyncer` 在每次本地校验成功的交易（购买 / 恢复 / 监听更新）之后自动调用一次；失败只通过 `logger` 记录，不会抛出或阻断主流程。

## 测试边界

单测只覆盖纯 Swift 逻辑（错误描述、模型映射、协议 mock 行为）。以下真实 StoreKit 交互无法在普通 XCTest 里跑通，需要 `.storekit` 配置文件 + `StoreKitTest`（`import StoreKitTest` / `SKTestSession`）或真机/模拟器手动验证，留作后续集成测试的 follow-up：

- `Product.products(for:)`
- `Product.purchase()`
- `Transaction.updates`
- `AppStore.sync()`

## 接入 Demo（未实现）

本次未在 `STBaseProjectExample` 中新增演示页面。接入时需要：添加 `.storekit` 配置文件、在 scheme 里启用它、并准备一组测试商品 ID。
