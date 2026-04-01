#!/usr/bin/env python3
"""
AWS G5 Instance Provisioning Script

Automates provisioning of an AWS G5.2xlarge (NVIDIA A10G GPU) instance
for running the Final Evolution Lab pipeline including:
  - UE5 compilation and cooking
  - CV preprocessing with GPU acceleration
  - DeepMotion processing
  - Pixel Streaming server

Requires: AWS CLI configured or AWS credentials in environment.

Usage:
    python provision_g5_instance.py --launch
    python provision_g5_instance.py --status
    python provision_g5_instance.py --terminate --instance-id i-xxxxx
"""

import argparse
import json
import os
import subprocess
import sys
import time
from pathlib import Path
from datetime import datetime


# Instance configuration
INSTANCE_CONFIG = {
    "instance_type": "g5.2xlarge",
    "ami_id": "ami-0c7217cdde317cfec",  # Ubuntu 22.04 LTS (us-east-1)
    "region": os.getenv("AWS_REGION", "us-east-1"),
    "key_name": os.getenv("AWS_KEY_NAME", "fel-gpu-key"),
    "security_group": os.getenv("AWS_SECURITY_GROUP", "fel-gpu-sg"),
    "subnet_id": os.getenv("AWS_SUBNET_ID", ""),
    "volume_size_gb": 500,
    "volume_type": "gp3",
    "tags": {
        "Name": "FEL-GPU-Build-Server",
        "Project": "FinalEvolutionLab",
        "Purpose": "UE5-Build-CV-Pipeline",
        "ManagedBy": "fel-provisioner"
    }
}

# AMIs per region (Ubuntu 22.04 LTS)
REGION_AMIS = {
    "us-east-1": "ami-0c7217cdde317cfec",
    "us-east-2": "ami-05fb0b8c1424f266b",
    "us-west-1": "ami-0ce2cb35386fc22e9",
    "us-west-2": "ami-008fe2fc65df48dac",
    "eu-west-1": "ami-0905a3c97561e0b69",
    "eu-central-1": "ami-0faab6bdbac9486fb",
    "ap-southeast-1": "ami-078c1149d8ad719a7",
}

USER_DATA_SCRIPT = """#!/bin/bash
set -e
export DEBIAN_FRONTEND=noninteractive

# Log everything
exec > >(tee /var/log/fel-setup.log) 2>&1
echo "=== FEL GPU Instance Setup Started: $(date) ==="

# Update system
apt-get update -y
apt-get upgrade -y

# Install NVIDIA drivers
apt-get install -y linux-headers-$(uname -r)
apt-get install -y nvidia-driver-535 nvidia-utils-535

# Install CUDA 12.x
wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
apt-get update
apt-get install -y cuda-toolkit-12-3

# Install Vulkan
apt-get install -y vulkan-tools libvulkan1 mesa-vulkan-drivers

# Install build essentials
apt-get install -y build-essential git git-lfs clang-16 mono-complete \
    python3-pip python3-venv nodejs npm docker.io docker-compose

# Install Python ML dependencies
pip3 install ultralytics opencv-python-headless scipy numpy torch torchvision

# Docker permissions
usermod -aG docker ubuntu

# Install AWS CLI v2
curl -s https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
unzip -q awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Create FEL workspace
mkdir -p /home/ubuntu/fel-workspace
chown ubuntu:ubuntu /home/ubuntu/fel-workspace

echo "=== FEL GPU Instance Setup Complete: $(date) ==="
echo "READY" > /home/ubuntu/.fel-setup-complete
"""


def aws_cli(cmd: list, capture=True) -> dict:
    """Run AWS CLI command and return parsed JSON output."""
    full_cmd = ["aws"] + cmd + ["--output", "json", "--region", INSTANCE_CONFIG["region"]]
    try:
        result = subprocess.run(full_cmd, capture_output=capture, text=True, check=True)
        if capture and result.stdout.strip():
            return json.loads(result.stdout)
        return {}
    except subprocess.CalledProcessError as e:
        print(f"[ERROR] AWS CLI failed: {e.stderr}")
        return {"error": e.stderr}
    except json.JSONDecodeError:
        return {"raw": result.stdout if capture else ""}


