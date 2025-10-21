# Discover available zones in the region
data "google_compute_zones" "available" {
  region = local.region
}

# Pick one zone (either from input, or the first available)
locals {
  selected_zone = local.zone != "" ? local.zone : data.google_compute_zones.available.names[0]
}
