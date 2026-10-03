# Declare the provider source so Terraform resolves grafana/grafana
# instead of inferring hashicorp/grafana. Version is pinned in the root module.
terraform {
  required_providers {
    grafana = {
      source = "grafana/grafana"
    }
  }
}
