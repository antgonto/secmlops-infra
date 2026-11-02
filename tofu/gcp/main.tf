# ===========================================================================================
# SecMLOps lab — PRODUCTION on Google Cloud with OpenTofu.   tofu init && tofu apply
# Replica of the laptop lab and of aws/ and azure/: same cloud-init (modules/lab-bootstrap).
# ===========================================================================================
terraform {
  required_version = ">= 1.8"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

variable "project_id" {
  type = string
}
variable "region" {
  type    = string
  default = "us-central1"
}
variable "zone" {
  type    = string
  default = "us-central1-a"
}
variable "prefix" {
  type    = string
  default = "secmlops"
}
variable "machine_type" {
  type    = string
  default = "n2-standard-8" # 8 vCPU / 32 GB
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

# --- network ---
resource "google_compute_network" "lab" {
  name                    = "${var.prefix}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "lab" {
  name          = "${var.prefix}-subnet"
  ip_cidr_range = "10.60.1.0/24"
  network       = google_compute_network.lab.id
  region        = var.region
}

# GCP networks deny ingress by default; this single rule is the allow-list.
resource "google_compute_firewall" "lab" {
  name          = "${var.prefix}-allow-from-cidr"
  network       = google_compute_network.lab.name
  source_ranges = [var.allowed_cidr]
  target_tags   = ["secmlops-lab"]
  allow {
    protocol = "tcp"
    ports    = [for p in module.bootstrap.service_ports : tostring(p)]
  }
}

resource "google_compute_firewall" "portal_public" {
  name          = "${var.prefix}-allow-portal-public"
  network       = google_compute_network.lab.name
  source_ranges = ["0.0.0.0/0"] # the course portal only (Course 3)
  target_tags   = ["secmlops-lab"]
  allow {
    protocol = "tcp"
    ports    = [for p in module.bootstrap.public_ports : tostring(p)]
  }
}

resource "google_compute_address" "lab" {
  name   = "${var.prefix}-ip"
  region = var.region
}

# Service account for the VM: the managed-identity analogue (no keys on disk).
resource "google_service_account" "lab" {
  account_id   = "${var.prefix}-vm"
  display_name = "SecMLOps lab VM"
}

resource "google_compute_instance" "lab" {
  name         = "${var.prefix}-lab"
  machine_type = var.machine_type
  zone         = var.zone
  tags         = ["secmlops-lab"]

  boot_disk {
    initialize_params {
      image = "ubuntu-os-cloud/ubuntu-2404-lts-amd64"
      size  = 256
      type  = "pd-ssd"
    }
  }
  network_interface {
    subnetwork = google_compute_subnetwork.lab.id
    network_ip = "10.60.1.20"
    access_config {
      nat_ip = google_compute_address.lab.address
    }
  }
  metadata = {
    ssh-keys  = "ubuntu:${var.ssh_public_key}"
    user-data = module.bootstrap.cloud_init # Ubuntu images on GCE run cloud-init from this key
  }
  service_account {
    email  = google_service_account.lab.email
    scopes = ["cloud-platform"]
  }
  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
  advanced_machine_features {
    enable_nested_virtualization = true # k3s inside the VM
  }
}

# --- DNS: Cloud DNS zone with the eight lab hostnames ---
resource "google_dns_managed_zone" "lab" {
  name     = "${var.prefix}-zone"
  dns_name = "${var.dns_zone}."
}

resource "google_dns_record_set" "services" {
  for_each     = toset(module.bootstrap.hostnames)
  managed_zone = google_dns_managed_zone.lab.name
  name         = "${each.key}.${var.dns_zone}."
  type         = "A"
  ttl          = 300
  rrdatas      = [google_compute_address.lab.address]
}

output "public_ip" {
  value = google_compute_address.lab.address
}
output "ssh" {
  value = "ssh -i ~/.ssh/secmlops ubuntu@${google_compute_address.lab.address}"
}
output "name_servers" {
  value       = google_dns_managed_zone.lab.name_servers
  description = "Delegate the zone (or sub-zone) to these at GoDaddy"
}
output "provision_log" {
  value = "ssh in and: tail -f /var/log/secmlops-provision.log"
}
