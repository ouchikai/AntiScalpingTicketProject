# AntiScalpingTicketProject

## 概要
このプロジェクトは、転売抑止機能付きデジタルチケットNFTコントラクト「AntiScalpingTicket」を実装しています。このコントラクトは、NFTチケットの発行、転売制限、KYC認証などの機能を提供します。

## ファイル構成
- **contracts/AntiScalpingTicket.sol**: AntiScalpingTicketコントラクトの実装。
- **scripts/deploy.js**: コントラクトをブロックチェーンにデプロイするためのスクリプト。
- **scripts/test.js**: コントラクトの機能をテストするためのスクリプト。
- **test/AntiScalpingTicket.test.js**: コントラクトのユニットテストを含むファイル。
- **package.json**: プロジェクトの依存関係やスクリプトを定義するnpm設定ファイル。
- **hardhat.config.js**: Hardhatの設定ファイル。

## セットアップ手順
1. リポジトリをクローンします。
   ```
   git clone <repository-url>
   cd AntiScalpingTicketProject
   ```

2. 依存関係をインストールします。
   ```
   npm install
   ```

3. コントラクトをデプロイします。
   ```
   npx hardhat run scripts/deploy.js --network <network-name>
   ```

4. テストを実行します。
   ```
   npx hardhat test
   ```

## 使用方法
- コントラクトの機能を利用するには、デプロイ後に提供されるアドレスを使用して、各機能を呼び出します。
- KYC認証や転売制限などの機能を活用して、安全なチケット取引を実現します。

## ライセンス
このプロジェクトはMITライセンスの下で提供されています。