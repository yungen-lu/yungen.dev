variable "cloudflare_account_id" {
  description = "Cloudflare account ID that owns the Pages project."
  type        = string
}

variable "project_name" {
  description = "Pages project name; also the <name>.pages.dev subdomain."
  type        = string
  default     = "yungen-dev"
}

variable "production_branch" {
  description = "Branch Cloudflare treats as production for this project."
  type        = string
  default     = "main"
}
