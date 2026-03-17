terraform {
  required_version = ">= 1.14.0, < 2.0.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "6.11.1"
    }
  }
}

provider "github" {
  owner = var.github_app_owner
  token = var.github_token
}

