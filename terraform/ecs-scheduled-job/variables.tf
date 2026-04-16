variable "name" {
  type = string
}

variable "application" {
  type = string
}

variable "environment" {
  type = string
}

variable "env_config" {
  type = any
}

variable "platform_extensions" {
  type = any
}

variable "custom_iam_policy_json" {
  type        = string
  default     = null
  description = "Optional custom IAM policy JSON to attach to the ECS task role"

  validation {
    condition     = var.custom_iam_policy_json == null ? true : length(var.custom_iam_policy_json) <= 6144
    error_message = "The length of the custom IAM policy exceeds the 6144 character limit for IAM managed policies."
  }
}

variable "service_config" {
  type = object({
    name = string
    type = string

    schedule = string

    sidecars = optional(map(object({
      port      = number
      image     = string
      essential = optional(bool)
      variables = optional(map(string))
      secrets   = optional(map(string))
      healthcheck = optional(object({
        command      = list(string)
        interval     = optional(number)
        retries      = optional(number)
        timeout      = optional(number)
        start_period = optional(number)
      }))
    })))

    image = object({
      location   = string
      port       = optional(number)
      depends_on = optional(map(string))
      healthcheck = optional(object({
        command      = list(string)
        interval     = optional(number)
        retries      = optional(number)
        timeout      = optional(number)
        start_period = optional(number)
      }))
    })

    cpu     = number
    memory  = number
    retries = optional(number)
    timeout = optional(number)

    exec       = optional(bool) #TODO review use in SJ
    entrypoint = optional(list(string))
    command    = optional(list(string))
    platform   = optional(string)

    network = optional(object({
      connect = optional(bool)
      vpc = optional(object({
        placement = optional(string)
      }))
    }))

    storage = optional(object({
      readonly_fs          = optional(bool)
      writable_directories = optional(list(string))
      ephemeral            = optional(number)
    }))

    variables = optional(map(any))
    secrets   = optional(map(string))
  })

  # validation {
  #   condition     = (can(tonumber(var.service_config.count)) || (can(var.service_config.count.range)))
  #   error_message = "service_config.count must be either a number, or a map with the correct autoscaling properties defined."
  # }
}
