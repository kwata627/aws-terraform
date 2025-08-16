#!/usr/bin/env python3
"""
Terraformの出力からAnsible変数を読み込むスクリプト
terraform.tfvarsを直接読み込む機能を追加し、Ansible単体実行時にTerraformで設定された値を使用できるようにする
"""

import json
import subprocess
import sys
import os
import yaml
import logging
import re
from typing import Dict, Any, Optional
from pathlib import Path

# =============================================================================
# 定数定義
# =============================================================================

DEFAULT_TERRAFORM_DIR = ".."
DEFAULT_TERRAFORM_TFVARS = "../terraform.tfvars"
DEFAULT_DEPLOYMENT_CONFIG = "../deployment_config.json"
DEFAULT_OUTPUT_FILE = "group_vars/all/terraform_vars.yml"
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
            logging.FileHandler(f"terraform_vars_{os.getenv('LOG_FILE', 'default')}.log")
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
        
        # RDS Endpoint
        if 'rds_endpoint' in terraform_output:
            rds_output = terraform_output['rds_endpoint']
            if isinstance(rds_output, dict) and 'value' in rds_output:
                merged_config['rds_endpoint'] = rds_output['value']
            elif isinstance(rds_output, str):
                merged_config['rds_endpoint'] = rds_output
        
        # RDS Username
        if 'db_username' in terraform_output:
            db_username_output = terraform_output['db_username']
            if isinstance(db_username_output, dict) and 'value' in db_username_output:
                merged_config['wp_db_user'] = db_username_output['value']
            elif isinstance(db_username_output, str):
                merged_config['wp_db_user'] = db_username_output
        
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
# 変数変換関数
# =============================================================================

def convert_terraform_to_ansible_vars(config: Dict[str, Any]) -> Dict[str, Any]:
    """統合された設定をAnsible変数に変換"""
    logger = logging.getLogger(__name__)
    
    logger.info("統合設定をAnsible変数に変換中...")
    
    ansible_vars = {}
    
    # ドメイン名
    if 'domain_name' in config:
        domain_name = config['domain_name']
        if domain_name:
            ansible_vars['domain_name'] = domain_name
            ansible_vars['wordpress_domain'] = domain_name
            logger.info(f"ドメイン名を設定: {domain_name}")
    
    # RDSエンドポイント
    if 'rds_endpoint' in config:
        rds_endpoint = config['rds_endpoint']
        if rds_endpoint:
            ansible_vars['rds_endpoint'] = rds_endpoint
            logger.info(f"RDSエンドポイントを設定: {rds_endpoint}")
    
    # S3バケット名
    if 's3_bucket_name' in config:
        s3_bucket_name = config['s3_bucket_name']
        if s3_bucket_name:
            ansible_vars['s3_bucket_name'] = s3_bucket_name
            logger.info(f"S3バケット名を設定: {s3_bucket_name}")
    
    # プロジェクト名
    if 'project' in config:
        project_name = config['project']
        if project_name:
            ansible_vars['project_name'] = project_name
            logger.info(f"プロジェクト名を設定: {project_name}")
    
    # WordPress URL
    if 'wordpress_https_url' in config:
        wordpress_url = config['wordpress_https_url']
        if wordpress_url:
            ansible_vars['wordpress_url'] = wordpress_url
            logger.info(f"WordPress URLを設定: {wordpress_url}")
    elif 'domain_name' in config:
        # ドメイン名からURLを生成
        domain_name = config['domain_name']
        if domain_name:
            ansible_vars['wordpress_url'] = f"https://{domain_name}"
            logger.info(f"WordPress URLを生成: {ansible_vars['wordpress_url']}")
    
    # SSH鍵情報
    if 'ssh_key_name' in config:
        ssh_key_name = config['ssh_key_name']
        if ssh_key_name:
            ansible_vars['ssh_key_name'] = ssh_key_name
            logger.info(f"SSH鍵名を設定: {ssh_key_name}")
    
    # データベース設定
    if 'db_password' in config:
        ansible_vars['wp_db_password'] = config['db_password']
        logger.info("データベースパスワードを設定")
    
    # データベースユーザー名（TerraformのRDSモジュールのデフォルト値を使用）
    if 'wp_db_user' in config:
        ansible_vars['wp_db_user'] = config['wp_db_user']
        logger.info(f"データベースユーザーを設定: {config['wp_db_user']}")
    elif 'db_username' in config:
        ansible_vars['wp_db_user'] = config['db_username']
        logger.info(f"データベースユーザーを設定: {config['db_username']}")
    elif 'db_user' in config:
        ansible_vars['wp_db_user'] = config['db_user']
        logger.info(f"データベースユーザーを設定: {config['db_user']}")
    else:
        ansible_vars['wp_db_user'] = 'admin'  # RDSモジュールのデフォルト値
        logger.info("データベースユーザーをデフォルト値に設定: admin")
    
    if 'db_name' in config:
        ansible_vars['wp_db_name'] = config['db_name']
        logger.info(f"データベース名を設定: {config['db_name']}")
    else:
        ansible_vars['wp_db_name'] = 'wordpress'
        logger.info("データベース名をデフォルト値に設定: wordpress")
    
    # SSL設定
    if 'enable_ssl_setup' in config:
        ansible_vars['enable_ssl_setup'] = config['enable_ssl_setup']
        logger.info(f"SSL設定を有効化: {config['enable_ssl_setup']}")
    
    if 'enable_lets_encrypt' in config:
        ansible_vars['enable_lets_encrypt'] = config['enable_lets_encrypt']
        logger.info(f"Let's Encryptを有効化: {config['enable_lets_encrypt']}")
    
    if 'lets_encrypt_email' in config:
        ansible_vars['lets_encrypt_email'] = config['lets_encrypt_email']
        logger.info(f"Let's Encryptメールアドレスを設定: {config['lets_encrypt_email']}")
    
    # 環境変数から追加の変数を取得
    env_vars = {
        'WORDPRESS_DB_PASSWORD': 'wp_db_password',
        'WORDPRESS_DB_USER': 'wp_db_user',
        'WORDPRESS_DB_NAME': 'wp_db_name',
        'SSH_PRIVATE_KEY_PATH': 'ssh_private_key',
        'SSH_PUBLIC_KEY_PATH': 'ssh_public_key',
    }
    
    for env_var, ansible_var in env_vars.items():
        env_value = os.getenv(env_var)
        if env_value:
            ansible_vars[ansible_var] = env_value
            logger.info(f"環境変数から設定: {ansible_var} = {env_value}")
    
    logger.info("Ansible変数への変換が完了しました")
    return ansible_vars

