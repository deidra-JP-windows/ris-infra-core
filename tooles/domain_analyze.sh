#!/bin/sh

# Usage: sh domain_analyze.sh <domain_or_ip>


if [ $# -lt 1 ]; then
  echo "Usage: sh domain_analyze.sh <domain_or_ip>"
  exit 1
fi

# 解析対象のドメインまたはIP
TARGET="$1"
# 出力ディレクトリ
OUTPUT_DIR="outputs"
# スクリプト名の省略形（ファイル名用）
SCRIPT_ABBR="da"
# 実行日時（ファイル名用）
DATE_STR="$(date +%Y%m%d_%H%M%S)"
# 出力ファイルパス
# 一時ファイル（生データ用）
RAW_FILE="$OUTPUT_DIR/${TARGET}_${SCRIPT_ABBR}_${DATE_STR}_raw.txt"
# 最終出力ファイル（サマリ＋生データ）
OUTPUT_FILE="$OUTPUT_DIR/${TARGET}_${SCRIPT_ABBR}_${DATE_STR}.txt"
# 出力ディレクトリ作成
mkdir -p "$OUTPUT_DIR"

# ping: 対象へのネットワーク疎通可否と応答速度（RTT）を確認します。3回送信し、パケットロスや遅延を把握できます。
{
  printf '\n--- ping result ---\n'
  # pingが成功する条件: 対象がネットワーク上で到達可能であり、ICMPパケットが許可されていること
  ping -c 3 "$TARGET" 2>&1 || ping -n 3 "$TARGET" 2>&1

  # dig/nslookup: DNSレコード（A, AAAA, MX, CNAME等）を取得し、名前解決の状況やDNSサーバの応答を確認します。
  # dig/nslookupが成功する条件: 対象のドメイン名がDNSに登録されていて、名前解決が可能であること
  if command -v dig >/dev/null 2>&1; then
    printf '\n--- dig result ---\n'
    dig "$TARGET"   # dig: DNSの詳細情報（レコード・TTL・権威サーバ等）を表示
  else
    printf '\n--- nslookup result ---\n'
    nslookup "$TARGET"   # nslookup: DNSの基本情報を表示
  fi

  # openssl: HTTPSサーバのSSL証明書チェーン（有効期限・発行者・サブジェクト等）を取得し、暗号化通信の安全性を確認します。SNI対応で多くのWebサーバに対応。
  printf '\n--- SSL certificate chain ---\n'
  # opensslが成功する条件: 対象が443ポート(HTTPS)でサービスを提供しており、TCP接続が可能であること
  echo | openssl s_client -showcerts -connect "$TARGET:443" -servername "$TARGET" 2>/dev/null

  # traceroute: 対象までの経路（ルーターの通過点）を表示し、どこで遅延や遮断が発生しているかを調査できます。
  # tracerouteが成功しない/終わらない主な原因:
  #   - ICMP/UDPパケットが途中で遮断されている（多くのネットワーク機器やFWでブロックされることが多い）
  #   - 対象がIPv6のみ対応 or DNS解決不可
  #   - ネットワーク障害や経路断
  #   - デフォルトUDP/ICMPに非対応（traceroute -IでICMP, -TでTCPも試せる）
  # 対策例: traceroute -I <target>（ICMP）、traceroute -T <target>（TCP）
  # 実行が終わらない場合はtimeoutで強制終了します（例: 20秒）
  printf '\n--- traceroute result ---\n'
  # tracerouteが成功する条件: 対象までの経路上でICMP/UDPパケットが通過可能であり、途中のルーターが応答すること
  if command -v traceroute >/dev/null 2>&1; then
    if command -v timeout >/dev/null 2>&1; then
      timeout 20 traceroute "$TARGET" 2>&1
    else
      traceroute "$TARGET" 2>&1
    fi
  else
    printf 'tracerouteコマンドが見つかりません。\n'
  fi

  # whois: ドメインやIPアドレスの登録者情報（管理者・組織・有効期限等）を取得し、所有者や運用元を調査できます。
  printf '\n--- whois result ---\n'
  # whoisが成功する条件: 対象のドメインやIPがwhoisデータベースに登録されていること
  if command -v whois >/dev/null 2>&1; then
    whois "$TARGET" 2>&1
  else
    printf 'whoisコマンドが見つかりません。\n'
  fi

  # curl -I: WebサーバのHTTPレスポンスヘッダー（ステータスコード・サーバ種別・有効期限・リダイレクト等）を取得し、Webサービスの稼働状況や設定を確認できます。
  printf '\n--- HTTP header (curl -I) ---\n'
  # curl -Iが成功する条件: 対象がHTTPS(443)でWebサービスを提供しており、HTTPレスポンスヘッダーが取得可能であること
  if command -v curl >/dev/null 2>&1; then
    curl -I "https://$TARGET" 2>&1
  else
    printf 'curlコマンドが見つかりません。\n'
  fi
} > "$RAW_FILE"

# サマリ＋生データを一つのファイルにまとめる
{
  printf '\n--- 日本語サマリ ---\n'

  # pingサマリ（BusyBox/Linux両対応）
  printf '【疎通確認】\n'
  PING_RESULT=$(awk '/--- ping result ---/{f=1; next} /--- nslookup result ---/{f=0} f' "$RAW_FILE")
  # パケットロス率抽出
  LOSS_LINE=$(echo "$PING_RESULT" | grep 'packet loss')
  if [ -n "$LOSS_LINE" ]; then
    LOSS=$(echo "$LOSS_LINE" | awk -F',' '{for(i=1;i<=NF;i++){if($i~/% packet loss/){print $i}}}' | awk '{print $1}')
    printf "パケットロス率: %s\n" "$LOSS"
  else
    printf "パケットロス率: 情報なし\n"
  fi
  # 平均応答時間抽出
  RTT_LINE=$(echo "$PING_RESULT" | grep -E 'round-trip|rtt')
  if [ -n "$RTT_LINE" ]; then
    # Linux形式: round-trip min/avg/max = 11.274/11.766/12.018 ms
    AVG=$(echo "$RTT_LINE" | awk -F'=' '{print $2}' | awk -F'/' '{print $2}')
    # BusyBox形式: rtt min/avg/max/mdev = ...
    [ -z "$AVG" ] && AVG=$(echo "$RTT_LINE" | awk -F'=' '{print $2}' | awk -F'/' '{print $2}')
    printf "平均応答時間: %s ms\n" "$AVG"
  else
    printf "平均応答時間: 情報なし\n"
  fi

  # DNSサマリ（dig/nslookup両対応・複数行抽出）
  printf '\n【DNS情報】\n'
  if grep -q 'NXDOMAIN' "$RAW_FILE"; then
    printf 'ドメインは存在しません（NXDOMAIN）。\n'
  else
    # dig形式
    ADDR_LIST=$(awk '/--- dig result ---/{f=1; c=0; next} f && c<40 {print; c++} /---/{f=0}' "$RAW_FILE" | grep -E '\sA\s' | awk '{print $5}')
    CNAME_LIST=$(awk '/--- dig result ---/{f=1; c=0; next} f && c<40 {print; c++} /---/{f=0}' "$RAW_FILE" | grep -E 'CNAME' | awk '{print $5}')
    # nslookup形式
    NSLOOKUP_ADDR=$(awk '/--- nslookup result ---/{f=1; c=0; next} f && c<40 {print; c++} /---/{f=0}' "$RAW_FILE" | grep -E '^Name:|^Address:' | grep -v 'canonical' | awk -F': ' '/Address:/ {print $2}')
    NSLOOKUP_CNAME=$(awk '/--- nslookup result ---/{f=1; c=0; next} f && c<40 {print; c++} /---/{f=0}' "$RAW_FILE" | grep 'canonical' | awk -F'= ' '{print $2}')
    # Aレコード
    if [ -n "$ADDR_LIST" ] || [ -n "$NSLOOKUP_ADDR" ]; then
      printf "AレコードIP一覧:\n"
      [ -n "$ADDR_LIST" ] && echo "$ADDR_LIST" | while read line; do printf "  - %s\n" "$line"; done
      [ -n "$NSLOOKUP_ADDR" ] && echo "$NSLOOKUP_ADDR" | while read line; do printf "  - %s\n" "$line"; done
    else
      printf "AレコードIP: 情報なし\n"
    fi
    # CNAME
    if [ -n "$CNAME_LIST" ] || [ -n "$NSLOOKUP_CNAME" ]; then
      printf "CNAME一覧:\n"
      [ -n "$CNAME_LIST" ] && echo "$CNAME_LIST" | while read line; do printf "  - %s\n" "$line"; done
      [ -n "$NSLOOKUP_CNAME" ] && echo "$NSLOOKUP_CNAME" | while read line; do printf "  - %s\n" "$line"; done
    else
      printf "CNAME: 情報なし\n"
    fi
  fi

  # SSL証明書サマリ（subject/issuer/Not After範囲拡大）
  printf '\n【SSL証明書】\n'
  printf "証明書情報: 詳細は下記SSL証明書ログ参照\n"

  # tracerouteサマリ（ホップ数のみ）
  printf '\n【経路(traceroute)】\n'
  if grep -q 'tracerouteコマンドが見つかりません' "$RAW_FILE"; then
    printf 'tracerouteコマンドが見つかりません。\n'
  else
    HOPS=$(awk '/--- traceroute result ---/{f=1; next} /---/{f=0} f' "$RAW_FILE" | grep -E '^[ ]*[0-9]+ ' | wc -l)
    if [ "$HOPS" -gt 0 ]; then
      printf "経路上のホップ数: %s\n" "$HOPS"
    else
      printf "経路情報: 情報なし\n"
    fi
  fi

  # whoisサマリ
  printf '\n【登録情報(whois)】\n'
  printf "組織・国・有効期限: 詳細は下記whoisログ参照\n"

  # curl -Iサマリ（複数行対応）
  printf '\n【Webサーバ応答】\n'
  # RAW_FILE全体から直接抽出（範囲指定なし）
  HTTP=$(grep -m1 -E 'HTTP/[0-9.]+' "$RAW_FILE" | sed -E 's/.*(HTTP\/[0-9.]+ [0-9]+).*/\1/')
  SERVER=$(grep -i -m1 '^server:' "$RAW_FILE" | sed 's/^server:[ ]*//I')
  TYPE=$(grep -i -m1 '^content-type:' "$RAW_FILE" | sed 's/^content-type:[ ]*//I')
  if [ -n "$HTTP" ]; then printf "HTTPステータス: %s\n" "$HTTP"; else printf "HTTPステータス: 情報なし\n"; fi
  if [ -n "$SERVER" ]; then printf "サーバ種別: %s\n" "$SERVER"; else printf "サーバ種別: 情報なし\n"; fi
  if [ -n "$TYPE" ]; then printf "Content-Type: %s\n" "$TYPE"; else printf "Content-Type: 情報なし\n"; fi
  cat "$RAW_FILE"
} > "$OUTPUT_FILE"
# 一時ファイル削除
rm -f "$RAW_FILE"
