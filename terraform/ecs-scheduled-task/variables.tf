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

    variables = optional(map(any))
    secrets   = optional(map(string))
  })

  # validation {
  #   condition     = (can(tonumber(var.service_config.count)) || (can(var.service_config.count.range)))
  #   error_message = "service_config.count must be either a number, or a map with the correct autoscaling properties defined."
  # }
}
