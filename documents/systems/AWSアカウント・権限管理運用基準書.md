# AWSアカウント・権限管理運用基準書
## 基本セキュリティ運用方針
本システムのAWSアカウント管理は、セキュリティ・可用性・運用効率を重視し、以下の方針で運用します。

- **多要素認証（MFA）必須**: 全ユーザにMFA設定を必須とします。
- **ゼロトラスト・セキュリティ運用**: ネットワークフローは送信前に認証・暗号化を行い、アクセス制御・可視化を徹底します。エンドポイントでの認証、プライベートPKIの活用、デバイスの定期的なスキャン・パッチ・ローテーションを実施します。
- **rootユーザの利用方針**: rootユーザは緊急時のみ利用し、通常運用はIAM Identity Center経由のユーザで実施します。
- **権限昇格の運用ルール**: 開発者へのAWS権限付与は原則「読み取り専用グループ（ReadOnlyAccess）」のみとし、PowerUserAccessが必要な作業は管理者が実施します。やむを得ず開発者がPowerUserAccessを必要とする場合は、管理者判断のもと一時的に昇格し、作業完了後は速やかに権限を戻します。

## 1. AWSアカウント管理方針

本システムのAWSアカウント管理は、以下の方針で運用しています。

- AWS OrganizationsとAWS IAM Identity Center（旧AWS SSO）を連携し、組織的なアカウント・権限管理を実施
- AWSアカウントはOrganizationsのroot直下に以下の構成で管理
    - 管理アカウント: deidra-project
    - 本番環境: ris-prod
    - ステージング環境: ris-stg
    - 開発環境: ris-dev
- 各アカウントの権限付与・ユーザ管理はIAM Identity Center経由で一元化
- rootユーザは緊急時のみ利用し、通常運用はIdentity Center経由のユーザで実施

この構成により、環境ごとの分離・権限管理の厳格化・運用効率化を図っています。

## 2. AWS Identity Center（旧AWS SSO）運用補足

各AWSアカウント環境ごとに、Identity Center上で以下のグループを作成し、公式の許可セット（Permission Set）をアタッチしています。

- **rif-prod-read-only**: 本番用の読み取り専用グループ（ReadOnlyAccess付与）
- **rif-prod-power**: 本番用のパワーユーザーグループ（PowerUserAccess付与）
- **rif-prod-admin**: 本番用の管理者グループ（AdministratorAccess付与）

各グループは手動で管理され、AWS公式のPermission Set（AdministratorAccess, ReadOnlyAccess, PowerUserAccess）を利用しています。
これにより、環境ごと・権限レベルごとに厳格なアクセス制御を実現しています。

## 3. 開発者への権限付与方針

開発者に対するAWS権限付与は、以下の運用方針としています。

- 通常は「読み取り専用グループ（ReadOnlyAccess）」のみ付与
- PowerUserAccess（パワーユーザー権限）が必要な作業は、原則として管理者が実施
- やむを得ず開発者がPowerUserAccessを必要とする場合は、管理者判断のもと、該当ユーザを一時的にパワー権限グループへ手動追加
- 作業完了後は速やかにパワー権限グループから除外

この運用により、最小権限の原則を徹底しつつ、必要時のみ柔軟な権限昇格を可能としています。

## 4. シークレット情報の管理（Parameter Store利用）

### 方針
- シークレット情報（APIキー、トークン、認証情報など）は、AWS Systems Manager Parameter Store（以下、Parameter Store）に手動で登録・保持します。
- Parameter Storeは暗号化（KMS）を有効にし、必要最小限のIAM権限で取得できるようにします。
- シークレットはリポジトリや環境変数などの平文での管理を行わず、必ずParameter Store経由で取得する運用とします。

### 登録（手動）の手順（例）
1. AWSコンソールにログインし、Systems Manager → Parameter Store を開く
2. [Create parameter] をクリック
3. Name: `/myapp/PROD/DB_PASSWORD` のように環境・用途が分かるパスで命名
4. Type: SecureString を選択
5. KMS key source: Default AWS key (aws/ssm) または専用のカスタマー管理キー（CMK）を指定
6. Value: シークレットの値を入力して作成

CLIから登録する例:
```sh
aws ssm put-parameter \
    --name "/myapp/PROD/DB_PASSWORD" \
    --value "your-db-password" \
    --type "SecureString" \
    --overwrite
```

### Lambda / EC2 からの取得方法（AWS SDK）
- LambdaやEC2内のアプリケーションでは、AWS SDKを使用してParameter Storeからシークレットを取得します。下記はNode.js（aws-sdk v3）の例です。

Node.js (aws-sdk v3) の例:
```js
import { SSMClient, GetParameterCommand } from "@aws-sdk/client-ssm";

const client = new SSMClient({ region: process.env.AWS_REGION });

async function getSecret(name) {
    const cmd = new GetParameterCommand({ Name: name, WithDecryption: true });
    const res = await client.send(cmd);
    return res.Parameter?.Value;
}

// 使用例
(async () => {
    const dbPassword = await getSecret('/myapp/PROD/DB_PASSWORD');
    console.log('got secret length:', dbPassword?.length);
})();
```

Python (boto3) の例:
```py
import boto3

ssm = boto3.client('ssm')

def get_secret(name):
        res = ssm.get_parameter(Name=name, WithDecryption=True)
        return res['Parameter']['Value']

db_password = get_secret('/myapp/PROD/DB_PASSWORD')
print('got secret length:', len(db_password))
```

### IAM ポリシー（最小権限）
- LambdaやEC2のインスタンスプロファイルにアタッチする最小権限のポリシー例:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameter",
                "ssm:GetParameters",
                "ssm:GetParametersByPath"
            ],
            "Resource": [
                "arn:aws:ssm:ap-northeast-1:123456789012:parameter/myapp/*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt"
            ],
            "Resource": "arn:aws:kms:ap-northeast-1:123456789012:key/your-cmk-id"
        }
    ]
}
```

※ 上記ARNやリージョン、アカウントID、CMKは環境に合わせて置き換えてください。

### 運用上の注意点
- Parameter Store の値はバージョン管理されます。値を更新すると古いバージョンは保持されますが、不要な古いバージョンは定期的に整理してください。
- シークレットアクセスの監査を有効にするため、CloudTrailで Systems Manager と KMS の操作を記録してください。
- シークレットを読み取る権限は最小限に絞り、アクセスが必要なリソースだけに付与してください。

