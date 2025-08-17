#!/usr/bin/env python3
"""
変数の読み込みと変換をテストするスクリプト
"""

import sys
import os
import logging

# スクリプトディレクトリをパスに追加
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from load_terraform_vars import (
    parse_terraform_tfvars,
    parse_deployment_config,
    merge_configurations,
    convert_terraform_to_ansible_vars
)

def setup_logging():
    """ログ設定"""
    logging.basicConfig(
        level=logging.DEBUG,
        format='%(asctime)s - %(levelname)s - %(message)s'
    )

def test_variable_loading():
    """変数の読み込みと変換をテスト"""
    logger = logging.getLogger(__name__)
    
    logger.info("=== 変数読み込みテスト開始 ===")
    
    # 1. terraform.tfvarsの読み込み
    logger.info("1. terraform.tfvarsの読み込み")
    tfvars = parse_terraform_tfvars("../terraform.tfvars")
    if tfvars:
        logger.info(f"terraform.tfvarsから{len(tfvars)}個の設定値を読み込み")
        logger.debug("terraform.tfvarsの内容:")
        for key, value in tfvars.items():
            if 'password' in key.lower():
                logger.debug(f"  {key}: ***")
            else:
                logger.debug(f"  {key}: {value}")
    else:
        logger.error("terraform.tfvarsの読み込みに失敗")
        return False
    
    # 2. deployment_config.jsonの読み込み
    logger.info("2. deployment_config.jsonの読み込み")
    deployment_config = parse_deployment_config("../deployment_config.json")
    if deployment_config:
        logger.info(f"deployment_config.jsonから{len(deployment_config)}個のセクションを読み込み")
        if 'production' in deployment_config:
            logger.debug("productionセクションの内容:")
            for key, value in deployment_config['production'].items():
                if 'password' in key.lower():
                    logger.debug(f"  {key}: ***")
                else:
                    logger.debug(f"  {key}: {value}")
    else:
        logger.warn("deployment_config.jsonの読み込みに失敗")
    
    # 3. 設定値の統合
    logger.info("3. 設定値の統合")
    merged_config = merge_configurations(
        terraform_output=None,  # 単体実行モード
        tfvars=tfvars,
        deployment_config=deployment_config
    )
    
    if merged_config:
        logger.info(f"統合された設定: {len(merged_config)}個の設定値")
        logger.debug("統合された設定の内容:")
        for key, value in merged_config.items():
            if 'password' in key.lower():
                logger.debug(f"  {key}: ***")
            else:
                logger.debug(f"  {key}: {value}")
    else:
        logger.error("設定値の統合に失敗")
        return False
    
    # 4. Ansible変数への変換
    logger.info("4. Ansible変数への変換")
    ansible_vars = convert_terraform_to_ansible_vars(merged_config)
    
    if ansible_vars:
        logger.info(f"Ansible変数: {len(ansible_vars)}個の変数")
        logger.info("生成されたAnsible変数:")
        for key, value in ansible_vars.items():
            if 'password' in key.lower():
                logger.info(f"  {key}: ***")
            else:
                logger.info(f"  {key}: {value}")
    else:
        logger.error("Ansible変数への変換に失敗")
        return False
    
    logger.info("=== 変数読み込みテスト完了 ===")
    return True

if __name__ == '__main__':
    setup_logging()
    success = test_variable_loading()
    sys.exit(0 if success else 1)
