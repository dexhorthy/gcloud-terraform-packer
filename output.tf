output "pool_public_ip" {
  value = "${google_compute_forwarding_rule.demo.ip_address}"
}
