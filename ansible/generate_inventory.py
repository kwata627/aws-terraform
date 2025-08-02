#!/usr/bin/env python3
"""
Terraformの出力からAnsibleインベントリを動的に生成するスクリプト
"""

import json
import subprocess
import sys
import os

def run_terraform_output():
    """Terraformの出力を取得"""
    try:
        result = subprocess.run(
            ['terraform', 'output', '-json'],
            capture_output=True,
            text=True,
            cwd='..'
        )
        if result.returncode != 0:
            print(f"Error running terraform output: {result.stderr}")
            return None
        return json.loads(result.stdout)
    except Exception as e:
        print(f"Error: {e}")
        return None

def generate_inventory(terraform_output):
    """Terraformの出力からAnsibleインベントリを生成"""
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
        inventory['all']['children']['wordpress']['hosts']['wordpress_ec2'] = {
            'ansible_host': wordpress_ip,
            'ansible_user': 'ec2-user',
            'ansible_ssh_private_key_file': '~/.ssh/id_rsa',
            'ansible_ssh_common_args': '-o StrictHostKeyChecking=no'
        }
    
    # NATインスタンスの情報を取得
    if 'nat_instance_public_ip' in terraform_output:
        nat_ip = terraform_output['nat_instance_public_ip']['value']
        inventory['all']['children']['nat_instance']['hosts']['nat_ec2'] = {
            'ansible_host': nat_ip,
            'ansible_user': 'ec2-user',
            'ansible_ssh_private_key_file': '~/.ssh/id_rsa',
            'ansible_ssh_common_args': '-o StrictHostKeyChecking=no'
        }
    
    return inventory

def write_inventory(inventory, output_file='inventory/hosts.yml'):
    """インベントリファイルを書き込み"""
    import yaml
    
    # YAMLファイルに書き込み
    with open(output_file, 'w') as f:
        yaml.dump(inventory, f, default_flow_style=False, sort_keys=False)
    
    print(f"Inventory generated: {output_file}")
    print("Hosts:")
    for group, hosts in inventory['all']['children'].items():
        for hostname, config in hosts['hosts'].items():
            print(f"  {hostname}: {config['ansible_host']}")

def main():
    """メイン関数"""
    print("Generating Ansible inventory from Terraform output...")
    
    # Terraformの出力を取得
    terraform_output = run_terraform_output()
    if not terraform_output:
        print("Failed to get Terraform output")
        sys.exit(1)
    
    # インベントリを生成
    inventory = generate_inventory(terraform_output)
    
    # インベントリファイルを書き込み
    write_inventory(inventory)
    
    print("Inventory generation completed!")

if __name__ == '__main__':
    main() 