[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $location = "westeurope",
    [Parameter()]
    [string]
    $resourceGroupName = "demo-rg",
    [Parameter()]
    [string]
    $userAssignedIdentityName = "demo-mi",
    [Parameter()]
    [string]
    $subscriptionId = "00000000-0000-0000-0000-000000000000",
    [Parameter()]
    [string]
    $tenantId = "00000000-0000-0000-0000-000000000000"
)

# Check if Connect-AzAccount is needed.
$alreadyLoggedIn = Get-AzContext -ErrorAction SilentlyContinue

# Login to Azure using Azure PowerShell if not already logged in.
if ($null -eq $alreadyLoggedIn) {
    try {
        Connect-AzAccount -Tenant $tenantId -Subscription $subscriptionId -ErrorAction SilentlyContinue
    } catch {
        Write-Error "Failed to connect to Azure account or select Azure subscription"
        exit 1
    }
}

# Set the right context
try {
    $Context = Set-AzContext -SubscriptionId $subscriptionId -ErrorAction SilentlyContinue
    if ($null -eq $Context) {
        Write-Error "Failed to set Azure context"
        exit 2
    }
} catch {
    Write-Error "Failed to set Azure context"
    exit 2
}

# Initialize an array to store the status of the resources
$resourceStatuses = @{}

# Initialize variables to track if resources were created
$resourceGroupCreated = $false
$uamiCreated = $false
$roleAssignmentCreated = $false

# Check if the Azure Resource Group already exists
try {
    $resourceGroup = Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue
} catch {
    Write-Error "Failed to get Azure resource group"
    return 3
}

# If the resource group does not exist, create it
if ($null -eq $resourceGroup) {
    try {
        $resourceGroup = New-AzResourceGroup -Name $resourceGroupName -Location $location
        $resourceGroupCreated = $true
    } catch {
        Write-Error "Failed to create Azure resource group"
        return 4
    }
}

$resourceStatuses["ResourceGroup"] = [PSCustomObject]@{
    "Name" = $resourceGroup.ResourceGroupName
    "Id" = $resourceGroup.ResourceId
    "ClientId" = "N/A"
    "PrincipalId" = "N/A"
    "Status" = if ($resourceGroupCreated) { "Created" } else { "Already exists" }
}

# Check if the Azure User Assigned Managed Identity already exists
try {
    $uami = Get-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $userAssignedIdentityName -ErrorAction SilentlyContinue
} catch {
    Write-Error "Failed to get Azure user assigned managed identity"
    return 5
}

# If the user assigned managed identity does not exist, create it
if ($null -eq $uami) {
    try {
        $uami = New-AzUserAssignedIdentity -ResourceGroupName $resourceGroupName -Name $userAssignedIdentityName -Location $location
        $uamiCreated = $true
    } catch {
        Write-Error "Failed to create Azure user assigned managed identity"
        return 6
    }
}

$resourceStatuses["UserAssignedIdentity"] = [PSCustomObject]@{
    "Name" = $uami.Name
    "Id" = $uami.Id
    "ClientId" = $uami.ClientId
    "PrincipalId" = $uami.PrincipalId
    "Status" = if ($uamiCreated) { "Created" } else { "Already exists" }
}

# Wait for the managed identity to be provisioned
if ($uamiCreated) {
    Write-Progress -Activity "Waiting for the user assigned managed identity to be provisioned" -Id 1 -Status "In Progress"
    # Write-Host "Waiting for the user assigned managed identity to be provisioned..."
    Start-Sleep -Seconds 30
    Write-Progress -Activity "Waiting for the user assigned managed identity to be provisioned" -Id 1 -Status "Completed" -Completed
}

# Check if the Owner role assignment already exists for the user assigned managed identity
try {
    $roleAssignment = Get-AzRoleAssignment -ObjectId $uami.PrincipalId -RoleDefinitionName "Owner" -Scope $resourceGroup.ResourceId -ErrorAction SilentlyContinue
} catch {
    Write-Error "Failed to get role assignment for the user assigned managed identity"
    return 8
}

# If the role assignment does not exist, create it
if ($null -eq $roleAssignment) {
    try {
        $roleAssignment = New-AzRoleAssignment -ObjectId $uami.PrincipalId -RoleDefinitionName "Owner" -Scope $resourceGroup.ResourceId -ErrorAction Stop
        $roleAssignmentCreated = $true
    } catch {
        Write-Error "Failed to assign Owner role to the user assigned managed identity"
        return 9
    }
}

$resourceStatuses["RoleAssignment"] = [PSCustomObject]@{
    "Name" = $roleAssignment.RoleDefinitionName
    "Identity" = $roleAssignment.DisplayName
    "Scope" = $roleAssignment.Scope
    "Status" = if ($roleAssignmentCreated) { "Created" } else { "Already exists" }
}


# Output the status of the resources
return $resourceStatuses