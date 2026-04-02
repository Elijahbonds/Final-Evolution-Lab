#!/usr/bin/env python3
"""
Final Evolution Lab — AWS G5.2xlarge Provisioning for us-east-2
Complete provisioning with error handling, bootstrap, and pipeline execution.

Usage:
  # With key pair name (uses existing key pair):
  python3 provision_g5_useast2.py --key-pair fel-gpu-key

  # Create new key pair automatically:
  python3 provision_g5_useast2.py --create-key

  # Dry run (test permissions only):
  python3 provision_g5_useast2.py --dry-run

  # With all options:
  python3 provision_g5_useast2.py --create-key --github-token ghp_xxx --notification-email you@example.com
"""

import argparse
import json
import os
import sys
import time
import stat
from datetime import datetime
from pathlib import Path

try:
    import boto3
    from botocore.exceptions import ClientError, WaiterError, NoCredentialsError
except ImportError:
    print("ERROR: boto3 required. Install: pip install boto3")
    sys.exit(1)


# ─── Configuration ───────────────────────────────────────────────────────────

REGION = "us-east-2"
INSTANCE_TYPE = "g5.2xlarge"
VOLUME_SIZE_GB = 500
VOLUME_TYPE = "gp3"
VOLUME_IOPS = 6000
VOLUME_THROUGHPUT = 400
PROJECT_TAG = "FEL"
INSTANCE_NAME = "FinalEvolutionLab-Build"
VPC_CIDR = "10.0.0.0/16"
SUBNET_CIDR = "10.0.1.0/24"

# Ubuntu 22.04 AMI search pattern and known AMIs for us-east-2
UBUNTU_AMI_PATTERN = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
UBUNTU_AMI_OWNER = "099720109477"
# Fallback AMI if DescribeImages fails (Ubuntu 22.04 LTS in us-east-2)
FALLBACK_AMI_USEAST2 = "ami-0ea3c35c5c3284d82"  # Ubuntu 22.04 LTS 20240126

REQUIRED_PORTS = [
    {"port": 22,   "proto": "tcp", "desc": "SSH"},
    {"port": 80,   "proto": "tcp", "desc": "HTTP"},
    {"port": 443,  "proto": "tcp", "desc": "HTTPS"},
    {"port": 3000, "proto": "tcp", "desc": "Web Frontend"},
    {"port": 8888, "proto": "tcp", "desc": "Pixel Streaming WS"},
    {"port": 8889, "proto": "tcp", "desc": "Pixel Streaming Streamer"},
    {"port": 3478, "proto": "tcp", "desc": "TURN TCP"},
    {"port": 3478, "proto": "udp", "desc": "TURN UDP"},
]

UDP_RANGES = [
    {"from": 49152, "to": 49200, "desc": "TURN Media Relay"},
]

# ─── IAM Policy Requirements ────────────────────────────────────────────────

REQUIRED_PERMISSIONS = """
Required IAM Permissions for Provisioning:
──────────────────────────────────────────
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:RunInstances",
                "ec2:DescribeInstances",
                "ec2:DescribeImages",
                "ec2:DescribeInstanceTypes",
                "ec2:DescribeInstanceTypeOfferings",
                "ec2:CreateVpc",
                "ec2:CreateSubnet",
                "ec2:CreateInternetGateway",
                "ec2:AttachInternetGateway",
                "ec2:CreateRouteTable",
                "ec2:CreateRoute",
                "ec2:AssociateRouteTable",
                "ec2:CreateSecurityGroup",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:AllocateAddress",
                "ec2:AssociateAddress",
                "ec2:CreateKeyPair",
                "ec2:DescribeKeyPairs",
                "ec2:CreateTags",
                "ec2:ModifyVpcAttribute",
                "ec2:ModifySubnetAttribute",
                "ec2:DescribeVpcs",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "iam:CreateRole",
                "iam:CreateInstanceProfile",
                "iam:AddRoleToInstanceProfile",
                "iam:AttachRolePolicy",
                "iam:PassRole"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "service-quotas:GetServiceQuota"
            ],
            "Resource": "*"
        }
    ]
}
"""


