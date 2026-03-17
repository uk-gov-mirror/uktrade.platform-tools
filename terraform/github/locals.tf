locals {
  deployment_policies = {
    for p in flatten([
      for env in var.github_repository_environments : concat(
        [for b in try(env.deployment_branch_policy.branch_pattern, []) :
          {
            key         = "${env.environment_name}:branch:${b}"
            repository  = env.repository
            environment = env.environment_name
            pattern     = b
            is_tag      = false
          }
        ],
        [for t in try(env.deployment_branch_policy.tag_pattern, []) :
          {
            key         = "${env.environment_name}:tag:${t}"
            repository  = env.repository
            environment = env.environment_name
            pattern     = t
            is_tag      = true
          }
        ]
      ) if lookup(try(env.deployment_branch_policy, {}), "custom_branch_policies", false) && !lookup(env, "existing", false)
    ]) : p.key => p
  }
}