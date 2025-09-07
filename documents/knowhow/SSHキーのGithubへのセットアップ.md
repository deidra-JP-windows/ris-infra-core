# Windows 11環境でED25519鍵をパスワードありで発行し、GitHubのSSH Keysに登録する手順

1. **PowerShellまたはコマンドプロンプトを開き、ユーザーディレクトリ直下に移動**
```sh
例
cd /
cd C:\Users\Admin
```

2. **ED25519形式でパスワードありのSSH鍵を作成**
```sh
ssh-keygen -t ed25519
```
※ コマンド実行時に「Enter passphrase (empty for no passphrase):」と表示されたら、任意のパスワードを入力してください。

3. **公開鍵の内容を手動でコピー**
エクスプローラー等で `%USERPROFILE%\.ssh\id_ed25519.pub` を開き、内容をすべてコピーします。

4. **GitHubにログインし、SSH鍵を登録**
   - GitHubの右上アイコン → [Settings] → [SSH and GPG keys] → [New SSH key]
   - Titleに任意の名前、Keyに先ほどコピーした公開鍵を貼り付けて [Add SSH key] をクリック

5. **.ssh/configファイルを作成・編集し、以下を記載**
```config
Host github.com
	IdentityFile ~/.ssh/id_ed25519
	User git
```

6. **接続確認**
```sh
ssh -T git@github.com
```
"Hi ユーザー名! You've successfully authenticated..." と表示されれば成功です。
