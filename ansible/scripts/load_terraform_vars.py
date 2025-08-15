#!/usr/bin/env python3
"""
Terraformの出力からAnsible変数を読み込むスクリプト
Ansible単独実行時にTerraformで設定された値を使用できるようにする
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

DEFAULT_TERRAFORM_DIR = ".."
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
# 変数変換関数
# =============================================================================

def convert_terraform_to_ansible_vars(terraform_output: Dict[str, Any]) -> Dict[str, Any]:
    """Terraform出力をAnsible変数に変換"""
    logger = logging.getLogger(__name__)
    
    logger.info("Terraform出力をAnsible変数に変換中...")
    
    ansible_vars = {}
    
    # domain_analysis出力からドメイン名を取得
    if 'domain_analysis' in terraform_output:
        domain_analysis = terraform_output['domain_analysis']['value']
        if domain_analysis and 'domain_name' in domain_analysis:
            domain_name = domain_analysis['domain_name']
            if domain_name:
                ansible_vars['domain_name'] = domain_name
                ansible_vars['wordpress_domain'] = domain_name
                logger.info(f"ドメイン名を設定: {domain_name}")
    
    # RDSエンドポイント
    if 'rds_endpoint' in terraform_output:
        rds_endpoint = terraform_output['rds_endpoint']['value']
        if rds_endpoint:
            ansible_vars['rds_endpoint'] = rds_endpoint
            logger.info(f"RDSエンドポイントを設定: {rds_endpoint}")
    
    # S3バケット名
    if 's3_bucket_name' in terraform_output:
        s3_bucket_name = terraform_output['s3_bucket_name']['value']
        if s3_bucket_name:
            ansible_vars['s3_bucket_name'] = s3_bucket_name
            logger.info(f"S3バケット名を設定: {s3_bucket_name}")
    
    # プロジェクト名
    if 'project' in terraform_output:
        project_name = terraform_output['project']['value']
        if project_name:
            ansible_vars['project_name'] = project_name
            logger.info(f"プロジェクト名を設定: {project_name}")
    
    # WordPress URL
    if 'wordpress_https_url' in terraform_output:
        wordpress_url = terraform_output['wordpress_https_url']['value']
        if wordpress_url:
            ansible_vars['wordpress_url'] = wordpress_url
            logger.info(f"WordPress URLを設定: {wordpress_url}")
    
    # SSH鍵情報
    if 'ssh_key_name' in terraform_output:
        ssh_key_name = terraform_output['ssh_key_name']['value']
        if ssh_key_name:
            ansible_vars['ssh_key_name'] = ssh_key_name
            logger.info(f"SSH鍵名を設定: {ssh_key_name}")
    
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
    
    # Terraformの出力を取得
    terraform_output = run_terraform_output(terraform_dir)
    if not terraform_output:
        logger.error("Terraform出力の取得に失敗しました")
        return 1
    
    # Ansible変数に変換
    ansible_vars = convert_terraform_to_ansible_vars(terraform_output)
    
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
