# OPTIONAL Windows machine on AWS (enable_windows = true): Windows Server 2025 — AWS offers no Windows 11 client images.
# Runs the Windows CI agents; configured by ansible/windows.yml from the Ubuntu VM (-e win_ip=10.60.1.21).
variable "enable_windows" {
  type    = bool
  default = false
}

variable "windows_instance_type" {
  type    = string
  default = "m6i.xlarge"
}

variable "windows_admin_password" {
  type      = string
  sensitive = true
  default   = ""
}

data "aws_ssm_parameter" "windows" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2025-English-Full-Base"
}

resource "aws_instance" "win" {
  count                  = var.enable_windows ? 1 : 0
  ami                    = data.aws_ssm_parameter.windows.value
  instance_type          = var.windows_instance_type
  subnet_id              = aws_subnet.lab.id
  private_ip             = "10.60.1.21"
  vpc_security_group_ids = [aws_security_group.lab.id]
  key_name               = aws_key_pair.lab.key_name
  # EC2 Windows runs <powershell> user data at first boot; it also creates the 'vagrant' admin used by windows.ini
  user_data = <<-EOT
    <powershell>
    net user vagrant "${var.windows_admin_password}" /add /y
    net localgroup Administrators vagrant /add
    ${module.bootstrap.win_first_boot}
    </powershell>
  EOT
  root_block_device {
    volume_size = 128
    volume_type = "gp3"
    encrypted   = true
  }
  metadata_options {
    http_tokens = "required"
  }
  tags = { Name = "${var.prefix}-win" }
}

output "windows_private_ip" {
  value = var.enable_windows ? "10.60.1.21" : "disabled"
}
