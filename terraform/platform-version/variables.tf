variable "platform_version" {
  type = string
}

variable "application" {
  type = string
}

variable "environment" {
  type     = string
  nullable = true
  default  = null
}

variable "service_name" {
  type     = string
  nullable = true
  default  = null
}

variable "pipeline_type" {
  type     = string
  nullable = true
  default  = null
}