def log(msg, level="INFO"):
    ts = datetime.now().strftime("%H:%M:%S")
    prefix = {"INFO": "ℹ️", "OK": "✅", "WARN": "⚠️", "ERR": "❌", "STEP": "──"}.get(level, "")
    print(f"  [{ts}] {prefix} {msg}")


def get_bootstrap_userdata(credentials: dict) -> str:
    """Generate cloud-init userdata for GPU instance bootstrap."""
    creds_block = "\n".join(f'export {k}="{v}"' for k, v in credentials.items() if v)
    return f"""#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/fel-bootstrap.log) 2>&1
echo "=== FEL Bootstrap Starting $(date) ==="
export DEBIAN_FRONTEND=noninteractive

# Save credentials
mkdir -p /home/ubuntu/.fel
cat > /home/ubuntu/.fel/credentials.env << 'CREDS'
{creds_block}
CREDS
chmod 600 /home/ubuntu/.fel/credentials.env
chown -R ubuntu:ubuntu /home/ubuntu/.fel

# System update
apt-get update -y
apt-get upgrade -y
apt-get install -y \\
    build-essential git curl wget unzip jq htop tmux \\
    python3 python3-pip python3-venv \\
    docker.io docker-compose \\
    nginx certbot python3-certbot-nginx \\
    linux-headers-$(uname -r)

# Node.js 20.x
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

# NVIDIA Driver 535
apt-get install -y nvidia-driver-535 nvidia-utils-535

# CUDA 12.3
wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
dpkg -i cuda-keyring_1.1-1_all.deb
apt-get update
apt-get install -y cuda-toolkit-12-3

# Vulkan SDK
wget -qO- https://packages.lunarg.com/lunarg-signing-key-pub.asc | apt-key add -
wget -qO /etc/apt/sources.list.d/lunarg-vulkan-jammy.list https://packages.lunarg.com/vulkan/lunarg-vulkan-jammy.list
apt-get update
apt-get install -y vulkan-sdk

# UE5 Dependencies
apt-get install -y \\
    libfreetype6-dev libfreeimage-dev libpng-dev libjpeg-dev \\
    libxi-dev libxrandr-dev libxrender-dev mesa-vulkan-drivers \\
    mono-complete dotnet-sdk-6.0

# Docker permissions
usermod -aG docker ubuntu

# Source credentials for project clone
source /home/ubuntu/.fel/credentials.env

# Clone or transfer project
GH_TOKEN="${{GITHUB_TOKEN:-}}"
if [ -n "$GH_TOKEN" ]; then
    cd /home/ubuntu
    git clone "https://${{GH_TOKEN}}@github.com/finalevolutiongroup/final-evolution-lab.git" rork-final-evolution-lab 2>/dev/null || true
fi

# Validate GPU
echo "=== GPU Validation ==="
nvidia-smi || echo "WARNING: nvidia-smi failed — driver may need reboot"

echo "=== FEL Bootstrap Complete $(date) ==="
echo "NOTE: Reboot recommended to fully load NVIDIA drivers"
# Auto-reboot to load drivers
reboot
"""


def find_ami(ec2_client):
    """Find latest Ubuntu 22.04 AMI, with fallback."""
    try:
        resp = ec2_client.describe_images(
            Owners=[UBUNTU_AMI_OWNER],
            Filters=[
                {"Name": "name", "Values": [UBUNTU_AMI_PATTERN]},
                {"Name": "virtualization-type", "Values": ["hvm"]},
                {"Name": "architecture", "Values": ["x86_64"]},
            ],
        )
        images = sorted(resp["Images"], key=lambda x: x["CreationDate"], reverse=True)
        if images:
            ami = images[0]
            log(f"AMI found: {ami['ImageId']} ({ami['Name']})", "OK")
            return ami["ImageId"]
    except ClientError as e:
        log(f"DescribeImages failed: {e.response['Error']['Message']}", "WARN")

    log(f"Using fallback AMI for us-east-2: {FALLBACK_AMI_USEAST2}", "WARN")
    return FALLBACK_AMI_USEAST2


