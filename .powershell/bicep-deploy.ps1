param(
    [Parameter(Mandatory=$false)]
    [switch]$whatIf,

    [Parameter(Mandatory=$false)]
    [bool]$cleanup = $false,

    [Parameter(Mandatory=$false)]
    [bool]$runOnlyPreReq = $false,

    [Parameter(Mandatory=$false)]
    [string]$adoResourceGroupName = "cnappenv-ado-rg",

    [Parameter(Mandatory=$false)]
    [string]$tfResourceGroupName = "tf-infra-env-rg",

    [Parameter(Mandatory=$false)]
    [string]$location = "westeurope",

    [Parameter(Mandatory=$false)]
    [string]$adoUserAssignedIdentityName = "cnappenv-ado-mi",

    [Parameter(Mandatory=$false)]
    [string]$tfUserAssignedIdentityName = "tf-infra-env-mi",

    [Parameter(Mandatory=$true)]
    [string]$subscriptionId,

    [Parameter(Mandatory=$true)]
    [string]$tenantId
)

if ($runOnlyPreReq) {
    Write-Progress -Activity "Deploying pre-requisites for the AzureDevOps Self-Hosted Agent Infrastructure" -Id 1 -Status "In Progress"
    # This Script will deploy the pre-requisites for the AzureDevOps Self-Hosted Agent Infrastructure.
    $PreReqAdo = . "$PSScriptRoot/pre-req.ps1" -ResourceGroupName $adoResourceGroupName -Location $location -UserAssignedIdentityName $adoUserAssignedIdentityName -SubscriptionId $subscriptionId -TenantId $tenantId
    $PreReqAdo | ConvertTo-Json -Depth 100

    Write-Progress -Activity "Deploying pre-requisites for the Terraform Infrastructure" -Id 1 -Status "In Progress"
    # This Script will deploy the pre-requisites for the Terraform Infrastructure.
    $PreReqTF = . "$PSScriptRoot/pre-req.ps1" -ResourceGroupName $tfResourceGroupName -Location $location -UserAssignedIdentityName $tfUserAssignedIdentityName -SubscriptionId $subscriptionId -TenantId $tenantId
    $PreReqTF | ConvertTo-Json -Depth 100
    Write-Progress -Activity "Deploying pre-requisites for the Terraform Infrastructure" -Id 1 -Status "Completed" -Completed

}

