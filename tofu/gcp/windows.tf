# OPTIONAL Windows machine on Google Cloud (enable_windows = true): Windows Server 2025 — GCP offers no Windows 11 client images.
variable "enable_windows" {
  type    = bool
  default = false
}

variable "windows_machine_type" {
  type    = string
  default = "n2-standard-4"
}

variable "windows_admin_password" {
  type      = string
  sensitive = true
  default   = ""
}

resource "google_compute_instance" "win" {
  count        = var.enable_windows ? 1 : 0
  name         = "${var.prefix}-win"
  machine_type = var.windows_machine_type
  zone         = var.zone
  tags         = ["secmlops-lab"]
  boot_disk {
    initialize_params {
      image = "windows-cloud/windows-2025"
      size  = 128
      type  = "pd-ssd"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.lab.id
    network_ip = "10.60.1.21"
  }
  # GCE Windows images run this key's script at every boot; the account creation is idempotent (/add fails harmlessly)
  metadata = {
    windows-startup-script-ps1 = <<-EOT
      net user vagrant "${var.windows_admin_password}" /add /y 2>$null
      net localgroup Administrators vagrant /add 2>$null
      ${module.bootstrap.win_first_boot}
    EOT
  }
  shielded_instance_config {
    enable_secure_boot = true
    enable_vtpm        = true
  }
}

output "windows_private_ip" {
  value = var.enable_windows ? "10.60.1.21" : "disabled"
}
