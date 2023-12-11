terraform {
  required_version = ">= 1.3"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.11, < 4.0"
    }

    azapi = {
      source  = "Azure/azapi"
      version = ">= 1.9, < 2.0"
    }
  }
}