# =============================================================================
# ファイル操作関数
# =============================================================================

def write_ansible_vars(ansible_vars: Dict[str, Any], output_file: str = DEFAULT_OUTPUT_FILE) -> bool:
    """Ansible変数ファイルを書き込み"""
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
            yaml.dump(ansible_vars, f, default_flow_style=False, sort_keys=False, allow_unicode=True)
        
        logger.info(f"Ansible変数ファイルを生成しました: {output_file}")
        
        # 生成された変数の表示
        logger.info("生成された変数:")
        for key, value in ansible_vars.items():
            # パスワードは隠す
            if 'password' in key.lower():
                logger.info(f"  {key}: ***")
            else:
                logger.info(f"  {key}: {value}")
        
        return True
        
    except Exception as e:
        logger.error(f"Ansible変数ファイルの書き込みに失敗: {e}")
        return False

# =============================================================================
# メイン処理
# =============================================================================

def main():
    """メイン関数"""
    # ログ設定
    logger = setup_logging(os.getenv('LOG_LEVEL', DEFAULT_LOG_LEVEL))
    
    logger.info("Terraform変数のAnsible変数への変換を開始...")
    
    # 引数の解析
    output_file = os.getenv('ANSIBLE_VARS_FILE', DEFAULT_OUTPUT_FILE)
    terraform_dir = os.getenv('TERRAFORM_DIR', DEFAULT_TERRAFORM_DIR)
    standalone_mode = os.getenv('STANDALONE_MODE', 'false').lower() == 'true'
    
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
    
    # Ansible変数に変換
    ansible_vars = convert_terraform_to_ansible_vars(config)
    
    if not ansible_vars:
        logger.warning("変換可能な変数が見つかりませんでした")
        return 0
    
    # Ansible変数ファイルを書き込み
    if not write_ansible_vars(ansible_vars, output_file):
        logger.error("Ansible変数ファイルの書き込みに失敗しました")
        return 1
    
    logger.info("Terraform変数のAnsible変数への変換が完了しました")
    return 0

if __name__ == '__main__':
    sys.exit(main())
