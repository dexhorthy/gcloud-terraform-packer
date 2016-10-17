# simple demo of using a packer-built image to bootstrap a gcloud autoscaler
provider "google" {
  region      = "${var.region}"
  project     = "${var.project_name}"
  credentials = "${file("${var.credentials_file_path}")}"
}

resource "google_compute_instance_template" "demo" {
  name           = "demo"
  machine_type   = "f1-micro"
  can_ip_forward = false

  tags = ["demo", "demo"]

  disk {
    source_image = "${var.base_image}"
  }

  network_interface {
    network = "default"

    access_config {
      # Ephemeral external IP
    }
  }

  metadata {
    ssh-keys = "root:${file("${var.public_key_path}")}"
  }
}

resource "google_compute_target_pool" "demo" {
  name          = "tf-demo-target-pool"
  health_checks = ["${google_compute_http_health_check.demo.name}"]
}

resource "google_compute_instance_group_manager" "demo" {
  name = "demo"
  zone = "${var.region_zone}"

  instance_template  = "${google_compute_instance_template.demo.self_link}"
  target_pools       = ["${google_compute_target_pool.demo.self_link}"]
  base_instance_name = "tf-demo-demo"
}

resource "google_compute_http_health_check" "demo" {
  name                = "tf-demo-basic-check"
  request_path        = "/"
  check_interval_sec  = 1
  healthy_threshold   = 1
  unhealthy_threshold = 3
  timeout_sec         = 1
}

resource "google_compute_autoscaler" "demo" {
  name   = "tf-demo-autoscaler"
  zone   = "${var.region_zone}"
  target = "${google_compute_instance_group_manager.demo.self_link}"

  autoscaling_policy = {
    max_replicas    = 10
    min_replicas    = 2
    cooldown_period = 60

    cpu_utilization {
      target = 0.3
    }
  }
}

resource "google_compute_forwarding_rule" "demo" {
  name       = "tf-demo-forwarding-rule"
  target     = "${google_compute_target_pool.demo.self_link}"
  port_range = "80"
}

resource "google_compute_firewall" "demo" {
  name    = "tf-demo-firewall"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["demo"]
}
