#!/usr/bin/env python3
"""
Terraformの出力からAnsibleインベントリを動的に生成するスクリプト
terraform.tfvarsを直接読み込む機能を追加し、Ansible単体実行を可能にする
ベストプラクティスに沿った設計で、エラーハンドリングとログ機能を強化
"""

import json
import subprocess
import sys
import os
import yaml
import logging
import re
from typing import Dict, Any, Optional, Union
from pathlib import Path

# =============================================================================
# 定数定義
# =============================================================================

DEFAULT_INVENTORY_FILE = "inventory/hosts.yml"
DEFAULT_TERRAFORM_DIR = ".."
DEFAULT_TERRAFORM_TFVARS = "../terraform.tfvars"
DEFAULT_DEPLOYMENT_CONFIG = "../deployment_config.json"
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
# terraform.tfvars読み込み関数
# =============================================================================

def parse_terraform_tfvars(tfvars_file: str = DEFAULT_TERRAFORM_TFVARS) -> Optional[Dict[str, Any]]:
    """terraform.tfvarsファイルを解析して設定値を取得"""
    logger = logging.getLogger(__name__)
    
    try:
        logger.info(f"terraform.tfvarsファイルを読み込み中: {tfvars_file}")
        
        if not os.path.exists(tfvars_file):
            logger.warning(f"terraform.tfvarsファイルが見つかりません: {tfvars_file}")
            return None
        
        with open(tfvars_file, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # HCL形式のterraform.tfvarsをPython辞書に変換
        tfvars = {}
        
        # 基本的な変数パターンを解析
        patterns = {
            'project': r'project\s*=\s*["\']([^"\']+)["\']',
            'environment': r'environment\s*=\s*["\']([^"\']+)["\']',
            'domain_name': r'domain_name\s*=\s*["\']([^"\']+)["\']',
            'ec2_name': r'ec2_name\s*=\s*["\']([^"\']+)["\']',
            'rds_identifier': r'rds_identifier\s*=\s*["\']([^"\']+)["\']',
            'db_password': r'db_password\s*=\s*["\']([^"\']+)["\']',
            's3_bucket_name': r's3_bucket_name\s*=\s*["\']([^"\']+)["\']',
            'instance_type': r'instance_type\s*=\s*["\']([^"\']+)["\']',
            'ami_id': r'ami_id\s*=\s*["\']([^"\']+)["\']',
            'vpc_cidr': r'vpc_cidr\s*=\s*["\']([^"\']+)["\']',
            'public_subnet_cidr': r'public_subnet_cidr\s*=\s*["\']([^"\']+)["\']',
            'private_subnet_cidr': r'private_subnet_cidr\s*=\s*["\']([^"\']+)["\']',
            'ssh_allowed_cidr': r'ssh_allowed_cidr\s*=\s*["\']([^"\']+)["\']',
            'enable_ssl_setup': r'enable_ssl_setup\s*=\s*(true|false)',
            'enable_lets_encrypt': r'enable_lets_encrypt\s*=\s*(true|false)',
            'lets_encrypt_email': r'lets_encrypt_email\s*=\s*["\']([^"\']+)["\']',
        }
        
        for key, pattern in patterns.items():
            match = re.search(pattern, content)
            if match:
                value = match.group(1)
                # ブール値の変換
                if value.lower() in ['true', 'false']:
                    tfvars[key] = value.lower() == 'true'
                else:
                    tfvars[key] = value
                logger.debug(f"設定値を取得: {key} = {value}")
        
        # registrant_infoブロックの解析
        registrant_match = re.search(r'registrant_info\s*=\s*\{([^}]+)\}', content, re.DOTALL)
        if registrant_match:
            registrant_content = registrant_match.group(1)
            registrant_info = {}
            
            registrant_patterns = {
                'first_name': r'first_name\s*=\s*["\']([^"\']+)["\']',
                'last_name': r'last_name\s*=\s*["\']([^"\']+)["\']',
                'email': r'email\s*=\s*["\']([^"\']+)["\']',
                'phone_number': r'phone_number\s*=\s*["\']([^"\']+)["\']',
            }
            
            for key, pattern in registrant_patterns.items():
                match = re.search(pattern, registrant_content)
                if match:
                    registrant_info[key] = match.group(1)
            
            if registrant_info:
                tfvars['registrant_info'] = registrant_info
        
        logger.info(f"terraform.tfvarsの解析が完了しました: {len(tfvars)}個の設定値を取得")
        return tfvars
        
    except Exception as e:
        logger.error(f"terraform.tfvarsファイルの解析に失敗: {e}")
        return None

def parse_deployment_config(config_file: str = DEFAULT_DEPLOYMENT_CONFIG) -> Optional[Dict[str, Any]]:
    """deployment_config.jsonファイルを読み込み"""
    logger = logging.getLogger(__name__)
    
    try:
        logger.info(f"deployment_config.jsonファイルを読み込み中: {config_file}")
        
        if not os.path.exists(config_file):
            logger.warning(f"deployment_config.jsonファイルが見つかりません: {config_file}")
            return None
        
        with open(config_file, 'r', encoding='utf-8') as f:
            config = json.load(f)
        
        logger.info("deployment_config.jsonの読み込みが完了しました")
        return config
        
    except Exception as e:
        logger.error(f"deployment_config.jsonファイルの読み込みに失敗: {e}")
        return None

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
        
        # デバッグ情報を出力
        logger.info(f"取得された出力キー: {list(terraform_output.keys())}")
        if 'wordpress_public_ip' in terraform_output:
            logger.info(f"WordPress IP: {terraform_output['wordpress_public_ip']}")
        
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
# 設定値統合関数
# =============================================================================

def merge_configurations(
    terraform_output: Optional[Dict[str, Any]] = None,
    tfvars: Optional[Dict[str, Any]] = None,
    deployment_config: Optional[Dict[str, Any]] = None
) -> Dict[str, Any]:
    """複数の設定ソースを統合して優先順位を付ける"""
    logger = logging.getLogger(__name__)
    
    logger.info("設定値の統合を開始...")
    
    # 統合された設定
    merged_config = {}
    
    # 1. terraform.tfvarsをベース設定として使用
    if tfvars:
        merged_config.update(tfvars)
        logger.info(f"terraform.tfvarsから{len(tfvars)}個の設定値を統合")
    
    # 2. deployment_config.jsonで上書き
    if deployment_config:
        if 'production' in deployment_config:
            merged_config.update(deployment_config['production'])
        if 'validation' in deployment_config:
            merged_config['validation'] = deployment_config['validation']
        logger.info("deployment_config.jsonの設定値を統合")
    
    # 3. Terraform出力で上書き（動的な値）
    if terraform_output:
        # WordPress IP
        if 'wordpress_public_ip' in terraform_output:
            wp_output = terraform_output['wordpress_public_ip']
            if isinstance(wp_output, dict) and 'value' in wp_output:
                merged_config['wordpress_public_ip'] = wp_output['value']
            elif isinstance(wp_output, str):
                merged_config['wordpress_public_ip'] = wp_output
        
        # NAT IP
        if 'nat_instance_public_ip' in terraform_output:
            nat_output = terraform_output['nat_instance_public_ip']
            if isinstance(nat_output, dict) and 'value' in nat_output:
                merged_config['nat_instance_public_ip'] = nat_output['value']
            elif isinstance(nat_output, str):
                merged_config['nat_instance_public_ip'] = nat_output
        
        # deployment_config.jsonのIPアドレスも統合
        if 'ec2_public_ip' in merged_config:
            merged_config['wordpress_public_ip'] = merged_config['ec2_public_ip']
        if 'nat_instance_ip' in merged_config:
            merged_config['nat_instance_public_ip'] = merged_config['nat_instance_ip']
        
        # RDS Endpoint
        if 'rds_endpoint' in terraform_output:
            rds_output = terraform_output['rds_endpoint']
            if isinstance(rds_output, dict) and 'value' in rds_output:
                merged_config['rds_endpoint'] = rds_output['value']
            elif isinstance(rds_output, str):
                merged_config['rds_endpoint'] = rds_output
        
        # SSH Key Name
        if 'ssh_key_name' in terraform_output:
            ssh_output = terraform_output['ssh_key_name']
            if isinstance(ssh_output, dict) and 'value' in ssh_output:
                merged_config['ssh_key_name'] = ssh_output['value']
            elif isinstance(ssh_output, str):
                merged_config['ssh_key_name'] = ssh_output
        
        logger.info("Terraform出力の動的値を統合")
    
    # 4. 環境変数で上書き（最高優先度）
    env_vars = {
        'WORDPRESS_DB_PASSWORD': 'db_password',
        'WORDPRESS_DB_USER': 'db_user',
        'WORDPRESS_DB_NAME': 'db_name',
        'SSH_PRIVATE_KEY_FILE': 'ssh_private_key_file',
        'SSH_USER': 'ssh_user',
    }
    
    for env_var, config_key in env_vars.items():
        env_value = os.getenv(env_var)
        if env_value:
            merged_config[config_key] = env_value
            # パスワードはログに出力しない
            if 'password' in config_key.lower():
                logger.debug(f"環境変数から設定: {config_key} = ***")
            else:
                logger.debug(f"環境変数から設定: {config_key} = {env_value}")
    
    logger.info(f"設定値の統合が完了しました: {len(merged_config)}個の設定値")
    return merged_config

# =============================================================================
# インベントリ生成関数
# =============================================================================

def generate_inventory_from_config(config: Dict[str, Any]) -> Dict[str, Any]:
    """統合された設定からAnsibleインベントリを生成"""
    logger = logging.getLogger(__name__)
    
    logger.info("統合設定からAnsibleインベントリを生成中...")
    
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
    
    # SSH鍵ファイルパスを設定
    ssh_key_name = config.get('ssh_key_name', 'ssh_key')
    ssh_key_file = config.get('ssh_private_key_file', f"~/.ssh/{ssh_key_name}")
    ssh_user = config.get('ssh_user', 'ec2-user')
    
    logger.info(f"使用するSSH鍵ファイル: {ssh_key_file}")
    logger.info(f"使用するSSHユーザー: {ssh_user}")
    
    # WordPress EC2の情報を設定
    wordpress_ip = config.get('wordpress_public_ip') or config.get('ec2_public_ip')
    if wordpress_ip and wordpress_ip != 'null':
        inventory['all']['children']['wordpress']['hosts']['wordpress_ec2'] = {
            'ansible_host': wordpress_ip,
            'ansible_user': ssh_user,
            'ansible_ssh_private_key_file': ssh_key_file,
            'ansible_ssh_common_args': '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null',
            'ansible_ssh_extra_args': '-o ConnectTimeout=30'
        }
        logger.info(f"WordPress EC2を追加: {wordpress_ip}")
    else:
        logger.warning("WordPress EC2のIPアドレスが設定されていません")
    
    # NATインスタンスの情報を設定
    nat_ip = config.get('nat_instance_public_ip') or config.get('nat_instance_ip')
    if nat_ip and nat_ip != 'null':
        inventory['all']['children']['nat_instance']['hosts']['nat_ec2'] = {
            'ansible_host': nat_ip,
            'ansible_user': ssh_user,
            'ansible_ssh_private_key_file': ssh_key_file,
            'ansible_ssh_common_args': '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null',
            'ansible_ssh_extra_args': '-o ConnectTimeout=30'
        }
        logger.info(f"NATインスタンスを追加: {nat_ip}")
    else:
        logger.warning("NATインスタンスのIPアドレスが設定されていません")
    
    logger.info(f"生成されたインベントリ: {inventory}")
    return inventory

def generate_inventory(terraform_output: Dict[str, Any]) -> Dict[str, Any]:
    """Terraformの出力からAnsibleインベントリを生成（後方互換性のため残す）"""
    logger = logging.getLogger(__name__)
    
    logger.info("Terraform出力からAnsibleインベントリを生成中...")
    
    # 設定値の統合
    tfvars = parse_terraform_tfvars()
    deployment_config = parse_deployment_config()
    config = merge_configurations(terraform_output, tfvars, deployment_config)
    
    return generate_inventory_from_config(config)

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
    standalone_mode = os.getenv('STANDALONE_MODE', 'false').lower() == 'true'
    
    # テンプレート作成モード
    if create_template:
        if create_inventory_template():
            logger.info("インベントリテンプレートの作成が完了しました")
            return 0
        else:
            logger.error("インベントリテンプレートの作成に失敗しました")
            return 1
    
    # 設定値の統合
    tfvars = parse_terraform_tfvars()
    deployment_config = parse_deployment_config()
    
    # Terraform出力の取得（失敗しても続行）
    terraform_output = None
    if not standalone_mode:
        terraform_output = run_terraform_output(terraform_dir)
        if not terraform_output:
            logger.warning("Terraform出力の取得に失敗しましたが、設定ファイルから続行します")
    
    # 設定値の統合
    config = merge_configurations(terraform_output, tfvars, deployment_config)
    
    if not config:
        logger.error("設定値の取得に失敗しました")
        return 1
    
    # インベントリを生成
    inventory = generate_inventory_from_config(config)
    
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