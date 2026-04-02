###############################################################################
# Final Evolution Lab — Terraform Configuration for AWS G5.2xlarge
###############################################################################

terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ─── Variables ───────────────────────────────────────────────────────────────

variable "aws_region" {
  default     = "us-east-1"
  description = "AWS region"
}

variable "instance_type" {
  default     = "g5.2xlarge"
  description = "EC2 instance type (must be GPU-enabled)"
}

variable "volume_size" {
  default     = 500
  description = "EBS volume size in GB"
}

variable "key_pair_name" {
  description = "Name of existing EC2 key pair"
  type        = string
}

variable "allowed_ssh_cidr" {
  default     = "0.0.0.0/0"
  description = "CIDR for SSH access"
}

variable "github_token" {
  default     = ""
  sensitive   = true
  description = "GitHub PAT linked to Epic Games"
}

variable "gaia_api_key" {
  default   = ""
  sensitive = true
}

variable "luma_api_key" {
  default   = ""
  sensitive = true
}

variable "runway_api_key" {
  default   = ""
  sensitive = true
}

variable "stability_api_key" {
  default   = ""
  sensitive = true
}

variable "meshy_api_key" {
  default   = ""
  sensitive = true
}

variable "notification_email" {
  default = ""
}

variable "slack_webhook" {
  default   = ""
  sensitive = true
}

# ─── Data Sources ────────────────────────────────────────────────────────────

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# ─── VPC ─────────────────────────────────────────────────────────────────────

resource "aws_vpc" "fel" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = { Name = "FEL-VPC" }
}

resource "aws_subnet" "fel" {
  vpc_id                  = aws_vpc.fel.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags = { Name = "FEL-Subnet" }
}

resource "aws_internet_gateway" "fel" {
  vpc_id = aws_vpc.fel.id
  tags   = { Name = "FEL-IGW" }
}

resource "aws_route_table" "fel" {
  vpc_id = aws_vpc.fel.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.fel.id
  }
}

resource "aws_route_table_association" "fel" {
  subnet_id      = aws_subnet.fel.id
  route_table_id = aws_route_table.fel.id
}

# ─── Security Group ─────────────────────────────────────────────────────────

resource "aws_security_group" "fel" {
  name_prefix = "fel-"
  vpc_id      = aws_vpc.fel.id
  description = "FEL Pixel Streaming + SSH"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.allowed_ssh_cidr]
    description = "SSH"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS"
  }

  ingress {
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Web Frontend"
  }

  ingress {
    from_port   = 8888
    to_port     = 8889
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Pixel Streaming"
  }

  ingress {
    from_port   = 3478
    to_port     = 3478
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURN TCP"
  }

  ingress {
    from_port   = 3478
    to_port     = 3478
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURN UDP"
  }

  ingress {
    from_port   = 49152
    to_port     = 49200
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURN Media Relay"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "FEL-SecurityGroup" }
}

# ─── IAM ─────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "fel" {
  name = "FEL-InstanceRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "s3" {
  role       = aws_iam_role.fel.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "cw" {
  role       = aws_iam_role.fel.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "fel" {
  name = "FEL-InstanceProfile"
  role = aws_iam_role.fel.name
}

# ─── Elastic IP ──────────────────────────────────────────────────────────────

resource "aws_eip" "fel" {
  domain = "vpc"
  tags   = { Name = "FEL-ElasticIP" }
}

resource "aws_eip_association" "fel" {
  instance_id   = aws_instance.fel.id
  allocation_id = aws_eip.fel.id
}

# ─── EC2 Instance ────────────────────────────────────────────────────────────

resource "aws_instance" "fel" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.fel.id
  vpc_security_group_ids = [aws_security_group.fel.id]
  iam_instance_profile   = aws_iam_instance_profile.fel.name

  root_block_device {
    volume_size = var.volume_size
    volume_type = "gp3"
    iops        = 6000
    throughput  = 400
  }

  user_data = templatefile("${path.module}/userdata.sh.tpl", {
    github_token       = var.github_token
    gaia_api_key       = var.gaia_api_key
    luma_api_key       = var.luma_api_key
    runway_api_key     = var.runway_api_key
    stability_api_key  = var.stability_api_key
    meshy_api_key      = var.meshy_api_key
    notification_email = var.notification_email
    slack_webhook      = var.slack_webhook
  })

  tags = {
    Name    = "FinalEvolutionLab-Build"
    Project = "FEL"
  }
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "instance_id" {
  value = aws_instance.fel.id
}

output "public_ip" {
  value = aws_eip.fel.public_ip
}

output "ssh_command" {
  value = "ssh -i ${var.key_pair_name}.pem ubuntu@${aws_eip.fel.public_ip}"
}

output "web_app_url" {
  value = "http://${aws_eip.fel.public_ip}:3000"
}

output "signalling_url" {
  value = "ws://${aws_eip.fel.public_ip}:8888"
}