def check_quota(session):
    """Check G/VT instance vCPU quota."""
    try:
        sq = session.client("service-quotas")
        resp = sq.get_service_quota(ServiceCode="ec2", QuotaCode="L-DB2F2C47")
        quota = int(resp["Quota"]["Value"])
        log(f"G/VT On-Demand vCPU quota: {quota} (need 8 for g5.2xlarge)", "INFO")
        if quota < 8:
            log("INSUFFICIENT QUOTA!", "ERR")
            log(f"Request increase: https://us-east-2.console.aws.amazon.com/servicequotas/home/services/ec2/quotas/L-DB2F2C47", "INFO")
            return False
        return True
    except Exception as e:
        log(f"Could not check quota: {e}", "WARN")
        return True  # Proceed anyway


def create_or_get_key_pair(ec2_client, key_name=None, create=False):
    """Create or use existing key pair."""
    if create:
        key_name = f"fel-gpu-{REGION}-{int(time.time())}"
        log(f"Creating new key pair: {key_name}", "STEP")
        resp = ec2_client.create_key_pair(KeyName=key_name)
        pem_path = Path.home() / f"{key_name}.pem"
        pem_path.write_text(resp["KeyMaterial"])
        pem_path.chmod(0o400)
        log(f"Private key saved: {pem_path}", "OK")
        return key_name, str(pem_path)

    if key_name:
        try:
            ec2_client.describe_key_pairs(KeyNames=[key_name])
            log(f"Key pair found: {key_name}", "OK")
            return key_name, f"{key_name}.pem"
        except ClientError:
            log(f"Key pair '{key_name}' not found in {REGION}", "ERR")
            raise

    # List available
    resp = ec2_client.describe_key_pairs()
    kps = [kp["KeyName"] for kp in resp["KeyPairs"]]
    if kps:
        log(f"Available key pairs: {', '.join(kps)}", "INFO")
        return kps[0], f"{kps[0]}.pem"
    else:
        log("No key pairs found. Use --create-key to create one.", "ERR")
        sys.exit(1)


def create_vpc_stack(ec2, ec2_client):
    """Create VPC, subnet, IGW, route table."""
    log("Creating VPC...", "STEP")
    vpc = ec2.create_vpc(CidrBlock=VPC_CIDR)
    vpc.wait_until_available()
    vpc.create_tags(Tags=[
        {"Key": "Name", "Value": "FEL-VPC"},
        {"Key": "Project", "Value": PROJECT_TAG},
    ])
    vpc.modify_attribute(EnableDnsSupport={"Value": True})
    vpc.modify_attribute(EnableDnsHostnames={"Value": True})
    log(f"VPC: {vpc.id}", "OK")

    # Pick first AZ with g5 support
    offerings = ec2_client.describe_instance_type_offerings(
        LocationType="availability-zone",
        Filters=[{"Name": "instance-type", "Values": [INSTANCE_TYPE]}],
    )
    azs = sorted(set(o["Location"] for o in offerings["InstanceTypeOfferings"]))
    az = azs[0] if azs else f"{REGION}a"
    log(f"Using AZ: {az} (g5 available in: {', '.join(azs)})", "INFO")

    subnet = vpc.create_subnet(CidrBlock=SUBNET_CIDR, AvailabilityZone=az)
    subnet.meta.client.modify_subnet_attribute(
        SubnetId=subnet.id, MapPublicIpOnLaunch={"Value": True}
    )
    subnet.create_tags(Tags=[{"Key": "Name", "Value": "FEL-Subnet"}, {"Key": "Project", "Value": PROJECT_TAG}])
    log(f"Subnet: {subnet.id} in {az}", "OK")

    igw = ec2.create_internet_gateway()
    igw.create_tags(Tags=[{"Key": "Name", "Value": "FEL-IGW"}])
    igw.attach_to_vpc(VpcId=vpc.id)

    rt = vpc.create_route_table()
    rt.create_route(DestinationCidrBlock="0.0.0.0/0", GatewayId=igw.id)
    rt.associate_with_subnet(SubnetId=subnet.id)
    log("Networking configured (IGW + routes)", "OK")

    return vpc, subnet