def check_prerequisites():
    """Verify AWS CLI and credentials are configured."""
    print("[CHECK] Verifying prerequisites...")
    
    # AWS CLI installed
    try:
        subprocess.run(["aws", "--version"], capture_output=True, check=True)
    except (FileNotFoundError, subprocess.CalledProcessError):
        print("[ERROR] AWS CLI not installed. Install from: https://aws.amazon.com/cli/")
        return False

    # AWS credentials
    result = aws_cli(["sts", "get-caller-identity"])
    if "error" in result:
        print("[ERROR] AWS credentials not configured. Run 'aws configure' first.")
        return False

    print(f"  AWS Account: {result.get('Account', 'unknown')}")
    print(f"  Region: {INSTANCE_CONFIG['region']}")
    return True


def create_key_pair():
    """Create SSH key pair if it doesn't exist."""
    key_name = INSTANCE_CONFIG["key_name"]
    key_path = Path.home() / ".ssh" / f"{key_name}.pem"

    if key_path.exists():
        print(f"[INFO] Key pair '{key_name}' already exists at {key_path}")
        return str(key_path)

    print(f"[INFO] Creating key pair: {key_name}")
    result = aws_cli(["ec2", "create-key-pair",
                      "--key-name", key_name,
                      "--key-type", "ed25519"])

    if "error" in result:
        if "InvalidKeyPair.Duplicate" in str(result.get("error", "")):
            print(f"[WARN] Key pair exists in AWS but not locally. Download from AWS Console.")
            return None
        print(f"[ERROR] Failed to create key pair: {result}")
        return None

    key_path.parent.mkdir(exist_ok=True)
    key_path.write_text(result.get("KeyMaterial", ""))
    key_path.chmod(0o600)
    print(f"  Key saved: {key_path}")
    return str(key_path)


def create_security_group():
    """Create security group for FEL GPU instance."""
    sg_name = INSTANCE_CONFIG["security_group"]
    print(f"[INFO] Setting up security group: {sg_name}")

    # Check existing
    result = aws_cli(["ec2", "describe-security-groups",
                      "--filters", f"Name=group-name,Values={sg_name}"])

    sgs = result.get("SecurityGroups", [])
    if sgs:
        sg_id = sgs[0]["GroupId"]
        print(f"  Existing SG: {sg_id}")
        return sg_id

    # Create new
    result = aws_cli(["ec2", "create-security-group",
                      "--group-name", sg_name,
                      "--description", "FEL GPU Build Server - SSH, HTTP, Pixel Streaming"])

    if "error" in result:
        print(f"[ERROR] Failed to create SG: {result}")
        return None

    sg_id = result.get("GroupId")
    print(f"  Created SG: {sg_id}")

    # Add ingress rules
    rules = [
        {"port": 22, "desc": "SSH"},
        {"port": 80, "desc": "HTTP"},
        {"port": 443, "desc": "HTTPS"},
        {"port": 8888, "desc": "Pixel Streaming Signalling"},
        {"port": 8889, "desc": "Pixel Streaming HTTPS"},
        {"port": 3000, "desc": "Frontend"},
        {"port": 3478, "desc": "TURN/STUN"},
    ]

    for rule in rules:
        aws_cli(["ec2", "authorize-security-group-ingress",
                 "--group-id", sg_id,
                 "--protocol", "tcp",
                 "--port", str(rule["port"]),
                 "--cidr", "0.0.0.0/0"])
        print(f"    Ingress: port {rule['port']} ({rule['desc']})")

    return sg_id


