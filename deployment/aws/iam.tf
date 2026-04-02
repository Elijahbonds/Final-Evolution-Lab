# =============================================================================
# IAM Roles and Policies for Pixel Streaming Infrastructure
# =============================================================================

# --- EC2 Instance Role ---
# Allows GPU instances to pull builds from S3, write CloudWatch logs/metrics

resource "aws_iam_role" "gpu_instance" {
  name = "${local.name_prefix}-gpu-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${local.name_prefix}-gpu-instance-role"
  }
}

resource "aws_iam_instance_profile" "gpu_instance" {
  name = "${local.name_prefix}-gpu-instance-profile"
  role = aws_iam_role.gpu_instance.name
}

# S3 access for UE5 builds
resource "aws_iam_role_policy" "s3_builds_access" {
  name = "${local.name_prefix}-s3-builds-access"
  role = aws_iam_role.gpu_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.builds.arn,
          "${aws_s3_bucket.builds.arn}/*"
        ]
      }
    ]
  })
}

# CloudWatch logs and metrics
resource "aws_iam_role_policy" "cloudwatch_access" {
  name = "${local.name_prefix}-cloudwatch-access"
  role = aws_iam_role.gpu_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/fel/*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "FinalEvolutionLab"
          }
        }
      }
    ]
  })
}

# SSM access for remote management (optional)
resource "aws_iam_role_policy_attachment" "ssm_managed" {
  role       = aws_iam_role.gpu_instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# ECR access for pulling container images
resource "aws_iam_role_policy" "ecr_access" {
  name = "${local.name_prefix}-ecr-access"
  role = aws_iam_role.gpu_instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchGetImage",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = "*"
      }
    ]
  })
}

# --- Deployment Role ---
# For CI/CD pipelines to deploy builds

resource "aws_iam_role" "deployment" {
  name = "${local.name_prefix}-deployment-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "codebuild.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "${local.name_prefix}-deployment-role"
  }
}

resource "aws_iam_role_policy" "deployment_policy" {
  name = "${local.name_prefix}-deployment-policy"
  role = aws_iam_role.deployment.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.builds.arn,
          "${aws_s3_bucket.builds.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "autoscaling:StartInstanceRefresh",
          "autoscaling:DescribeInstanceRefreshes",
          "autoscaling:UpdateAutoScalingGroup"
        ]
        Resource = aws_autoscaling_group.gpu.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ssm:SendCommand",
          "ssm:GetCommandInvocation"
        ]
        Resource = "*"
      }
    ]
  })
}
