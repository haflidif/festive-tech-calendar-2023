######################################
#     Creating Network Resources     #
######################################

# Creating Random id to append to the resource group name
resource "random_id" "rg" {
  byte_length = 4
}

resource "azurerm_resource_group" "this" {
  name     = "${var.resource_group_name}-${lower(random_id.rg.hex)}-rg"
  location = var.location
  tags     = var.tags
}