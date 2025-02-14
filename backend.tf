# # --------------------------------------------------------
# # Backend Configuration for Terraform: Specifies the Azure Blob Storage as the backend for storing tfstate
# # --------------------------------------------------------
# terraform {
#   backend "azurerm" {
#     resource_group_name  = "test-resources-1"   # Replace with your Resource Group name
#     storage_account_name = "teststorageacc2025" # Replace with your Storage Account name
#     container_name       = "tfstate-container"  # Replace with your Blob Container name
#     key                  = "terraform.tfstate"  # Name of the state file
#   }
# }