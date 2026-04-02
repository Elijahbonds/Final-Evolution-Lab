# =============================================================================
# Security Groups for Pixel Streaming Infrastructure
# =============================================================================

# --- ALB Security Group ---
# Allows inbound HTTP/HTTPS from the internet

resource "aws_security_group" "alb" {
  name_prefix = "${local.name_prefix}-alb-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for Application Load Balancer"

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP from internet"
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${local.name_prefix}-alb-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- GPU Instance Security Group ---
# Allows traffic from ALB and WebRTC UDP ports

resource "aws_security_group" "gpu_instance" {
  name_prefix = "${local.name_prefix}-gpu-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for GPU Pixel Streaming instances"

  # SSH access (restricted)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Restrict to your IP in production
    description = "SSH access"
  }

  # UE5 Pixel Streaming HTTP port from ALB
  ingress {
    from_port       = 8888
    to_port         = 8888
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Signaling server from ALB"
  }

  # UE5 Pixel Streaming WebSocket from ALB
  ingress {
    from_port       = 8889
    to_port         = 8889
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Signaling WebSocket from ALB"
  }

  # WebRTC UDP port range (for direct peer connections)
  ingress {
    from_port   = 49152
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "WebRTC UDP media streams"
  }

  # WebRTC TCP fallback
  ingress {
    from_port   = 49152
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "WebRTC TCP fallback"
  }

  # Internal communication between GPU instances
  ingress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    self      = true
    description = "Internal cluster communication"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${local.name_prefix}-gpu-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# --- TURN Server Security Group ---

resource "aws_security_group" "turn" {
  count       = var.turn_server_enabled ? 1 : 0
  name_prefix = "${local.name_prefix}-turn-"
  vpc_id      = aws_vpc.main.id
  description = "Security group for TURN/STUN server"

  # STUN/TURN TCP
  ingress {
    from_port   = 3478
    to_port     = 3478
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "STUN/TURN TCP"
  }

  # STUN/TURN UDP
  ingress {
    from_port   = 3478
    to_port     = 3478
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "STUN/TURN UDP"
  }

  # TURN TLS
  ingress {
    from_port   = 5349
    to_port     = 5349
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURN TLS"
  }

  # TURN relay port range
  ingress {
    from_port   = 49152
    to_port     = 65535
    protocol    = "udp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "TURN relay ports"
  }

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound"
  }

  tags = {
    Name = "${local.name_prefix}-turn-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}
