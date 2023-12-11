##################################################
# VARIABLES                                      #
##################################################
variable "location" {
  type        = string
  default     = "westeurope"
  description = "Region / Location where resources should be deployed"
}

variable "resource_group_name" {
  type        = string
  description = "Name of the Resource Group where virtual network is deployed + NSG and RT for testing the module with existing NSG and RT"
}

variable "tags" {
  type        = map(string)
  description = "(Optional): Resource Tags"
  default     = {}
}