def create_security_group(ec2_client, vpc_id, ssh_cidr="0.0.0.0/0"):
    """Create security group with all required ports."""
    log("Creating Security Group...", "STEP")
    resp = ec2_client.create_security_group(
        GroupName=f"FEL-SG-{int(time.time())}",
        Description="Final Evolution Lab - GPU Build + Pixel Streaming",
        VpcId=vpc_id,
    )
    sg_id = resp["GroupId"]

    rules = []
    for p in REQUIRED_PORTS:
        cidr = ssh_cidr if p["port"] == 22 else "0.0.0.0/0"
        rules.append({
            "IpProtocol": p["proto"],
            "FromPort": p["port"],
            "ToPort": p["port"],
            "IpRanges": [{"CidrIp": cidr, "Description": p["desc"]}],
        })
    for r in UDP_RANGES:
        rules.append({
            "IpProtocol": "udp",
            "FromPort": r["from"],
            "ToPort": r["to"],
            "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": r["desc"]}],
        })

    ec2_client.authorize_security_group_ingress(GroupId=sg_id, IpPermissions=rules)
    ports_str = ", ".join(f"{p['port']}/{p['proto']}" for p in REQUIRED_PORTS)
    log(f"SG: {sg_id} — Ports: {ports_str}", "OK")
    return sg_id


def launch_instance(ec2, ec2_client, ami_id, key_name, subnet_id, sg_id, userdata):
    """Launch g5.2xlarge instance."""
    log(f"Launching {INSTANCE_TYPE} instance...", "STEP")
    instances = ec2.create_instances(
        ImageId=ami_id,
        InstanceType=INSTANCE_TYPE,
        KeyName=key_name,
        MinCount=1,
        MaxCount=1,
        SubnetId=subnet_id,
        SecurityGroupIds=[sg_id],
        BlockDeviceMappings=[{
            "DeviceName": "/dev/sda1",
            "Ebs": {
                "VolumeSize": VOLUME_SIZE_GB,
                "VolumeType": VOLUME_TYPE,
                "Iops": VOLUME_IOPS,
                "Throughput": VOLUME_THROUGHPUT,
                "DeleteOnTermination": True,
            },
        }],
        UserData=userdata,
        TagSpecifications=[{
            "ResourceType": "instance",
            "Tags": [
                {"Key": "Name", "Value": INSTANCE_NAME},
                {"Key": "Project", "Value": PROJECT_TAG},
                {"Key": "Created", "Value": datetime.now().isoformat()},
            ],
        }],
    )
    instance = instances[0]
    log(f"Instance ID: {instance.id}", "OK")

    log("Waiting for instance to enter 'running' state...", "INFO")
    instance.wait_until_running()
    instance.reload()
    log(f"Instance running! Private IP: {instance.private_ip_address}", "OK")

    # Elastic IP
    log("Allocating Elastic IP...", "STEP")
    eip = ec2_client.allocate_address(Domain="vpc")
    ec2_client.associate_address(
        InstanceId=instance.id,
        AllocationId=eip["AllocationId"],
    )
    public_ip = eip["PublicIp"]
    log(f"Elastic IP: {public_ip}", "OK")

    return instance, public_ip, eip["AllocationId"]


