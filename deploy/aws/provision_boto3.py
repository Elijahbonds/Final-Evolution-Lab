#!/usr/bin/env python3
"""
Final Evolution Lab — AWS Provisioning via boto3
Provisions a G5.2xlarge instance with 500GB EBS for UE5 build + Pixel Streaming.

Usage:
  python3 provision_boto3.py --key-pair my-key --region us-east-1
  python3 provision_boto3.py --key-pair my-key --dry-run
"""

import argparse
import json
import os
import sys
import time
import base64
from pathlib import Path

try:
    import boto3
    from botocore.exceptions import ClientError, WaiterError
except ImportError:
    print("ERROR: boto3 required. Install: pip install boto3")
    sys.exit(1)


# ─── Configuration ───────────────────────────────────────────────────────────

DEFAULT_CONFIG = {
    "instance_type": "g5.2xlarge",
    "volume_size_gb": 500,
    "volume_type": "gp3",
    "volume_iops": 6000,
    "volume_throughput": 400,
    "ubuntu_ami_name": "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*",
    "ubuntu_owner": "099720109477",
    "vpc_cidr": "10.0.0.0/16",
    "subnet_cidr": "10.0.1.0/24",
    "project_tag": "FEL",
    "instance_name": "FinalEvolutionLab-Build",
}

PORTS = [
    {"port": 22,    "proto": "tcp", "desc": "SSH"},
    {"port": 80,    "proto": "tcp", "desc": "HTTP"},
    {"port": 443,   "proto": "tcp", "desc": "HTTPS"},
    {"port": 3000,  "proto": "tcp", "desc": "Web Frontend"},
    {"port": 8888,  "proto": "tcp", "desc": "Pixel Streaming WS"},
    {"port": 8889,  "proto": "tcp", "desc": "Pixel Streaming Streamer"},
    {"port": 3478,  "proto": "tcp", "desc": "TURN TCP"},
    {"port": 3478,  "proto": "udp", "desc": "TURN UDP"},
]

UDP_RANGES = [
    {"from": 49152, "to": 49200, "desc": "TURN Media Relay"},
]


def get_userdata(credentials: dict) -> str:
    """Generate bootstrap userdata script."""
    script_dir = Path(__file__).parent
    bootstrap_ref = ""
    creds_block = "\n".join(f"{k}={v}" for k, v in credentials.items() if v)
    
    return f"""#!/bin/bash
set -e
exec > /var/log/fel-bootstrap.log 2>&1
echo "=== FEL Bootstrap Starting ==="
export DEBIAN_FRONTEND=noninteractive

mkdir -p /home/ubuntu/.fel
cat > /home/ubuntu/.fel/credentials.env << 'CREDS'
{creds_block}
CREDS
chmod 600 /home/ubuntu/.fel/credentials.env
chown -R ubuntu:ubuntu /home/ubuntu/.fel

apt-get update -y
apt-get install -y git curl wget

cd /home/ubuntu
GH_TOKEN="{credentials.get('GITHUB_TOKEN', '')}"
if [ -n "$GH_TOKEN" ]; then
  git clone https://${{GH_TOKEN}}@github.com/finalevolutiongroup/final-evolution-lab.git rork-final-evolution-lab || true
fi

if [ -d /home/ubuntu/rork-final-evolution-lab/deploy/aws ]; then
  chmod +x /home/ubuntu/rork-final-evolution-lab/deploy/aws/bootstrap.sh
  su - ubuntu -c '/home/ubuntu/rork-final-evolution-lab/deploy/aws/bootstrap.sh'
fi
echo "=== FEL Bootstrap Complete ==="
"""


def find_ubuntu_ami(ec2_client, region: str) -> str:
    """Find latest Ubuntu 22.04 AMI."""
    resp = ec2_client.describe_images(
        Owners=[DEFAULT_CONFIG["ubuntu_owner"]],
        Filters=[
            {"Name": "name", "Values": [DEFAULT_CONFIG["ubuntu_ami_name"]]},
            {"Name": "virtualization-type", "Values": ["hvm"]},
            {"Name": "architecture", "Values": ["x86_64"]},
        ],
    )
    images = sorted(resp["Images"], key=lambda x: x["CreationDate"], reverse=True)
    if not images:
        raise RuntimeError(f"No Ubuntu 22.04 AMI found in {region}")
    ami = images[0]["ImageId"]
    print(f"  AMI: {ami} ({images[0]['Name']})")
    return ami


