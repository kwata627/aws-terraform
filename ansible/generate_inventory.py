#!/usr/bin/env python3
"""
Terraformの出力からAnsibleインベントリを動的に生成するスクリプト
ベストプラクティスに沿った設計で、エラーハンドリングとログ機能を強化
"""

import json
import subprocess
import sys
import os
import yaml
import logging
from typing import Dict, Any, Optional
from pathlib import Path

# =============================================================================
# 定数定義
# =============================================================================

DEFAULT_INVENTORY_FILE = "inventory/hosts.yml"
DEFAULT_TERRAFORM_DIR = ".."
DEFAULT_LOG_LEVEL = "INFO"

# =============================================================================
# ログ設定
# =============================================================================

def setup_logging(log_level: str = DEFAULT_LOG_LEVEL) -> logging.Logger:
    """ログ設定の初期化"""
    logging.basicConfig(
        level=getattr(logging, log_level.upper()),
        format='%(asctime)s - %(levelname)s - %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(f"ansible_inventory_{os.getenv('LOG_FILE', 'default')}.log")
        ]
    )
    return logging.getLogger(__name__)

# =============================================================================
# Terraform連携関数
# =============================================================================

def run_terraform_output(terraform_dir: str = DEFAULT_TERRAFORM_DIR) -> Optional[Dict[str, Any]]:
    """Terraformの出力を取得"""
    logger = logging.getLogger(__name__)
    
    try:
        logger.info(f"Terraform出力を取得中... (ディレクトリ: {terraform_dir})")
        
        # 作業ディレクトリを変更
        original_dir = os.getcwd()
        os.chdir(terraform_dir)
        
        # Terraform出力の実行
        result = subprocess.run(
            ['terraform', 'output', '-json'],
            capture_output=True,
            text=True,
            timeout=30
        )
        
        # 元のディレクトリに戻る
        os.chdir(original_dir)
        
        if result.returncode != 0:
            logger.error(f"Terraform出力の実行に失敗: {result.stderr}")
            return None
        
        # JSONの解析
        terraform_output = json.loads(result.stdout)
        logger.info("Terraform出力の取得が完了しました")
        
        return terraform_output
        
    except subprocess.TimeoutExpired:
        logger.error("Terraform出力の取得がタイムアウトしました")
        return None
    except json.JSONDecodeError as e:
        logger.error(f"Terraform出力のJSON解析に失敗: {e}")
        return None
    except Exception as e:
        logger.error(f"Terraform出力の取得中にエラーが発生: {e}")
        return None

def validate_terraform_output(terraform_output: Dict[str, Any]) -> bool:
    """Terraform出力の検証"""
    logger = logging.getLogger(__name__)
    
    if not isinstance(terraform_output, dict):
        logger.error("Terraform出力が辞書形式ではありません")
        return False
    
    # 必須キーの確認
    required_keys = ['wordpress_public_ip']
    missing_keys = [key for key in required_keys if key not in terraform_output]
    
    if missing_keys:
        logger.warning(f"Terraform出力に必須キーが不足: {missing_keys}")
        # 警告のみで処理を続行
    
    logger.info("Terraform出力の検証が完了しました")
    return True

# =============================================================================
# インベントリ生成関数
# =============================================================================

