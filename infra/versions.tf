terraform {
  required_version = ">= 1.6"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
  }
}

# Auth: the provider reads the API token from the CLOUDFLARE_API_TOKEN env var.
# Never hardcode it here — this repo is public and tfstate is gitignored.
provider "cloudflare" {}
