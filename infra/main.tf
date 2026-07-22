# Production direct-upload Pages project: GitHub Actions builds the Gleam site
# and uploads ./dist via `wrangler pages deploy`. No `source` block, so Cloudflare
# never tries to build the repo itself (its build image has no Erlang/Gleam
# toolchain). `source` and `build_config` are optional in the provider and
# omitted on purpose.
#
# This manages the PROJECT only. The custom domain (yungen.dev) and its DNS are
# left out of Terraform on purpose: the cutover is a one-time, watch-it-happen
# step done by hand (dashboard/wrangler), and it never perturbs `terraform apply`
# because the project resource does not track custom domains as a managed input.
resource "cloudflare_pages_project" "site" {
  account_id        = var.cloudflare_account_id
  name              = var.project_name
  production_branch = var.production_branch
}

output "pages_url" {
  description = "The *.pages.dev URL to validate the build on before the domain flip."
  value       = "https://${var.project_name}.pages.dev"
}
