#!/usr/bin/env python3
"""
Terraform連携用Ansibleフィルター
Terraformの出力とstateファイルから値を取得するためのフィルターを提供
"""

import json
import os
from ansible.errors import AnsibleFilterError
from ansible.module_utils.common.text.converters import to_native

class FilterModule(object):
    """Terraform連携用フィルター"""

    def filters(self):
        return {
            'terraform_output': self.terraform_output,
            'terraform_state': self.terraform_state,
            'terraform_value': self.terraform_value,
            'load_terraform_config': self.load_terraform_config
        }

    def terraform_output(self, output_file, key=None):
        """
        Terraformの出力ファイルから値を取得
        
        Args:
            output_file (str): terraform_output.jsonのパス
            key (str): 取得したいキー（Noneの場合は全データ）
        
        Returns:
            dict or str: 指定されたキーの値または全データ
        """
        try:
            if not os.path.exists(output_file):
                return None
            
            with open(output_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            if key is None:
                return data
            
            # ネストしたキーの処理（例: "wordpress_public_ip.value"）
            if '.' in key:
                keys = key.split('.')
                result = data
                for k in keys:
                    if isinstance(result, dict) and k in result:
                        result = result[k]
                    else:
                        return None
                return result
            
            return data.get(key)
            
        except Exception as e:
            raise AnsibleFilterError(f"Terraform出力の読み取りに失敗: {to_native(e)}")

    def terraform_state(self, state_file, resource_type=None, resource_name=None):
        """
        Terraformのstateファイルからリソース情報を取得
        
        Args:
            state_file (str): terraform.tfstateのパス
            resource_type (str): リソースタイプ（例: "aws_instance"）
            resource_name (str): リソース名（例: "wordpress"）
        
        Returns:
            dict: リソース情報
        """
        try:
            if not os.path.exists(state_file):
                return None
            
            with open(state_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            resources = data.get('resources', [])
            
            if resource_type and resource_name:
                # 特定のリソースを検索
                for resource in resources:
                    if (resource.get('type') == resource_type and 
                        resource.get('name') == resource_name):
                        return resource.get('instances', [{}])[0].get('attributes', {})
            
            return resources
            
        except Exception as e:
            raise AnsibleFilterError(f"Terraform stateの読み取りに失敗: {to_native(e)}")

    def terraform_value(self, terraform_data, path):
        """
        Terraformのデータから指定されたパスの値を取得
        
        Args:
            terraform_data (dict): Terraformのデータ
            path (str): 値のパス（例: "wordpress_public_ip.value"）
        
        Returns:
            any: 指定されたパスの値
        """
        try:
            if not terraform_data:
                return None
            
            keys = path.split('.')
            result = terraform_data
            
            for key in keys:
                if isinstance(result, dict) and key in result:
                    result = result[key]
                elif isinstance(result, list) and key.isdigit():
                    index = int(key)
                    if 0 <= index < len(result):
                        result = result[index]
                    else:
                        return None
                else:
                    return None
            
            return result
            
        except Exception as e:
            raise AnsibleFilterError(f"Terraform値の取得に失敗: {to_native(e)}")

    def load_terraform_config(self, config_file):
        """
        Terraform設定ファイル（terraform.tfvars）を読み取り
        
        Args:
            config_file (str): terraform.tfvarsのパス
        
        Returns:
            dict: 設定データ
        """
        try:
            if not os.path.exists(config_file):
                return {}
            
            config = {}
            
            with open(config_file, 'r', encoding='utf-8') as f:
                for line in f:
                    line = line.strip()
                    # コメントと空行をスキップ
                    if not line or line.startswith('#') or line.startswith('//'):
                        continue
                    
                    # 変数定義を解析
                    if '=' in line:
                        key, value = line.split('=', 1)
                        key = key.strip()
                        value = value.strip().strip('"').strip("'")
                        
                        # ブール値の処理
                        if value.lower() in ['true', 'false']:
                            value = value.lower() == 'true'
                        # 数値の処理
                        elif value.isdigit():
                            value = int(value)
                        # CIDRブロックの処理
                        elif '/' in value and all(part.isdigit() or part == '.' for part in value.split('/')[0].split('.')):
                            # CIDRブロックとして保持
                            pass
                        
                        config[key] = value
            
            return config
            
        except Exception as e:
            raise AnsibleFilterError(f"Terraform設定の読み取りに失敗: {to_native(e)}")