def generate_inventory(terraform_output: Dict[str, Any]) -> Dict[str, Any]:
    """Terraformの出力からAnsibleインベントリを生成"""
    logger = logging.getLogger(__name__)
    
    logger.info("Ansibleインベントリを生成中...")
    
    inventory = {
        'all': {
            'children': {
                'wordpress': {
                    'hosts': {}
                },
                'nat_instance': {
                    'hosts': {}
                }
            }
        }
    }
    
    # WordPress EC2の情報を取得
    if 'wordpress_public_ip' in terraform_output:
        wordpress_ip = terraform_output['wordpress_public_ip']['value']
        if wordpress_ip:
            inventory['all']['children']['wordpress']['hosts']['wordpress_ec2'] = {
                'ansible_host': wordpress_ip,
                'ansible_user': os.getenv('SSH_USER', 'ec2-user'),
                'ansible_ssh_private_key_file': os.getenv('SSH_PRIVATE_KEY_FILE', '~/.ssh/ssh_key'),
                'ansible_ssh_common_args': '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null',
                'ansible_ssh_extra_args': '-o ConnectTimeout=30'
            }
            logger.info(f"WordPress EC2を追加: {wordpress_ip}")
        else:
            logger.warning("WordPress EC2のIPアドレスが空です")
    else:
        logger.warning("WordPress EC2の情報が見つかりません")
    
    # NATインスタンスの情報を取得
    if 'nat_instance_public_ip' in terraform_output:
        nat_ip = terraform_output['nat_instance_public_ip']['value']
        if nat_ip:
            inventory['all']['children']['nat_instance']['hosts']['nat_ec2'] = {
                'ansible_host': nat_ip,
                'ansible_user': os.getenv('SSH_USER', 'ec2-user'),
                'ansible_ssh_private_key_file': os.getenv('SSH_PRIVATE_KEY_FILE', '~/.ssh/ssh_key'),
                'ansible_ssh_common_args': '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null',
                'ansible_ssh_extra_args': '-o ConnectTimeout=30'
            }
            logger.info(f"NATインスタンスを追加: {nat_ip}")
        else:
            logger.warning("NATインスタンスのIPアドレスが空です")
    else:
        logger.info("NATインスタンスは設定されていません")
    
    # RDSエンドポイントの設定
    if 'rds_endpoint' in terraform_output:
        rds_endpoint = terraform_output['rds_endpoint']['value']
        if rds_endpoint:
            # WordPressグループの全ホストにRDSエンドポイントを設定
            for host in inventory['all']['children']['wordpress']['hosts']:
                inventory['all']['children']['wordpress']['hosts'][host]['rds_endpoint'] = rds_endpoint
            logger.info(f"RDSエンドポイントを設定: {rds_endpoint}")
        else:
            logger.warning("RDSエンドポイントが空です")
    else:
        logger.warning("RDSエンドポイントの情報が見つかりません")
    
    # 環境変数による追加設定
    if os.getenv('ANSIBLE_EXTRA_VARS'):
        try:
            extra_vars = json.loads(os.getenv('ANSIBLE_EXTRA_VARS'))
            for group in inventory['all']['children']:
                for host in inventory['all']['children'][group]['hosts']:
                    inventory['all']['children'][group]['hosts'][host].update(extra_vars)
            logger.info("環境変数による追加設定を適用しました")
        except json.JSONDecodeError as e:
            logger.error(f"環境変数ANSIBLE_EXTRA_VARSのJSON解析に失敗: {e}")
    
    logger.info("Ansibleインベントリの生成が完了しました")
    return inventory

def validate_inventory(inventory: Dict[str, Any]) -> bool:
    """インベントリの検証"""
    logger = logging.getLogger(__name__)
    
    if not isinstance(inventory, dict):
        logger.error("インベントリが辞書形式ではありません")
        return False
    
    if 'all' not in inventory:
        logger.error("インベントリに'all'グループがありません")
        return False
    
    if 'children' not in inventory['all']:
        logger.error("インベントリに'children'がありません")
        return False
    
    # ホストの存在確認
    total_hosts = 0
    for group_name, group_data in inventory['all']['children'].items():
        if 'hosts' in group_data:
            hosts_count = len(group_data['hosts'])
            total_hosts += hosts_count
            logger.info(f"グループ '{group_name}': {hosts_count} ホスト")
    
    if total_hosts == 0:
        logger.warning("インベントリにホストが設定されていません")
    
    logger.info("インベントリの検証が完了しました")
    return True

# =============================================================================
# ファイル操作関数
# =============================================================================

