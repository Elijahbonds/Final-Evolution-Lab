# =============================================================================
# EC2 GPU Instances with Auto Scaling for Pixel Streaming
# =============================================================================

# --- Launch Template for GPU Instances ---

resource "aws_launch_template" "gpu" {
  name_prefix   = "${local.name_prefix}-gpu-"
  image_id      = local.gpu_ami_id
  instance_type = var.gpu_instance_type
  key_name      = var.key_pair_name

  iam_instance_profile {
    arn = aws_iam_instance_profile.gpu_instance.arn
  }

  vpc_security_group_ids = [aws_security_group.gpu_instance.id]

  block_device_mappings {
    device_name = "/dev/sda1"

    ebs {
      volume_size           = var.root_volume_size
      volume_type           = var.root_volume_type
      encrypted             = true
      delete_on_termination = true
    }
  }

  # Enable detailed monitoring
  monitoring {
    enabled = true
  }

  # Metadata service v2 (security best practice)
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # User data script to bootstrap the instance
  user_data = base64encode(templatefile("${path.module}/templates/user_data.sh.tpl", {
    s3_builds_bucket  = aws_s3_bucket.builds.id
    aws_region        = var.aws_region
    environment       = var.environment
    project_name      = var.project_name
    turn_server_ip    = var.turn_server_enabled ? aws_instance.turn[0].private_ip : ""
    turn_secret       = local.turn_secret
    signaling_port    = 8888
    websocket_port    = 8889
    log_group         = aws_cloudwatch_log_group.pixel_streaming.name
  }))

  tag_specifications {
    resource_type = "instance"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-gpu-instance"
      Role = "pixel-streaming"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(local.common_tags, {
      Name = "${local.name_prefix}-gpu-volume"
    })
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- Auto Scaling Group ---

resource "aws_autoscaling_group" "gpu" {
  name                = "${local.name_prefix}-gpu-asg"
  vpc_zone_identifier = aws_subnet.public[*].id
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_desired_capacity

  # Health checks via ALB
  health_check_type         = "ELB"
  health_check_grace_period = 600  # 10 min grace for UE5 startup

  launch_template {
    id      = aws_launch_template.gpu.id
    version = "$Latest"
  }

  target_group_arns = [
    aws_lb_target_group.signaling.arn,
    aws_lb_target_group.websocket.arn
  ]

  # Instance refresh for rolling deployments
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 600
    }
  }

  # Warm pool for faster scaling
  warm_pool {
    pool_state                  = "Stopped"
    min_size                    = 1
    max_group_prepared_capacity = var.asg_max_size
  }

  tag {
    key                 = "Name"
    value               = "${local.name_prefix}-gpu-instance"
    propagate_at_launch = true
  }

  tag {
    key                 = "AutoScaling"
    value               = "true"
    propagate_at_launch = true
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

# --- Auto Scaling Policies ---

# Scale up on high CPU
resource "aws_autoscaling_policy" "scale_up_cpu" {
  name                   = "${local.name_prefix}-scale-up-cpu"
  autoscaling_group_name = aws_autoscaling_group.gpu.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value     = var.scale_up_cpu_threshold
    disable_scale_in = false
  }
}

# Scale based on ALB request count
resource "aws_autoscaling_policy" "scale_on_requests" {
  name                   = "${local.name_prefix}-scale-requests"
  autoscaling_group_name = aws_autoscaling_group.gpu.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ALBRequestCountPerTarget"
      resource_label         = "${aws_lb.main.arn_suffix}/${aws_lb_target_group.signaling.arn_suffix}"
    }
    target_value = 2  # Target 2 concurrent streams per instance
  }
}

# --- Scheduled Scaling (optional, for known traffic patterns) ---

resource "aws_autoscaling_schedule" "scale_down_night" {
  scheduled_action_name  = "${local.name_prefix}-night-scale-down"
  autoscaling_group_name = aws_autoscaling_group.gpu.name
  min_size               = var.asg_min_size
  max_size               = var.asg_max_size
  desired_capacity       = var.asg_min_size
  recurrence             = "0 6 * * *"  # 6 AM UTC (10 PM PST) scale down
}

resource "aws_autoscaling_schedule" "scale_up_day" {
  scheduled_action_name  = "${local.name_prefix}-day-scale-up"
  autoscaling_group_name = aws_autoscaling_group.gpu.name
  min_size               = var.asg_min_size
  max_size               = var.asg_max_size
  desired_capacity       = var.asg_desired_capacity
  recurrence             = "0 14 * * *"  # 2 PM UTC (6 AM PST) scale up
}

# --- TURN Server Instance ---

resource "aws_instance" "turn" {
  count                  = var.turn_server_enabled ? 1 : 0
  ami                    = local.gpu_ami_id
  instance_type          = var.turn_instance_type
  key_name               = var.key_pair_name
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.turn[0].id]

  iam_instance_profile = aws_iam_instance_profile.gpu_instance.name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/templates/turn_user_data.sh.tpl", {
    turn_secret = local.turn_secret
    realm       = var.domain_name
    aws_region  = var.aws_region
  }))

  tags = {
    Name = "${local.name_prefix}-turn-server"
    Role = "turn-server"
  }
}

# Elastic IP for TURN server (needs stable public IP)
resource "aws_eip" "turn" {
  count    = var.turn_server_enabled ? 1 : 0
  instance = aws_instance.turn[0].id
  domain   = "vpc"

  tags = {
    Name = "${local.name_prefix}-turn-eip"
  }
}