def launch_instance(sg_id: str) -> dict:
    """Launch G5.2xlarge instance."""
    region = INSTANCE_CONFIG["region"]
    ami_id = REGION_AMIS.get(region, INSTANCE_CONFIG["ami_id"])

    print(f"\n[LAUNCH] Starting {INSTANCE_CONFIG['instance_type']} instance...")
    print(f"  AMI: {ami_id}")
    print(f"  Region: {region}")

    import base64
    user_data_b64 = base64.b64encode(USER_DATA_SCRIPT.encode()).decode()

    cmd = [
        "ec2", "run-instances",
        "--image-id", ami_id,
        "--instance-type", INSTANCE_CONFIG["instance_type"],
        "--key-name", INSTANCE_CONFIG["key_name"],
        "--security-group-ids", sg_id,
        "--user-data", USER_DATA_SCRIPT,
        "--block-device-mappings",
        json.dumps([{
            "DeviceName": "/dev/sda1",
            "Ebs": {
                "VolumeSize": INSTANCE_CONFIG["volume_size_gb"],
                "VolumeType": INSTANCE_CONFIG["volume_type"],
                "DeleteOnTermination": True
            }
        }]),
        "--tag-specifications",
        json.dumps([{
            "ResourceType": "instance",
            "Tags": [{"Key": k, "Value": v} for k, v in INSTANCE_CONFIG["tags"].items()]
        }]),
        "--count", "1"
    ]

    if INSTANCE_CONFIG["subnet_id"]:
        cmd += ["--subnet-id", INSTANCE_CONFIG["subnet_id"]]

    result = aws_cli(cmd)
    if "error" in result:
        print(f"[ERROR] Launch failed: {result}")
        return {}

    instance = result.get("Instances", [{}])[0]
    instance_id = instance.get("InstanceId")
    print(f"  Instance ID: {instance_id}")
    print(f"  State: {instance.get('State', {}).get('Name')}")

    # Wait for running
    print("  Waiting for instance to start...")
    aws_cli(["ec2", "wait", "instance-running", "--instance-ids", instance_id])

    # Get public IP
    desc = aws_cli(["ec2", "describe-instances", "--instance-ids", instance_id])
    reservations = desc.get("Reservations", [{}])
    if reservations:
        inst = reservations[0].get("Instances", [{}])[0]
        public_ip = inst.get("PublicIpAddress", "pending")
        print(f"  Public IP: {public_ip}")
    else:
        public_ip = "unknown"

    launch_info = {
        "instance_id": instance_id,
        "instance_type": INSTANCE_CONFIG["instance_type"],
        "public_ip": public_ip,
        "region": region,
        "key_name": INSTANCE_CONFIG["key_name"],
        "launched_at": datetime.now().isoformat(),
        "ssh_command": f"ssh -i ~/.ssh/{INSTANCE_CONFIG['key_name']}.pem ubuntu@{public_ip}",
        "estimated_hourly_cost": "$1.21/hr (g5.2xlarge on-demand)"
    }

    # Save launch info
    info_path = Path.home() / ".fel-gpu-instance.json"
    info_path.write_text(json.dumps(launch_info, indent=2))
    print(f"\n  Launch info saved: {info_path}")
    print(f"  SSH: {launch_info['ssh_command']}")

    return launch_info


def get_instance_status():
    """Get status of FEL GPU instances."""
    result = aws_cli(["ec2", "describe-instances",
                      "--filters",
                      "Name=tag:Project,Values=FinalEvolutionLab",
                      "Name=instance-state-name,Values=running,pending,stopping,stopped"])

    instances = []
    for r in result.get("Reservations", []):
        for i in r.get("Instances", []):
            instances.append({
                "id": i.get("InstanceId"),
                "type": i.get("InstanceType"),
                "state": i.get("State", {}).get("Name"),
                "ip": i.get("PublicIpAddress", "N/A"),
                "launched": i.get("LaunchTime", "")
            })

    if instances:
        print("\nFEL GPU Instances:")
        for inst in instances:
            print(f"  {inst['id']} | {inst['type']} | {inst['state']} | {inst['ip']} | {inst['launched']}")
    else:
        print("\nNo running FEL GPU instances found.")

    return instances


def terminate_instance(instance_id: str):
    """Terminate a specific instance."""
    print(f"[TERMINATE] Terminating instance: {instance_id}")
    result = aws_cli(["ec2", "terminate-instances", "--instance-ids", instance_id])
    if "error" not in result:
        print(f"  Instance {instance_id} termination initiated.")
    else:
        print(f"  Error: {result}")


def main():
    parser = argparse.ArgumentParser(description="AWS G5 Instance Provisioner for FEL")
    parser.add_argument("--launch", action="store_true", help="Launch new G5 instance")
    parser.add_argument("--status", action="store_true", help="Check instance status")
    parser.add_argument("--terminate", action="store_true", help="Terminate instance")
    parser.add_argument("--instance-id", help="Instance ID for terminate")
    parser.add_argument("--region", help="AWS region override")
    args = parser.parse_args()

    if args.region:
        INSTANCE_CONFIG["region"] = args.region

    if args.launch:
        if not check_prerequisites():
            sys.exit(1)
        create_key_pair()
        sg_id = create_security_group()
        if sg_id:
            launch_instance(sg_id)
    elif args.status:
        get_instance_status()
    elif args.terminate:
        if args.instance_id:
            terminate_instance(args.instance_id)
        else:
            print("[ERROR] Provide --instance-id to terminate")
    else:
        parser.print_help()


if __name__ == "__main__":
    main()
