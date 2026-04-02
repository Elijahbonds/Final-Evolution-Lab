# =============================================================================
# CloudWatch Monitoring, Alarms, and Dashboard
# =============================================================================

# --- Log Groups ---

resource "aws_cloudwatch_log_group" "pixel_streaming" {
  name              = "/fel/pixel-streaming"
  retention_in_days = 30

  tags = {
    Name = "${local.name_prefix}-pixel-streaming-logs"
  }
}

resource "aws_cloudwatch_log_group" "signaling_server" {
  name              = "/fel/signaling-server"
  retention_in_days = 30

  tags = {
    Name = "${local.name_prefix}-signaling-logs"
  }
}

resource "aws_cloudwatch_log_group" "ue5_server" {
  name              = "/fel/ue5-server"
  retention_in_days = 14

  tags = {
    Name = "${local.name_prefix}-ue5-server-logs"
  }
}

# --- SNS Topic for Alarms ---

resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"

  tags = {
    Name = "${local.name_prefix}-alerts"
  }
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.notification_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# --- CloudWatch Alarms ---

# High CPU utilization across ASG
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${local.name_prefix}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 300
  statistic           = "Average"
  threshold           = 85
  alarm_description   = "GPU instance CPU utilization is above 85% for 15 minutes"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  ok_actions          = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.gpu.name
  }
}

# ALB unhealthy host count
resource "aws_cloudwatch_metric_alarm" "unhealthy_hosts" {
  alarm_name          = "${local.name_prefix}-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Maximum"
  threshold           = 0
  alarm_description   = "One or more GPU instances are unhealthy"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    TargetGroup  = aws_lb_target_group.signaling.arn_suffix
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

# ALB 5XX error rate
resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "${local.name_prefix}-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "ALB 5XX errors exceed threshold"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

# High ALB latency
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  alarm_name          = "${local.name_prefix}-high-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Average"
  threshold           = 5  # 5 seconds
  alarm_description   = "ALB average response time exceeds 5 seconds"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }
}

# ASG capacity alarm
resource "aws_cloudwatch_metric_alarm" "asg_max_capacity" {
  alarm_name          = "${local.name_prefix}-asg-at-max"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = 1
  metric_name         = "GroupInServiceInstances"
  namespace           = "AWS/AutoScaling"
  period              = 300
  statistic           = "Maximum"
  threshold           = var.asg_max_size
  alarm_description   = "ASG has reached maximum capacity - consider increasing max_size"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.gpu.name
  }
}

# --- CloudWatch Dashboard ---

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${local.name_prefix}-pixel-streaming"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# Final Evolution Lab - Pixel Streaming Dashboard\n**Environment:** ${var.environment} | **Region:** ${var.aws_region}"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.gpu.name, { stat = "Average" }],
            ["...", { stat = "Maximum" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "GPU Instance CPU Utilization"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 1
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.gpu.name],
            [".", "GroupDesiredCapacity", ".", "."],
            [".", "GroupTotalInstances", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Auto Scaling Group Capacity"
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum" }],
            [".", "ActiveConnectionCount", ".", ".", { stat = "Sum" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ALB Request & Connection Count"
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 7
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Average" }],
            ["...", { stat = "p99" }]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "ALB Response Time"
          period  = 60
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 13
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_2XX_Count", "LoadBalancer", aws_lb.main.arn_suffix, { stat = "Sum" }],
            [".", "HTTPCode_Target_4XX_Count", ".", ".", { stat = "Sum" }],
            [".", "HTTPCode_Target_5XX_Count", ".", ".", { stat = "Sum" }]
          ]
          view    = "timeSeries"
          stacked = true
          region  = var.aws_region
          title   = "ALB HTTP Response Codes"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 13
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.signaling.arn_suffix, "LoadBalancer", aws_lb.main.arn_suffix],
            [".", "UnHealthyHostCount", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = var.aws_region
          title   = "Target Group Health"
          period  = 60
        }
      },
      {
        type   = "log"
        x      = 0
        y      = 19
        width  = 24
        height = 6
        properties = {
          query   = "SOURCE '/fel/pixel-streaming' | fields @timestamp, @message | sort @timestamp desc | limit 50"
          region  = var.aws_region
          title   = "Recent Pixel Streaming Logs"
          view    = "table"
        }
      }
    ]
  })
}
