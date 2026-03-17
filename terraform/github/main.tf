resource "github_repository_environment" "this" {
  for_each            = { for env in var.github_repository_environments : env.environment_name => env }
  environment         = each.key
  repository          = each.value.repository
  wait_timer          = each.value.wait_timer
  prevent_self_review = each.value.prevent_self_review

  dynamic "reviewers" {
    for_each = each.value.reviewers != {} && each.value.reviewers != null ? [each.value.reviewers] : []

    content {
      teams = reviewers.value.teams
      users = reviewers.value.users
    }
  }

  dynamic "deployment_branch_policy" {
    for_each = each.value.deployment_branch_policy != {} && each.value.deployment_branch_policy != null ? [each.value.deployment_branch_policy] : []

    content {
      protected_branches     = deployment_branch_policy.value.protected_branches
      custom_branch_policies = deployment_branch_policy.value.custom_branch_policies
    }
  }
}

resource "github_repository_environment_deployment_policy" "this" {
  for_each       = local.deployment_policies
  repository     = each.value.repository
  environment    = each.value.environment
  branch_pattern = each.value.is_tag ? null : each.value.pattern
  tag_pattern    = each.value.is_tag ? each.value.pattern : null

  depends_on = [github_repository_environment.this]
}
