github_repository_environments = [
  {
    environment_name = "dev"
    repository       = "github-environments-test"
    existing         = true
  },
  {
    environment_name = "test"
    repository       = "github-environments-test"
    existing         = true

    deployment_branch_policy = {
      protected_branches     = false
      custom_branch_policies = true
      branch_pattern         = ["main", "release/*"]
      tag_pattern            = ["v*"]
    }
  },
  {
    environment_name = "prod"
    repository       = "github-environments-test"

    deployment_branch_policy = {
      protected_branches     = false
      custom_branch_policies = true
      branch_pattern         = ["main", "release/*"]
      tag_pattern            = ["v*"]
    }
  }
]
