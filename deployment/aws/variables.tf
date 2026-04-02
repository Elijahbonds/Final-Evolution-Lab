# =============================================================================
# Final Evolution Lab - Pixel Streaming Infrastructure Variables
# =============================================================================
# All configurable parameters for the AWS deployment
# =============================================================================

variable "project_name" {
  description = "Project name used for resource naming and tagging"
  type        = string
  default     = "final-evolution-lab"
}

variable "environment" {
  description = "Deployment environment (dev, staging, production)"
  type        = string
  default     = "production"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be one of: dev, staging, production."
  }
}

variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.11.0/24", "10.0.12.0/24"]
}

variable "availability_zones" {
  description = "Availability zones to use"
  type        = list(string)
  default     = ["us-west-2a", "us-west-2b", "us-west-2c"]
}

# --- GPU Instance Configuration ---

variable "gpu_instance_type" {
  description = "EC2 instance type for Pixel Streaming servers (must have GPU)"
  type        = string
  default     = "g4dn.xlarge"
  validation {
    condition     = can(regex("^g[45]dn\\.", var.gpu_instance_type))
    error_message = "Instance type must be a GPU instance (g4dn.* or g5dn.*)."
  }
}

variable "gpu_ami_id" {
  description = "AMI ID for GPU instances (Ubuntu 22.04 with NVIDIA drivers). Leave empty to auto-detect."
  type        = string
  default     = ""
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair for SSH access (FinalEvolutionLab)"
  type        = string
  default     = "FinalEvolutionLab"
}

variable "root_volume_size" {
  description = "Root EBS volume size in GB for GPU instances"
  type        = number
  default     = 100
}

variable "root_volume_type" {
  description = "Root EBS volume type"
  type        = string
  default     = "gp3"
}

# --- Spot Instance Configuration (Cost Optimization) ---

variable "use_spot_instances" {
  description = "Use EC2 Spot Instances for GPU servers (60-70% cheaper, but can be interrupted)"
  type        = bool
  default     = false
}

variable "spot_max_price" {
  description = "Maximum hourly price for spot instances (empty = on-demand price cap). Example: '0.25' for $0.25/hr"
  type        = string
  default     = ""
}

variable "spot_instance_types" {
  description = "List of instance types for spot fleet (enables capacity-optimized selection)"
  type        = list(string)
  default     = ["g4dn.xlarge", "g4dn.2xlarge"]
}

variable "on_demand_base_capacity" {
  description = "Number of on-demand instances as a baseline (0 = all spot for max savings)"
  type        = number
  default     = 0
}

variable "on_demand_percentage_above_base" {
  description = "Percentage of on-demand instances above base capacity (0 = all spot above base)"
  type        = number
  default     = 0
}

variable "spot_allocation_strategy" {
  description = "How to allocate spot capacity: capacity-optimized (recommended) or lowest-price"
  type        = string
  default     = "capacity-optimized"
  validation {
    condition     = contains(["capacity-optimized", "lowest-price", "capacity-optimized-prioritized"], var.spot_allocation_strategy)
    error_message = "Spot allocation strategy must be: capacity-optimized, lowest-price, or capacity-optimized-prioritized."
  }
}

# --- Scheduling Configuration (Cost Optimization) ---

variable "enable_scheduled_scaling" {
  description = "Enable scheduled scaling to turn off instances during off-hours"
  type        = bool
  default     = true
}

variable "schedule_scale_down_cron" {
  description = "Cron expression (UTC) for scaling down at night. Default: 6 AM UTC = 10 PM PST"
  type        = string
  default     = "0 6 * * *"
}

variable "schedule_scale_up_cron" {
  description = "Cron expression (UTC) for scaling up in the morning. Default: 2 PM UTC = 6 AM PST"
  type        = string
  default     = "0 14 * * *"
}

variable "off_hours_min_capacity" {
  description = "Minimum instances during off-hours (0 = completely shut down)"
  type        = number
  default     = 0
}

# --- Auto Scaling Configuration ---

variable "asg_min_size" {
  description = "Minimum number of GPU instances in the Auto Scaling Group"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Maximum number of GPU instances in the Auto Scaling Group"
  type        = number
  default     = 10
}

variable "asg_desired_capacity" {
  description = "Desired number of GPU instances"
  type        = number
  default     = 2
}

variable "scale_up_cpu_threshold" {
  description = "CPU utilization percentage to trigger scale-up"
  type        = number
  default     = 70
}

variable "scale_down_cpu_threshold" {
  description = "CPU utilization percentage to trigger scale-down"
  type        = number
  default     = 30
}

variable "scale_up_gpu_threshold" {
  description = "GPU utilization percentage to trigger scale-up"
  type        = number
  default     = 75
}

# --- Domain and SSL ---

variable "domain_name" {
  description = "Primary domain name for the application"
  type        = string
  default     = "stream.finalevolutiongroup.com"
}

variable "hosted_zone_id" {
  description = "Route53 hosted zone ID for DNS records"
  type        = string
  default     = ""
}

variable "ssl_certificate_arn" {
  description = "ARN of ACM SSL certificate. Leave empty to create a new one."
  type        = string
  default     = ""
}

# --- S3 Build Storage ---

variable "s3_builds_bucket_name" {
  description = "S3 bucket name for storing UE5 builds"
  type        = string
  default     = "fel-ue5-builds"
}

# --- TURN Server ---

variable "turn_server_enabled" {
  description = "Whether to deploy a dedicated TURN server"
  type        = bool
  default     = true
}

variable "turn_instance_type" {
  description = "Instance type for TURN server"
  type        = string
  default     = "c5.xlarge"
}

variable "turn_secret" {
  description = "Shared secret for TURN server authentication"
  type        = string
  sensitive   = true
  default     = ""
}

# --- Notification ---

variable "notification_email" {
  description = "Email for CloudWatch alarm notifications"
  type        = string
  default     = "deploy@finalevolutiongroup.com"
}

variable "slack_webhook_url" {
  description = "Slack webhook URL for deployment notifications"
  type        = string
  sensitive   = true
  default     = ""
}

# --- Tags ---

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

locals {
  common_tags = merge({
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Application = "pixel-streaming"
  }, var.tags)

  name_prefix = "${var.project_name}-${var.environment}"
}
