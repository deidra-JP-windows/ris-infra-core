# Windows 11環境でED25519鍵をパスワードありで発行し、GitHubのSSH Keysに登録する手順
Visual Studio Code（VSCode）での作業を推奨しています。

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
※ 作成後ユーザ直下に .ssh フォルダがない場合、手動で作成しコマンド実行により作成されたファイルを移動させてください。
※ <img width="680" height="174" alt="image" src="https://github.com/user-attachments/assets/253cbc0e-6abc-45d4-b8a4-7113542fa072" />
3. **公開鍵の内容を手動でコピー**
Visual Studio Code（VSCode）等で `%USERPROFILE%\.ssh\id_ed25519.pub` を開き、内容をすべてコピーします。

4. **GitHubにログインし、SSH鍵を登録**
   - GitHubの右上アイコン → [Settings] → [SSH and GPG keys] → [New SSH key]
   - Titleに任意の名前、Keyに先ほどコピーした公開鍵を貼り付けて [Add SSH key] をクリック

5. **.ssh/configファイルを作成・編集し、以下を記載**
※ 拡張子は不要です。Visual Studio Code（VSCode）で開くと画像にあるボタンから作成できます。
※ <img width="841" height="232" alt="image" src="https://github.com/user-attachments/assets/ac420d85-f64b-43ba-b31c-3a0dc61bab70" />
※ <img width="39" height="44" alt="image" src="https://github.com/user-attachments/assets/58282739-8fba-4abe-b499-5a3cfd52792c" />

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
