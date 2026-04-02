# =============================================================================
# Final Evolution Lab - Main Terraform Configuration
# UE5 Pixel Streaming on AWS with GPU Instances
# =============================================================================
#
# Architecture Overview:
#   Internet -> ALB -> GPU EC2 Instances (UE5 Pixel Streaming)
#                  -> Signaling Server (WebSocket)
#                  -> TURN/STUN Server (WebRTC relay)
#   S3 -> UE5 Build Artifacts
#   CloudWatch -> Monitoring & Alerts
#
# =============================================================================

# --- Data Sources ---

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

# Auto-detect latest Ubuntu 22.04 GPU AMI if not specified
data "aws_ami" "ubuntu_gpu" {
  count       = var.gpu_ami_id == "" ? 1 : 0
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

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

locals {
  gpu_ami_id = var.gpu_ami_id != "" ? var.gpu_ami_id : data.aws_ami.ubuntu_gpu[0].id
}

# --- Random suffix for globally unique names ---

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# --- Generate TURN secret if not provided ---

resource "random_password" "turn_secret" {
  count   = var.turn_secret == "" ? 1 : 0
  length  = 32
  special = false
}

locals {
  turn_secret = var.turn_secret != "" ? var.turn_secret : (
    length(random_password.turn_secret) > 0 ? random_password.turn_secret[0].result : ""
  )
}
