# ===========================================================================================
# SecMLOps lab — PRODUCTION on AWS with OpenTofu.   tofu init && tofu apply
# Replica of the laptop lab and of gcp/ and azure/: same cloud-init (modules/lab-bootstrap),
# same Ansible, same smoke test. Only the provider vocabulary differs.
# ===========================================================================================
terraform {
  required_version = ">= 1.8"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.70" }
  }
}

provider "aws" {
  region = var.region
}

variable "region" {
  type    = string
  default = "us-east-1"
}
variable "prefix" {
  type    = string
  default = "secmlops"
}
variable "instance_type" {
  type    = string
  default = "m6i.2xlarge" # 8 vCPU / 32 GB
}
variable "ssh_public_key" {
  type = string
}
variable "allowed_cidr" {
  type = string
}
variable "repo_url" {
  type = string
}
variable "dns_zone" {
  type    = string
  default = "secmlops.com"
}

module "bootstrap" {
  source       = "../modules/lab-bootstrap"
  repo_url     = var.repo_url
  lab_ip       = "10.60.1.20"
  lab_domain   = var.dns_zone
  allowed_cidr = var.allowed_cidr
}

# --- network: one VPC, one public subnet, default deny via the security group ---
resource "aws_vpc" "lab" {
  cidr_block           = "10.60.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "${var.prefix}-vpc" }
}

resource "aws_subnet" "lab" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = "10.60.1.0/24"
  map_public_ip_on_launch = false
  tags                    = { Name = "${var.prefix}-subnet" }
}

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id
}

resource "aws_route_table" "lab" {
  vpc_id = aws_vpc.lab.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }
}

resource "aws_route_table_association" "lab" {
  subnet_id      = aws_subnet.lab.id
  route_table_id = aws_route_table.lab.id
}

resource "aws_security_group" "lab" {
  name   = "${var.prefix}-sg"
  vpc_id = aws_vpc.lab.id
  dynamic "ingress" {
    for_each = toset(module.bootstrap.service_ports)
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = [var.allowed_cidr] # never 0.0.0.0/0
    }
  }
  dynamic "ingress" {
    for_each = toset(module.bootstrap.public_ports)
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"] # the course portal only (Course 3)
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# --- Ubuntu 24.04 LTS AMI, looked up from Canonical's public SSM parameter (no hard-coded AMI id) ---
data "aws_ssm_parameter" "ubuntu" {
  name = "/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
}

resource "aws_key_pair" "lab" {
  key_name   = "${var.prefix}-key"
  public_key = var.ssh_public_key
}

# Instance role: lets the VM use AWS APIs (backups to S3, Secrets Manager) without stored keys — the managed-identity analogue.
resource "aws_iam_role" "lab" {
  name               = "${var.prefix}-vm-role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" }, Action = "sts:AssumeRole" }] })
}

resource "aws_iam_instance_profile" "lab" {
  name = "${var.prefix}-vm-profile"
  role = aws_iam_role.lab.name
}

resource "aws_instance" "lab" {
  ami                         = data.aws_ssm_parameter.ubuntu.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.lab.id
  private_ip                  = "10.60.1.20"
  vpc_security_group_ids      = [aws_security_group.lab.id]
  key_name                    = aws_key_pair.lab.key_name
  iam_instance_profile        = aws_iam_instance_profile.lab.name
  user_data                   = module.bootstrap.cloud_init
  user_data_replace_on_change = true
  root_block_device {
    volume_size = 256
    volume_type = "gp3"
    encrypted   = true
  }
  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }
  tags = { Name = "${var.prefix}-lab" }
}

resource "aws_eip" "lab" {
  instance = aws_instance.lab.id
  domain   = "vpc"
}

# --- DNS: Route 53 zone with the eight lab hostnames ---
resource "aws_route53_zone" "lab" {
  name = var.dns_zone
}

resource "aws_route53_record" "services" {
  for_each = toset(module.bootstrap.hostnames)
  zone_id  = aws_route53_zone.lab.zone_id
  name     = "${each.key}.${var.dns_zone}"
  type     = "A"
  ttl      = 300
  records  = [aws_eip.lab.public_ip]
}

output "public_ip" {
  value = aws_eip.lab.public_ip
}
output "ssh" {
  value = "ssh -i ~/.ssh/secmlops ubuntu@${aws_eip.lab.public_ip}"
}
output "name_servers" {
  value       = aws_route53_zone.lab.name_servers
  description = "Delegate the zone (or sub-zone) to these at GoDaddy"
}
output "provision_log" {
  value = "ssh in and: tail -f /var/log/secmlops-provision.log"
}
output "instance_id" {
  value = aws_instance.lab.id
}
