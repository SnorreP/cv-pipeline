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
    VM size for the single-node cluster. Standard_D4s_v5 has 4 vCPUs, which
    is exactly the free-trial quota -- and free trials only get quota for
    v5-generation D/E families (older sizes like Standard_DS3_v2 come back
    "not available"). If Azure still rejects it, probe what your
    subscription can start with:
      az vm list-skus --location <region> --resource-type virtualMachines
  EOT
  type        = string
  default     = "Standard_D4s_v5"
}