def handle_error(error, phase):
    """Provide user-friendly error messages and solutions."""
    code = error.response["Error"]["Code"]
    msg = error.response["Error"]["Message"]

    print(f"\n{'='*60}")
    print(f"  ❌ PROVISIONING FAILED — Phase: {phase}")
    print(f"{'='*60}")
    print(f"  Error Code: {code}")
    print(f"  Message: {msg}")
    print()

    if code == "UnauthorizedOperation":
        print("  🔑 SOLUTION: Insufficient IAM Permissions")
        print("  ─────────────────────────────────────────")
        print("  The AWS credentials being used don't have permission for EC2 operations.")
        print()
        print("  To fix this, your IAM user/role needs these permissions:")
        print("    • ec2:RunInstances, ec2:DescribeInstances, ec2:DescribeImages")
        print("    • ec2:CreateVpc, ec2:CreateSubnet, ec2:CreateSecurityGroup")
        print("    • ec2:AllocateAddress, ec2:CreateKeyPair, ec2:CreateTags")
        print("    • iam:CreateRole, iam:PassRole, iam:CreateInstanceProfile")
        print()
        print("  Quick fix options:")
        print("    1. Use AWS Console manually: https://us-east-2.console.aws.amazon.com/ec2/")
        print("    2. Use an IAM user with AdministratorAccess or PowerUserAccess")
        print("    3. Create a custom policy (see REQUIRED_PERMISSIONS in this script)")
        print()
        print(REQUIRED_PERMISSIONS)

    elif code in ("InstanceLimitExceeded", "VcpuLimitExceeded") or "quota" in msg.lower():
        print("  📊 SOLUTION: Service Quota Exceeded")
        print("  ──────────────────────────────────")
        print(f"  Your account doesn't have enough G-instance vCPU quota in {REGION}.")
        print(f"  g5.2xlarge requires 8 vCPUs.")
        print()
        print("  Request a quota increase:")
        print(f"    https://us-east-2.console.aws.amazon.com/servicequotas/home/services/ec2/quotas/L-DB2F2C47")
        print()
        print("  Steps:")
        print("    1. Click 'Request quota increase'")
        print("    2. Enter desired value: 8 (or more)")
        print("    3. Submit — usually approved within 1-24 hours")

    elif code == "InsufficientInstanceCapacity":
        print("  🖥️ SOLUTION: No Capacity Available")
        print("  ──────────────────────────────────")
        print(f"  AWS doesn't have g5.2xlarge capacity in the selected AZ.")
        print()
        print("  Try these alternatives:")
        print("    1. Different AZ: Re-run with different availability zone")
        print("    2. Spot instance: Add --spot flag (60-70% cheaper, may be interrupted)")
        print("    3. Different instance: g5.xlarge (1 GPU, 4 vCPUs, cheaper)")
        print("    4. Different region: us-east-1, us-west-2 also have g5 instances")
        print("    5. Wait and retry: Capacity often frees up within minutes")

    elif code == "InvalidKeyPair.NotFound":
        print("  🔐 SOLUTION: Key Pair Not Found")
        print("  ─────────────────────────────────")
        print(f"  The specified key pair doesn't exist in {REGION}.")
        print()
        print("  Fix: Re-run with --create-key to create a new key pair automatically")

    else:
        print(f"  🔧 UNEXPECTED ERROR")
        print(f"  ──────────────────")
        print(f"  Please check the AWS documentation or contact support.")
        print(f"  Full error: {msg}")

    # Save error report
    error_report = {
        "status": "failed",
        "phase": phase,
        "error_code": code,
        "error_message": msg,
        "region": REGION,
        "instance_type": INSTANCE_TYPE,
        "timestamp": datetime.now().isoformat(),
        "solutions": get_solution_links(code),
    }
    report_path = Path(__file__).parent / "provision_error.json"
    report_path.write_text(json.dumps(error_report, indent=2))
    print(f"\n  Error report saved: {report_path}")


def get_solution_links(error_code):
    """Return relevant solution links for the error."""
    links = {
        "UnauthorizedOperation": {
            "console_launch": "https://us-east-2.console.aws.amazon.com/ec2/home?region=us-east-2#LaunchInstances:",
            "iam_policies": "https://docs.aws.amazon.com/IAM/latest/UserGuide/access_policies.html",
            "manual_guide": "See deploy/aws/MANUAL_PROVISIONING.md",
        },
        "InstanceLimitExceeded": {
            "quota_increase": "https://us-east-2.console.aws.amazon.com/servicequotas/home/services/ec2/quotas/L-DB2F2C47",
        },
        "VcpuLimitExceeded": {
            "quota_increase": "https://us-east-2.console.aws.amazon.com/servicequotas/home/services/ec2/quotas/L-DB2F2C47",
        },
        "InsufficientInstanceCapacity": {
            "spot_instances": "https://us-east-2.console.aws.amazon.com/ec2/home?region=us-east-2#SpotInstances:",
            "instance_types": "https://aws.amazon.com/ec2/instance-types/g5/",
        },
    }
    return links.get(error_code, {"aws_ec2_docs": "https://docs.aws.amazon.com/ec2/"})


