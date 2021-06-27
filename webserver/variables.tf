
variable "web_server_rg" {
  type        = string
  description = "resource group name"
}

variable "resource_prefix" {
  type        = string
  description = "resource prefix"
}


variable "web_server_name" {
  type        = string
  description = "Webserver name"
}

variable "environment" {
  type        = string
  description = "dev or prod variable"
}

variable "web_server_count" {
  type        = number
  description = "use to dynamically create names for multiple servers"
}


variable "terraform_my_resource_script_version" {
  type        = string
  description = "terraform script version"
}

variable "domain_name_label" {
  type        = string
  description = "domin name label"
}