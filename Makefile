# =============================================================================
# WordPress AWS Infrastructure Makefile
# =============================================================================
# 
# このMakefileは、WordPress環境の構築からSSH設定までを統合管理します。
# =============================================================================

.PHONY: help init plan apply destroy ssh-setup ansible-setup full-setup clean

# デフォルトターゲット
help:
	@echo "WordPress AWS Infrastructure Management"
	@echo ""
	@echo "利用可能なコマンド:"
	@echo "  make init          - Terraform初期化"
	@echo "  make plan          - Terraform実行計画"
	@echo "  make apply         - インフラ構築実行"
	@echo "  make destroy       - インフラ削除"
	@echo "  make ssh-setup        - SSH鍵設定のみ"
	@echo "  make ansible-setup    - Ansible設定のみ"
	@echo "  make wordpress-setup  - WordPress環境構築"
	@echo "  make ssl-setup        - SSL設定"
	@echo "  make test-environment - 環境テスト"
	@echo "  make generate-password - セキュアパスワード生成"
	@echo "  make full-setup       - 完全セットアップ（推奨）"
	@echo "  make clean         - 一時ファイル削除"
	@echo "  make status        - 現在の状態確認"
	@echo ""

# Terraform初期化
init:
	@echo "=== Terraform初期化 ==="
	terraform init
	@echo "初期化完了"

# Terraform実行計画
plan:
	@echo "=== Terraform実行計画 ==="
	terraform plan
	@echo "計画完了"

# インフラ構築実行
apply:
	@echo "=== インフラ構築実行 ==="
	terraform apply -auto-approve
	@echo "インフラ構築完了"
	@echo ""
	@echo "次のステップ:"
	@echo "  make ssh-setup     # SSH鍵設定"
	@echo "  make ansible-setup # Ansible設定"

# インフラ削除
destroy:
	@echo "=== インフラ削除 ==="
	@read -p "本当にインフラを削除しますか？ (y/N): " -n 1 -r; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		terraform destroy -auto-approve; \
		echo "インフラ削除完了"; \
	else \
		echo "削除をキャンセルしました"; \
	fi

# SSH鍵設定
ssh-setup:
	@echo "=== SSH鍵設定 ==="
	@if [ ! -f "terraform.tfstate" ]; then \
		echo "エラー: terraform.tfstateファイルが見つかりません"; \
		echo "先に 'make apply' を実行してください"; \
		exit 1; \
	fi
	@./scripts/setup/ssh_key_setup.sh -v
	@echo "SSH鍵設定完了"

# Ansible設定
ansible-setup:
	@echo "=== Ansible設定 ==="
	@if [ ! -f "terraform.tfstate" ]; then \
		echo "エラー: terraform.tfstateファイルが見つかりません"; \
		echo "先に 'make apply' を実行してください"; \
		exit 1; \
	fi
	@./scripts/setup/ansible_auto_setup.sh -s -v
	@echo "Ansible設定完了"

# WordPress環境構築
wordpress-setup:
	@echo "=== WordPress環境構築 ==="
	@if [ ! -f "terraform.tfstate" ]; then \
		echo "エラー: terraform.tfstateファイルが見つかりません"; \
		echo "先に 'make apply' を実行してください"; \
		exit 1; \
	fi
	@./scripts/setup/ansible_auto_setup.sh -f -v
	@echo "WordPress環境構築完了"

# SSL設定
ssl-setup:
	@echo "=== SSL設定 ==="
	@if [ ! -f "terraform.tfstate" ]; then \
		echo "エラー: terraform.tfstateファイルが見つかりません"; \
		echo "先に 'make apply' を実行してください"; \
		exit 1; \
	fi
	@./scripts/setup/ansible_auto_setup.sh --skip-test -v
	@echo "SSL設定完了"

# 環境テスト
test-environment:
	@echo "=== 環境テスト ==="
	@if [ ! -f "terraform.tfstate" ]; then \
		echo "エラー: terraform.tfstateファイルが見つかりません"; \
		echo "先に 'make apply' を実行してください"; \
		exit 1; \
	fi
	@./scripts/setup/ansible_auto_setup.sh -t -v
	@echo "環境テスト完了"

# 完全セットアップ（推奨）
full-setup: init apply ssh-setup wordpress-setup ssl-setup test-environment
	@echo ""
	@echo "=== 完全セットアップ完了 ==="
	@echo ""
	@echo "WordPress環境が構築されました！"
	@echo ""
	@echo "接続情報:"
	@echo "- SSH接続: ssh wordpress-server"
	@echo "- WordPress URL: https://$(shell terraform output -raw domain_name 2>/dev/null || echo '設定中...')"
	@echo "- 管理画面: https://$(shell terraform output -raw domain_name 2>/dev/null || echo '設定中...')/wp-admin"
	@echo ""
	@echo "次のステップ:"
	@echo "1. WordPressの初期設定を完了"
	@echo "2. プラグインとテーマの設定"
	@echo "3. セキュリティ設定の確認"
	@echo ""

# 現在の状態確認
status:
	@echo "=== 現在の状態 ==="
	@if [ -f "terraform.tfstate" ]; then \
		echo "✓ Terraform状態ファイル: 存在"; \
		echo ""; \
		echo "インフラ情報:"; \
		terraform output -json | jq -r 'to_entries[] | "\(.key): \(.value)"' 2>/dev/null || echo "出力情報なし"; \
	else \
		echo "✗ Terraform状態ファイル: 不存在"; \
		echo "先に 'make apply' を実行してください"; \
	fi
	@echo ""
	@if [ -f "~/.ssh/wordpress_key" ]; then \
		echo "✓ SSH鍵: 設定済み"; \
	else \
		echo "✗ SSH鍵: 未設定"; \
	fi
	@if [ -f "~/.ssh/config" ] && grep -q "wordpress-server" ~/.ssh/config; then \
		echo "✓ SSH設定: 設定済み"; \
	else \
		echo "✗ SSH設定: 未設定"; \
	fi
	@if [ -f "deployment_config.json" ]; then \
		echo "✓ Ansible設定: 設定済み"; \
	else \
		echo "✗ Ansible設定: 未設定"; \
	fi

# 一時ファイル削除
clean:
	@echo "=== 一時ファイル削除 ==="
	rm -f .terraform.lock.hcl
	rm -rf .terraform
	rm -f *.backup
	rm -f *.log
	@echo "一時ファイル削除完了"

# 開発用: 高速セットアップ（既存の状態を前提）
quick-setup: ssh-setup ansible-setup
	@echo "=== 高速セットアップ完了 ==="

# 開発用: 設定のみ更新
update-config:
	@echo "=== 設定更新 ==="
	@./scripts/setup/ssh_key_setup.sh -c -v
	@echo "設定更新完了"
