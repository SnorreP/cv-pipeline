variable "subscription_id" {
  description = "Your Azure subscription ID. Find it with: az account show --query id -o tsv"
  type        = string
}

variable "github_repo_url" {
  description = "HTTPS URL of this repo on GitHub, e.g. https://github.com/YOUR-USERNAME/cv-pipeline"
  type        = string
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "node_type_id" {
  description = <<-EOT
    VM size for the single-node cluster. Standard_DS3_v2 has 4 vCPUs, which
    is exactly the free-trial quota. If Azure rejects it with a quota or
    availability error, try Standard_F4s or a different region.
  EOT
  type        = string
  default     = "Standard_DS3_v2"
}
