# ── SSH Key ────────────────────────────────────────────────────
resource "tls_private_key" "jenkins" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jenkins" {
  key_name   = "jenkins-key"
  public_key = tls_private_key.jenkins.public_key_openssh
}

resource "local_file" "jenkins_pem" {
  content         = tls_private_key.jenkins.private_key_pem
  filename        = "${path.module}/jenkins-key.pem"
  file_permission = "0400"
}

# ── Security Group ─────────────────────────────────────────────
resource "aws_security_group" "jenkins" {
  name   = "jenkins-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ── Jenkins EC2 Instance ───────────────────────────────────────
resource "aws_instance" "jenkins" {
  ami                         = "ami-0f58b397bc5c1f2e8"
  instance_type               = "t3.large"
  subnet_id                   = var.public_subnet_id
  vpc_security_group_ids      = [aws_security_group.jenkins.id]
  associate_public_ip_address = true
  key_name                    = aws_key_pair.jenkins.key_name
  iam_instance_profile        = var.iam_instance_profile

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
  }

  tags = {
    Name = "jenkins-server"
  }
}

# ── Get availability zone of Jenkins EC2 ──────────────────────
data "aws_availability_zones" "available" {
  state = "available"
}

# ── Separate EBS Volume for Jenkins data ──────────────────────
# This volume is NOT deleted when EC2 is terminated
# Jenkins jobs, credentials, build history all survive
resource "aws_ebs_volume" "jenkins_data" {
  availability_zone = aws_instance.jenkins.availability_zone
  size              = 20
  type              = "gp3"

  tags = {
    Name = "jenkins-data-volume"
  }
}

# ── Attach EBS Volume to Jenkins EC2 ──────────────────────────
resource "aws_volume_attachment" "jenkins_data" {
  device_name  = "/dev/xvdf"
  volume_id    = aws_ebs_volume.jenkins_data.id
  instance_id  = aws_instance.jenkins.id
  force_detach = true
}