def main():
    parser = argparse.ArgumentParser(description="FEL AWS G5 Provisioning (us-east-2)")
    parser.add_argument("--key-pair", help="Existing EC2 key pair name")
    parser.add_argument("--create-key", action="store_true", help="Create new key pair")
    parser.add_argument("--ssh-cidr", default="0.0.0.0/0", help="SSH CIDR (default: 0.0.0.0/0)")
    parser.add_argument("--github-token", default="", help="GitHub PAT for repo access")
    parser.add_argument("--notification-email", default="", help="Email for notifications")
    parser.add_argument("--dry-run", action="store_true", help="Pre-flight checks only")
    args = parser.parse_args()

    print(f"\n{'='*60}")
    print(f"  🎮 FINAL EVOLUTION LAB — GPU Instance Provisioning")
    print(f"  Region: {REGION}  |  Instance: {INSTANCE_TYPE}")
    print(f"  Volume: {VOLUME_SIZE_GB}GB {VOLUME_TYPE}  |  Ports: {len(REQUIRED_PORTS)}")
    print(f"{'='*60}\n")

    # ── Credential Check ──
    log("Checking AWS credentials...", "STEP")
    try:
        session = boto3.Session(region_name=REGION)
        sts = session.client("sts")
        identity = sts.get_caller_identity()
        log(f"Account: {identity['Account']}", "OK")
        log(f"ARN: {identity['Arn']}", "OK")
    except (NoCredentialsError, ClientError) as e:
        print(f"\n  ❌ AWS credentials not configured or invalid.")
        print(f"  Set: AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY")
        print(f"  Or configure: aws configure --region {REGION}")
        sys.exit(1)

    ec2_client = session.client("ec2")
    ec2 = session.resource("ec2")

    # ── AMI Lookup ──
    log("Finding Ubuntu 22.04 AMI...", "STEP")
    try:
        ami_id = find_ami(ec2_client)
    except ClientError as e:
        handle_error(e, "AMI Lookup")
        sys.exit(1)

    # ── Quota Check ──
    log("Checking G-instance vCPU quota...", "STEP")
    check_quota(session)

    if args.dry_run:
        print(f"\n{'='*60}")
        print("  🔍 DRY RUN COMPLETE — Would provision:")
        print(f"  AMI: {ami_id}")
        print(f"  Instance: {INSTANCE_TYPE} in {REGION}")
        print(f"  Volume: {VOLUME_SIZE_GB}GB {VOLUME_TYPE}")
        print(f"  Key Pair: {args.key_pair or '(auto-create)'}")
        print(f"{'='*60}")
        return

    # ── Key Pair ──
    log("Setting up key pair...", "STEP")
    try:
        key_name, pem_path = create_or_get_key_pair(
            ec2_client, key_name=args.key_pair, create=args.create_key
        )
    except ClientError as e:
        handle_error(e, "Key Pair")
        sys.exit(1)

    # ── VPC & Networking ──
    try:
        vpc, subnet = create_vpc_stack(ec2, ec2_client)
    except ClientError as e:
        handle_error(e, "VPC Creation")
        sys.exit(1)

    # ── Security Group ──
    try:
        sg_id = create_security_group(ec2_client, vpc.id, args.ssh_cidr)
    except ClientError as e:
        handle_error(e, "Security Group")
        sys.exit(1)

    # ── Credentials for UserData ──
    env_file = Path(__file__).parent.parent.parent / ".env"
    env_vars = {}
    if env_file.exists():
        for line in env_file.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env_vars[k.strip()] = v.strip().strip('"').strip("'")

    credentials = {
        "GITHUB_TOKEN": args.github_token or env_vars.get("GITHUB_TOKEN", ""),
        "GAIA_API_KEY": env_vars.get("GAIA_API_KEY", ""),
        "LUMA_API_KEY": env_vars.get("LUMA_API_KEY", ""),
        "RUNWAY_API_KEY": env_vars.get("RUNWAY_API_KEY", ""),
        "STABILITY_API_KEY": env_vars.get("STABILITY_API_KEY", ""),
        "MESHY_API_KEY": env_vars.get("MESHY_API_KEY", ""),
        "DEEPMOTION_CLIENT_ID": env_vars.get("DEEPMOTION_CLIENT_ID", ""),
        "DEEPMOTION_CLIENT_SECRET": env_vars.get("DEEPMOTION_CLIENT_SECRET", ""),
        "NOTIFICATION_EMAIL": args.notification_email or env_vars.get("NOTIFICATION_EMAIL", ""),
        "SLACK_WEBHOOK": env_vars.get("SLACK_WEBHOOK", ""),
    }
    userdata = get_bootstrap_userdata(credentials)

    # ── Launch Instance ──
    try:
        instance, public_ip, eip_alloc = launch_instance(
            ec2, ec2_client, ami_id, key_name, subnet.id, sg_id, userdata
        )
    except ClientError as e:
        handle_error(e, "Instance Launch")
        sys.exit(1)

    # ── Success ──
    result = {
        "status": "success",
        "instance_id": instance.id,
        "public_ip": public_ip,
        "vpc_id": vpc.id,
        "subnet_id": subnet.id,
        "security_group_id": sg_id,
        "eip_allocation_id": eip_alloc,
        "key_pair": key_name,
        "pem_file": pem_path,
        "region": REGION,
        "instance_type": INSTANCE_TYPE,
        "volume_size_gb": VOLUME_SIZE_GB,
        "ami_id": ami_id,
        "timestamp": datetime.now().isoformat(),
        "ssh_command": f"ssh -i {pem_path} ubuntu@{public_ip}",
        "web_app": f"http://{public_ip}:3000",
        "signalling": f"ws://{public_ip}:8888",
        "bootstrap_log": f"ssh -i {pem_path} ubuntu@{public_ip} 'tail -f /var/log/fel-bootstrap.log'",
        "next_steps": [
            f"1. Wait 10-15 min for bootstrap to complete (NVIDIA drivers, CUDA, etc.)",
            f"2. SSH in: ssh -i {pem_path} ubuntu@{public_ip}",
            f"3. Check bootstrap: tail -f /var/log/fel-bootstrap.log",
            f"4. Verify GPU: nvidia-smi",
            f"5. Transfer project: rsync -avz /home/ubuntu/rork-final-evolution-lab/ ubuntu@{public_ip}:/home/ubuntu/rork-final-evolution-lab/",
            f"6. Run pipeline: cd rork-final-evolution-lab && bash scripts/ue5_setup/fel_complete_pipeline.sh",
        ],
    }

    output_file = Path(__file__).parent / "provision_output.json"
    output_file.write_text(json.dumps(result, indent=2))

    print(f"\n{'='*60}")
    print(f"  ✅ PROVISIONING COMPLETE!")
    print(f"{'='*60}")
    print(f"  Instance ID:  {instance.id}")
    print(f"  Public IP:    {public_ip}")
    print(f"  Region:       {REGION}")
    print(f"  Type:         {INSTANCE_TYPE}")
    print(f"  Volume:       {VOLUME_SIZE_GB}GB {VOLUME_TYPE}")
    print(f"  Key Pair:     {key_name}")
    print(f"")
    print(f"  SSH:          ssh -i {pem_path} ubuntu@{public_ip}")
    print(f"  Web App:      http://{public_ip}:3000")
    print(f"  Bootstrap:    ssh -i {pem_path} ubuntu@{public_ip} 'tail -f /var/log/fel-bootstrap.log'")
    print(f"")
    print(f"  Output saved: {output_file}")
    print(f"{'='*60}\n")

    return result


if __name__ == "__main__":
    main()
