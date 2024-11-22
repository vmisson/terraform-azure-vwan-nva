variable "subscription_id" {
  type = string
}

variable "resource_group_name" {
  type    = string
  default = "rg-vwan-001"
}

variable "default_location" {
  type    = string
  default = "North Europe"
}

variable "vhub1_location" {
  type    = string
  default = "North Europe"
}

variable "vhub1_location_name" {
  type    = string
  default = "neu"
}

variable "vhub1_ip_prefix" {
  type    = string
  default = "10.10.0.0/16"

}

variable "vhub2_location" {
  type    = string
  default = "East US2"
}

variable "vhub2_location_name" {
  type    = string
  default = "eus"
}

variable "vhub2_ip_prefix" {
  type    = string
  default = "10.20.0.0/16"
}

variable "username" {
  type    = string
  default = "vincent"
}

variable "password" {
  type    = string
  default = "Password1234!"
}