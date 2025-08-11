#!/bin/bash

# =============================================================================
# SSH Key Auto-Setup Script
# =============================================================================
# 
# このスクリプトは、Terraformで生成されたSSH鍵を自動的に設定します。
# terraform apply完了後に実行することを想定しています。
# =============================================================================

set -e

# 色付きログ関数
log() {
    echo -e "\033[1;34m[$(date '+%Y-%m-%d %H:%M:%S')]\033[0m $1"
}

error() {
    echo -e "\033[1;31m[ERROR]\033[0m $1" >&2
}

success() {
    echo -e "\033[1;32m[SUCCESS]\033[0m $1"
}

warning() {
    echo -e "\033[1;33m[WARNING]\033[0m $1"
}

# ヘルプ表示
show_help() {
    cat << EOF
SSH Key Auto-Setup Script

使用方法:
    $0 [オプション]

オプション:
    -h, --help          このヘルプを表示
    -f, --force         既存の設定を強制上書き
    -k, --key-name      鍵ファイル名（デフォルト: wordpress_key）
    -c, --config-only   SSH設定ファイルのみ更新
    -v, --verbose       詳細出力

例:
    $0                    # 通常の設定
    $0 -f                 # 強制上書き
    $0 -k my_key          # カスタム鍵名
    $0 -c                 # 設定ファイルのみ更新

EOF
}

# デフォルト値
FORCE_OVERWRITE=false
KEY_NAME="wordpress_key"
CONFIG_ONLY=false
VERBOSE=false

# 引数解析
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            FORCE_OVERWRITE=true
            shift
            ;;
        -k|--key-name)
            KEY_NAME="$2"
            shift 2
            ;;
        -c|--config-only)
            CONFIG_ONLY=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        *)
            error "不明なオプション: $1"
            show_help
            exit 1
            ;;
    esac
done

# メイン処理
main() {
    log "=== SSH Key Auto-Setup 開始 ==="
    
    # 必要なディレクトリの作成
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Terraformの状態確認
    if ! command -v terraform &> /dev/null; then
        error "terraformコマンドが見つかりません"
        exit 1
    fi
    
    if [ ! -f "terraform.tfstate" ]; then
        error "terraform.tfstateファイルが見つかりません。terraform applyを先に実行してください。"
        exit 1
    fi
    
    # SSH秘密鍵の取得と保存
    if [ "$CONFIG_ONLY" = false ]; then
        log "SSH秘密鍵を取得中..."
        
        if [ -f "~/.ssh/$KEY_NAME" ] && [ "$FORCE_OVERWRITE" = false ]; then
            warning "既存の鍵ファイル ~/.ssh/$KEY_NAME が存在します"
            read -p "上書きしますか？ (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "処理を中止しました"
                exit 0
            fi
        fi
        
        # Terraformから秘密鍵を取得
        if terraform output -raw ssh_private_key > "~/.ssh/$KEY_NAME" 2>/dev/null; then
            chmod 600 "~/.ssh/$KEY_NAME"
            success "SSH秘密鍵を保存しました: ~/.ssh/$KEY_NAME"
        else
            error "SSH秘密鍵の取得に失敗しました"
            exit 1
        fi
    fi
    
    # WordPressサーバーのIPアドレスを取得
    log "WordPressサーバーのIPアドレスを取得中..."
    WORDPRESS_IP=$(terraform output -raw wordpress_public_ip 2>/dev/null || echo "")
    
    if [ -z "$WORDPRESS_IP" ]; then
        error "WordPressサーバーのIPアドレスを取得できませんでした"
        exit 1
    fi
    
    success "WordPressサーバーIP: $WORDPRESS_IP"
    
    # SSH設定ファイルの更新
    log "SSH設定ファイルを更新中..."
    
    # 既存の設定をチェック
    if grep -q "Host wordpress-server" ~/.ssh/config 2>/dev/null; then
        if [ "$FORCE_OVERWRITE" = true ]; then
            # 既存の設定を削除
            sed -i '/^Host wordpress-server$/,/^$/d' ~/.ssh/config
            log "既存の設定を削除しました"
        else
            warning "既存のwordpress-server設定が存在します"
            read -p "更新しますか？ (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                log "設定ファイルの更新をスキップしました"
            else
                # 既存の設定を削除して新しく追加
                sed -i '/^Host wordpress-server$/,/^$/d' ~/.ssh/config
            fi
        fi
    fi
    
    # 新しい設定を追加
    cat >> ~/.ssh/config << EOF

Host wordpress-server
  HostName $WORDPRESS_IP
  User ec2-user
  IdentityFile ~/.ssh/$KEY_NAME
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
  ServerAliveInterval 60
  ServerAliveCountMax 3
EOF
    
    chmod 600 ~/.ssh/config
    success "SSH設定ファイルを更新しました: ~/.ssh/config"
    
    # 接続テスト（オプション）
    if [ "$VERBOSE" = true ]; then
        log "SSH接続をテスト中..."
        if timeout 10 ssh -o ConnectTimeout=5 wordpress-server "echo 'SSH接続成功'" 2>/dev/null; then
            success "SSH接続テスト成功"
        else
            warning "SSH接続テストに失敗しました（サーバー起動中かもしれません）"
        fi
    fi
    
    # 設定完了メッセージ
    log "=== SSH Key Auto-Setup 完了 ==="
    echo
    success "SSH鍵の設定が完了しました！"
    echo
    echo "設定内容:"
    echo "- 秘密鍵: ~/.ssh/$KEY_NAME"
    echo "- SSH設定: ~/.ssh/config"
    echo "- 接続先: $WORDPRESS_IP"
    echo
    echo "接続コマンド:"
    echo "  ssh wordpress-server"
    echo
    echo "Ansible実行例:"
    echo "  ansible-playbook -i ansible/inventory/hosts.yml ansible/playbooks/wordpress-setup.yml"
    echo
}

# スクリプト実行
main "$@"