if (!$runOnlyPreReq -and !$cleanup) {

    # Checking if the pre-requisites have been deployed

    Write-Progress -Activity "Deploying pre-requisites for the AzureDevOps Self-Hosted Agent Infrastructure" -Id 1 -Status "In Progress"
    # This Script will deploy the pre-requisites for the AzureDevOps Self-Hosted Agent Infrastructure.
    $PreReqAdo = . "$PSScriptRoot/pre-req.ps1" -ResourceGroupName $adoResourceGroupName -Location $location -UserAssignedIdentityName $adoUserAssignedIdentityName -SubscriptionId $subscriptionId -TenantId $tenantId
    $PreReqAdo | ConvertTo-Json -Depth 100

    Write-Progress -Activity "Deploying pre-requisites for the Terraform Infrastructure" -Id 1 -Status "In Progress"
    # This Script will deploy the pre-requisites for the Terraform Infrastructure.
    $PreReqTF = . "$PSScriptRoot/pre-req.ps1" -ResourceGroupName $tfResourceGroupName -Location $location -UserAssignedIdentityName $tfUserAssignedIdentityName -SubscriptionId $subscriptionId -TenantId $tenantId
    $PreReqTF | ConvertTo-Json -Depth 100
    Write-Progress -Activity "Deploying pre-requisites for the Terraform Infrastructure" -Id 1 -Status "Completed" -Completed


    $adoBicepFilePath = "$PSScriptRoot/../iac/bicep/agent-infrastructure"

    # Add the parameter to the Azure DevOps deployment command
    $adoDeploymentParameters = @{
        'Name' = "cnappenv-ado-$(Get-Date -Format 'yyyMMddHHmm')"
        'TemplateFile' = "$($adoBicepFilePath)/main.bicep"
        'TemplateParameterFile' = "$($adoBicepFilePath)/main.bicepparam"
        'ResourceGroupName' = $PreReqAdo.ResourceGroup.Name
        'userAssignedIdentityName' = $PreReqAdo.UserAssignedIdentity.Name
    }

    $adoDeploymentParameters

    # Create the Azure DevOps Self-hosted Agent Infrastructure
    if($whatIf){
        $adoDeployment = New-AzResourceGroupDeployment @adoDeploymentParameters -WhatIf
    }
    else {
        $adoDeployment = New-AzResourceGroupDeployment @adoDeploymentParameters
        $adoDeployment
        $adoDeployment.Outputs.vnetId.Value
        $adoDeployment.Outputs.vnetName.Value
        $adoDeployment.Outputs.containerSubnetId.Value
    }

    $tfBicepFilePath = "$PSScriptRoot/../iac/bicep/terraform-infrastructure"

    # Adding parameters to the Terraform deployment command
    $tfDeploymentParameters = @{
        'Name' = "tf-infra-env-$(Get-Date -Format 'yyyMMddHHmm')"
        'TemplateFile' = "$($tfBicepFilePath)/main.bicep"
        'TemplateParameterFile' = "$($tfBicepFilePath)/main.bicepparam"
        'ResourceGroupName' = $PreReqTF.ResourceGroup.Name
        # 'userAssignedIdentityName' = $PreReqTF.UserAssignedIdentity.Name
        'containerSubnetId' = $adoDeployment.Outputs.containerSubnetId.Value # Id of the Subnet created by the ADO deployment, to be used for Service Endpoints on the storage account created by the TF deployment
    }

    $tfDeploymentParameters

    # Creating the Terraform Infrastructure (VNet, Subnet, Storage Account for state files, etc.)
    if ($whatIf) {
        $tfDeploymentParameters.containerSubnetId = "whatIfPlaceholder"
        $tfDeployment = New-AzResourceGroupDeployment @tfDeploymentParameters -WhatIf
    }
    else {
        $tfDeployment = New-AzResourceGroupDeployment @tfDeploymentParameters
        $tfDeployment
        $tfDeployment.Outputs.vnetId.Value
        $tfDeployment.Outputs.vnetName.Value
    }

    # Creating vnet Peering between the VNet created by the ADO deployment and the VNet created by the TF deployment
    if ($adoDeployment -and $tfDeployment) {
    $peeringBicepFilePath = "$PSScriptRoot/../iac/bicep/vnet-peering"

    $peeringDeploymentParameters = @{
        'Name' = "vnetpeering-$(Get-Date -Format 'yyyMMddHHmm')"
        'Location' = $location
        'TemplateFile' = "$($peeringBicepFilePath)/main.bicep"
        'firstVnetRg' = $PreReqAdo.ResourceGroup.Name
        'firstVnetName' = $adoDeployment.Outputs.vnetName.Value
        'secondVnetRg' = $PreReqTF.ResourceGroup.Name
        'secondVnetName' = $tfDeployment.Outputs.vnetName.Value
    }

    $peeringDeploymentParameters
        if ($whatIf) {
            $peeringDeploymentParameters.firstVnetName = "whatIfPlaceholder"
            $peeringDeploymentParameters.secondVnetName = "whatIfPlaceholder"
            $peeringDeployment = New-AzSubscriptionDeployment @peeringDeploymentParameters -WhatIf
        }
        else {
            $peeringDeployment = New-AzSubscriptionDeployment @peeringDeploymentParameters
            $peeringDeployment
        }
    }    
}

# Clean up resources.
if ($cleanup) {
    Write-Progress -Activity "Cleaning up Infrastructure" -Id 1 -Status "In Progress"
    Write-Progress -Activity "Cleaning up AzureDevOps Self-Hosted Agent Infrastructure" -Id 1 -Status "In Progress"
    try {
        $adoResourceGroup = Get-AzResourceGroup -Name $adoResourceGroupName -ErrorAction SilentlyContinue
        if ($adoResourceGroup) {
            Remove-AzResourceGroup -Name $adoResourceGroupName -Force
        }
    }
    catch {
        $message = $_
        Write-Error "Failed to remove Azure resource group $($adoResourceGroupName), make sure you have the correct context selected"
        Write-Warning $message
        Write-Progress -Activity "Cleaning up AzureDevOps Self-Hosted Agent Infrastructure" -Id 1 -Status "Failed"
        return 1
    }
    finally{
        Write-Progress -Activity "Cleaning up AzureDevOps Self-Hosted Agent Infrastructure" -Id 1 -Status "Completed" -Completed
    }
        
    Write-Progress -Activity "Cleaning up Terraform Infrastructure..." -Id 1 -Status "In Progress"
    try {
        $tfResourceGroup = Get-AzResourceGroup -Name $tfResourceGroupName -ErrorAction SilentlyContinue
        if ($tfResourceGroup) {
            Remove-AzResourceGroup -Name $tfResourceGroupName -Force
        }
    }
    catch {
        $message = $_
        Write-Error "Failed to remove Azure resource group $($tfResourceGroupName), make sure you have the correct context selected"
        Write-Warning $message
        Write-Progress -Activity "Cleaning up Terraform Infrastructure..." -Id 1 -Status "Failed"
        return 2      
    }
    finally {
        Write-Progress -Activity "Cleaning up Terraform Infrastructure..." -Id 1 -Status "Completed" -Completed
    }

    Write-Progress -Activity "Cleaning up Infrastructure" -Id 1 -Status "Completed" -Completed
    
}