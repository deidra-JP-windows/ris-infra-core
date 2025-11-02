# tools
便利なコマンドをまとめた .sh ファイルを実装しています。

## domain_analyze.sh

対象のドメインまたはIPアドレスについて、以下を解析します。
- ping応答の有無
- dig(nslookup)によるDNS情報取得
- SSL証明書の状態とチェーン情報

### 使い方

```sh
sh domain_analyze.sh <domain_or_ip>
```

例:
```sh
sh domain_analyze.sh example.com
```

※ Windowsの場合はWSLやGit Bash、Mac/Linuxではそのまま利用できます。
※ openssl, dig/nslookupコマンドが必要です。