def write_inventory(inventory: Dict[str, Any], output_file: str = DEFAULT_INVENTORY_FILE) -> bool:
    """インベントリファイルを書き込み"""
    logger = logging.getLogger(__name__)
    
    try:
        # ディレクトリの作成
        output_path = Path(output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        # 既存ファイルのバックアップ
        if output_path.exists():
            backup_file = f"{output_file}.backup.{int(os.path.getmtime(output_file))}"
            import shutil
            shutil.copy2(output_file, backup_file)
            logger.info(f"既存ファイルをバックアップしました: {backup_file}")
        
        # YAMLファイルに書き込み
        with open(output_file, 'w', encoding='utf-8') as f:
            yaml.dump(inventory, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        
        logger.info(f"インベントリファイルを生成しました: {output_file}")
        
        # 生成されたホストの表示
        logger.info("生成されたホスト:")
        for group_name, group_data in inventory['all']['children'].items():
            for hostname, config in group_data['hosts'].items():
                logger.info(f"  {hostname}: {config.get('ansible_host', 'N/A')}")
        
        return True
        
    except Exception as e:
        logger.error(f"インベントリファイルの書き込みに失敗: {e}")
        return False

def create_inventory_template(output_file: str = "inventory/hosts.template.yml") -> bool:
    """インベントリテンプレートの作成"""
    logger = logging.getLogger(__name__)
    
    template = {
        'all': {
            'children': {
                'wordpress': {
                    'hosts': {
                        'wordpress_ec2': {
                            'ansible_host': '{{ wordpress_public_ip }}',
                            'ansible_user': '{{ ssh_user | default("ec2-user") }}',
                            'ansible_ssh_private_key_file': '{{ ssh_private_key_file | default("~/.ssh/id_rsa") }}',
                            'ansible_ssh_common_args': '-o StrictHostKeyChecking=no'
                        }
                    }
                },
                'nat_instance': {
                    'hosts': {
                        'nat_ec2': {
                            'ansible_host': '{{ nat_instance_public_ip }}',
                            'ansible_user': '{{ ssh_user | default("ec2-user") }}',
                            'ansible_ssh_private_key_file': '{{ ssh_private_key_file | default("~/.ssh/id_rsa") }}',
                            'ansible_ssh_common_args': '-o StrictHostKeyChecking=no'
                        }
                    }
                }
            }
        }
    }
    
    try:
        output_path = Path(output_file)
        output_path.parent.mkdir(parents=True, exist_ok=True)
        
        with open(output_file, 'w', encoding='utf-8') as f:
            yaml.dump(template, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        
        logger.info(f"インベントリテンプレートを作成しました: {output_file}")
        return True
        
    except Exception as e:
        logger.error(f"インベントリテンプレートの作成に失敗: {e}")
        return False

# =============================================================================
# メイン処理
# =============================================================================

def main():
    """メイン関数"""
    # ログ設定
    logger = setup_logging(os.getenv('LOG_LEVEL', DEFAULT_LOG_LEVEL))
    
    logger.info("Ansibleインベントリ生成を開始...")
    
    # 引数の解析
    output_file = os.getenv('INVENTORY_FILE', DEFAULT_INVENTORY_FILE)
    terraform_dir = os.getenv('TERRAFORM_DIR', DEFAULT_TERRAFORM_DIR)
    create_template = os.getenv('CREATE_TEMPLATE', 'false').lower() == 'true'
    
    # テンプレート作成モード
    if create_template:
        if create_inventory_template():
            logger.info("インベントリテンプレートの作成が完了しました")
            return 0
        else:
            logger.error("インベントリテンプレートの作成に失敗しました")
            return 1
    
    # Terraformの出力を取得
    terraform_output = run_terraform_output(terraform_dir)
    if not terraform_output:
        logger.error("Terraform出力の取得に失敗しました")
        return 1
    
    # Terraform出力の検証
    if not validate_terraform_output(terraform_output):
        logger.warning("Terraform出力の検証で警告が発生しましたが、処理を続行します")
    
    # インベントリを生成
    inventory = generate_inventory(terraform_output)
    
    # インベントリの検証
    if not validate_inventory(inventory):
        logger.error("インベントリの検証に失敗しました")
        return 1
    
    # インベントリファイルを書き込み
    if not write_inventory(inventory, output_file):
        logger.error("インベントリファイルの書き込みに失敗しました")
        return 1
    
    logger.info("インベントリ生成が完了しました")
    return 0

if __name__ == '__main__':
    sys.exit(main()) 