def create_vpc(ec2):
    """Create VPC with subnet, IGW, routes."""
    print("\n── Creating VPC...")
    vpc = ec2.create_vpc(CidrBlock=DEFAULT_CONFIG["vpc_cidr"])
    vpc.wait_until_available()
    vpc.create_tags(Tags=[{"Key": "Name", "Value": "FEL-VPC"}])
    vpc.modify_attribute(EnableDnsSupport={"Value": True})
    vpc.modify_attribute(EnableDnsHostnames={"Value": True})
    print(f"  VPC: {vpc.id}")

    subnet = vpc.create_subnet(
        CidrBlock=DEFAULT_CONFIG["subnet_cidr"],
        AvailabilityZone=f"{ec2.meta.client.meta.region_name}a",
    )
    subnet.meta.client.modify_subnet_attribute(
        SubnetId=subnet.id, MapPublicIpOnLaunch={"Value": True}
    )
    subnet.create_tags(Tags=[{"Key": "Name", "Value": "FEL-Subnet"}])
    print(f"  Subnet: {subnet.id}")

    igw = ec2.create_internet_gateway()
    igw.create_tags(Tags=[{"Key": "Name", "Value": "FEL-IGW"}])
    igw.attach_to_vpc(VpcId=vpc.id)

    rt = vpc.create_route_table()
    rt.create_route(DestinationCidrBlock="0.0.0.0/0", GatewayId=igw.id)
    rt.associate_with_subnet(SubnetId=subnet.id)

    return vpc, subnet


def create_security_group(ec2_client, vpc_id: str, ssh_cidr: str):
    """Create security group with all required ports."""
    print("\n── Creating Security Group...")
    resp = ec2_client.create_security_group(
        GroupName="FEL-SecurityGroup",
        Description="Final Evolution Lab - Pixel Streaming + SSH",
        VpcId=vpc_id,
    )
    sg_id = resp["GroupId"]

    ingress_rules = []
    for p in PORTS:
        cidr = ssh_cidr if p["port"] == 22 else "0.0.0.0/0"
        ingress_rules.append({
            "IpProtocol": p["proto"],
            "FromPort": p["port"],
            "ToPort": p["port"],
            "IpRanges": [{"CidrIp": cidr, "Description": p["desc"]}],
        })
    for r in UDP_RANGES:
        ingress_rules.append({
            "IpProtocol": "udp",
            "FromPort": r["from"],
            "ToPort": r["to"],
            "IpRanges": [{"CidrIp": "0.0.0.0/0", "Description": r["desc"]}],
        })

    ec2_client.authorize_security_group_ingress(
        GroupId=sg_id, IpPermissions=ingress_rules
    )
    print(f"  Security Group: {sg_id}")
    return sg_id


def create_iam_role(iam_client):
    """Create IAM role and instance profile."""
    print("\n── Creating IAM Role...")
    role_name = "FEL-InstanceRole"
    profile_name = "FEL-InstanceProfile"

    trust_policy = json.dumps({
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "ec2.amazonaws.com"},
            "Action": "sts:AssumeRole",
        }],
    })

    try:
        iam_client.create_role(
            RoleName=role_name,
            AssumeRolePolicyDocument=trust_policy,
            Description="FEL build instance role",
        )
        for arn in [
            "arn:aws:iam::aws:policy/AmazonS3FullAccess",
            "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
        ]:
            iam_client.attach_role_policy(RoleName=role_name, PolicyArn=arn)
    except ClientError as e:
        if e.response["Error"]["Code"] != "EntityAlreadyExists":
            raise
        print(f"  Role {role_name} already exists, reusing")

    try:
        iam_client.create_instance_profile(InstanceProfileName=profile_name)
        iam_client.add_role_to_instance_profile(
            InstanceProfileName=profile_name, RoleName=role_name
        )
        time.sleep(10)  # Wait for propagation
    except ClientError as e:
        if e.response["Error"]["Code"] != "EntityAlreadyExists":
            raise
        print(f"  Profile {profile_name} already exists, reusing")

    print(f"  IAM Role: {role_name}")
    return profile_name


