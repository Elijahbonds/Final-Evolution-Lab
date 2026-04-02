# =============================================================================
# Terraform Outputs
# =============================================================================

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "alb_dns_name" {
  description = "ALB DNS name for accessing Pixel Streaming"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "ALB hosted zone ID for DNS alias records"
  value       = aws_lb.main.zone_id
}

output "streaming_url" {
  description = "Full streaming URL"
  value       = "https://${var.domain_name}"
}

output "websocket_url" {
  description = "WebSocket URL for signaling"
  value       = "wss://${var.domain_name}/ws"
}

output "s3_builds_bucket" {
  description = "S3 bucket name for UE5 builds"
  value       = aws_s3_bucket.builds.id
}

output "s3_builds_bucket_arn" {
  description = "S3 bucket ARN for UE5 builds"
  value       = aws_s3_bucket.builds.arn
}

output "asg_name" {
  description = "Auto Scaling Group name"
  value       = aws_autoscaling_group.gpu.name
}

output "launch_template_id" {
  description = "Launch template ID for GPU instances"
  value       = aws_launch_template.gpu.id
}

output "gpu_security_group_id" {
  description = "Security group ID for GPU instances"
  value       = aws_security_group.gpu_instance.id
}

output "turn_server_ip" {
  description = "TURN server public IP"
  value       = var.turn_server_enabled ? aws_eip.turn[0].public_ip : "N/A"
}

output "turn_server_secret" {
  description = "TURN server shared secret"
  value       = local.turn_secret
  sensitive   = true
}

output "cloudwatch_dashboard_url" {
  description = "URL for the CloudWatch monitoring dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${local.name_prefix}-pixel-streaming"
}

output "sns_alerts_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}

output "ssh_command" {
  description = "SSH command to connect to instances (use with ASG instance IPs)"
  value       = "ssh -i ~/Uploads/FinalEvolutionLab.pem ubuntu@<INSTANCE_PUBLIC_IP>"
}

output "deployment_role_arn" {
  description = "IAM role ARN for CI/CD deployments"
  value       = aws_iam_role.deployment.arn
}
