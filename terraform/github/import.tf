import {
  for_each = {
    for gh_env in var.github_repository_environments : gh_env.environment_name => gh_env
    if lookup(gh_env, "is_existing", false)
  }

  to = github_repository_environment.this[each.key]
  id = "${each.value.repository}:${each.key}"
}