def provision(args):
    """Main provisioning flow."""
    region = args.region
    print(f"\n{'='*60}")
    print(f"  FINAL EVOLUTION LAB — AWS Provisioning")
    print(f"  Region: {region}  Instance: {args.instance_type}")
    print(f"  Volume: {args.volume_size}GB gp3")
    print(f"{'='*60}\n")

    session = boto3.Session(region_name=region)
    ec2 = session.resource("ec2")
    ec2_client = session.client("ec2")
    iam_client = session.client("iam")

    # 1. Find AMI
    print("── Finding Ubuntu 22.04 AMI...")
    ami_id = find_ubuntu_ami(ec2_client, region)

    if args.dry_run:
        print("\n[DRY RUN] Would provision:")
        print(f"  AMI: {ami_id}")
        print(f"  Instance: {args.instance_type}")
        print(f"  Volume: {args.volume_size}GB gp3")
        print(f"  Key Pair: {args.key_pair}")
        return

    # 2. Create VPC
    vpc, subnet = create_vpc(ec2)

    # 3. Security Group
    sg_id = create_security_group(ec2_client, vpc.id, args.ssh_cidr)

    # 4. IAM
    profile_name = create_iam_role(iam_client)

    # 5. Credentials
    credentials = {
        "GITHUB_TOKEN": args.github_token or os.environ.get("GITHUB_TOKEN", ""),
        "GAIA_API_KEY": os.environ.get("GAIA_API_KEY", ""),
        "LUMA_API_KEY": os.environ.get("LUMA_API_KEY", ""),
        "RUNWAY_API_KEY": os.environ.get("RUNWAY_API_KEY", ""),
        "STABILITY_API_KEY": os.environ.get("STABILITY_API_KEY", ""),
        "MESHY_API_KEY": os.environ.get("MESHY_API_KEY", ""),
        "NOTIFICATION_EMAIL": args.notification_email or "",
        "SLACK_WEBHOOK": os.environ.get("SLACK_WEBHOOK", ""),
    }
    userdata = get_userdata(credentials)

    # 6. Launch Instance
    print("\n── Launching G5.2xlarge Instance...")
    instances = ec2.create_instances(
        ImageId=ami_id,
        InstanceType=args.instance_type,
        KeyName=args.key_pair,
        MinCount=1,
        MaxCount=1,
        SubnetId=subnet.id,
        SecurityGroupIds=[sg_id],
        IamInstanceProfile={"Name": profile_name},
        BlockDeviceMappings=[{
            "DeviceName": "/dev/sda1",
            "Ebs": {
                "VolumeSize": args.volume_size,
                "VolumeType": "gp3",
                "Iops": DEFAULT_CONFIG["volume_iops"],
                "Throughput": DEFAULT_CONFIG["volume_throughput"],
                "DeleteOnTermination": True,
            },
        }],
        UserData=userdata,
        TagSpecifications=[{
            "ResourceType": "instance",
            "Tags": [
                {"Key": "Name", "Value": DEFAULT_CONFIG["instance_name"]},
                {"Key": "Project", "Value": DEFAULT_CONFIG["project_tag"]},
            ],
        }],
    )
    instance = instances[0]
    print(f"  Instance ID: {instance.id}")
    print("  Waiting for instance to be running...")
    instance.wait_until_running()
    instance.reload()

    # 7. Elastic IP
    print("\n── Allocating Elastic IP...")
    eip = ec2_client.allocate_address(Domain="vpc")
    ec2_client.associate_address(
        InstanceId=instance.id,
        AllocationId=eip["AllocationId"],
    )
    public_ip = eip["PublicIp"]
    print(f"  Elastic IP: {public_ip}")

    # 8. Output
    result = {
        "instance_id": instance.id,
        "public_ip": public_ip,
        "vpc_id": vpc.id,
        "subnet_id": subnet.id,
        "security_group_id": sg_id,
        "eip_allocation_id": eip["AllocationId"],
        "region": region,
        "ssh_command": f"ssh -i {args.key_pair}.pem ubuntu@{public_ip}",
        "web_app": f"http://{public_ip}:3000",
        "signalling": f"ws://{public_ip}:8888",
        "bootstrap_log": f"ssh -i {args.key_pair}.pem ubuntu@{public_ip} 'tail -f /var/log/fel-bootstrap.log'",
    }

    output_file = Path(__file__).parent / "provision_output.json"
    output_file.write_text(json.dumps(result, indent=2))

    print(f"\n{'='*60}")
    print("  ✅ PROVISIONING COMPLETE")
    print(f"{'='*60}")
    print(f"  Instance: {instance.id}")
    print(f"  Public IP: {public_ip}")
    print(f"  SSH: ssh -i {args.key_pair}.pem ubuntu@{public_ip}")
    print(f"  Web App: http://{public_ip}:3000")
    print(f"  Signalling: ws://{public_ip}:8888")
    print(f"  Bootstrap Log: tail -f /var/log/fel-bootstrap.log")
    print(f"\n  Output saved: {output_file}")

    return result


def main():
    parser = argparse.ArgumentParser(description="FEL AWS Provisioning")
    parser.add_argument("--key-pair", required=True, help="EC2 Key Pair name")
    parser.add_argument("--region", default="us-east-1")
    parser.add_argument("--instance-type", default="g5.2xlarge")
    parser.add_argument("--volume-size", type=int, default=500)
    parser.add_argument("--ssh-cidr", default="0.0.0.0/0")
    parser.add_argument("--github-token", default="")
    parser.add_argument("--notification-email", default="")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    provision(args)


if __name__ == "__main__":
    main()
