<#
.SYNOPSIS
    Deletes specified Kubernetes Secrets and ConfigMaps and recreates them from provided files.

.DESCRIPTION
    This script uses kubectl to delete the following:
        - Secrets: librechat-vectordb, librechat-credentials-env
        - ConfigMaps: librechat-config, librechat-public-env
    It then recreates them using the specified .env and .yaml files.

.NOTES
    - Ensure you have the necessary permissions to delete and create resources in the target namespace.
    - Modify the $namespace variable if your resources are in a different namespace.
#>

# Variables
$namespace = "wonkachat" # Change this to your target namespace if different

# Define Secrets with their corresponding source files
$secrets = @(
    @{ Name = "librechat-vectordb"; File = ".env.rag.secret" },
    @{ Name = "librechat-credentials-env"; File = ".env.secret" }
)

# Define ConfigMaps with their corresponding source files
$configMaps = @(
    @{ Name = "librechat-config"; File = "librechat.yaml" },
    @{ Name = "librechat-public-env"; File = ".env.public" }
)

# Function to delete a Kubernetes resource
function Delete-K8sResource {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Type,

        [Parameter(Mandatory=$true)]
        [string]$Name
    )

    Write-Host "Deleting $Type '$Name' in namespace '$namespace'..."
    kubectl delete $Type $Name --namespace $namespace --ignore-not-found | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully deleted $Type '$Name' or it did not exist."
    }
    else {
        Write-Warning "Failed to delete $Type '$Name'. Please check your permissions and resource existence."
    }
}

# Function to create a Kubernetes Secret
function Create-K8sSecret {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string]$File
    )

    if (-Not (Test-Path $File)) {
        Write-Error "Secret source file '$File' does not exist. Aborting creation of Secret '$Name'."
        return
    }

    Write-Host "Creating Secret '$Name' from file '$File' in namespace '$namespace'..."
    kubectl create secret generic $Name --from-env-file=$File --namespace $namespace

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully created Secret '$Name'."
    }
    else {
        Write-Warning "Failed to create Secret '$Name'. Please check the file format and permissions."
    }
}

# Function to create a Kubernetes ConfigMap
function Create-K8sConfigMap {
    param (
        [Parameter(Mandatory=$true)]
        [string]$Name,

        [Parameter(Mandatory=$true)]
        [string]$File
    )

    if (-Not (Test-Path $File)) {
        Write-Error "ConfigMap source file '$File' does not exist. Aborting creation of ConfigMap '$Name'."
        return
    }

    # Determine if the file is a YAML or an env file based on extension
    $extension = [System.IO.Path]::GetExtension($File).ToLower()

    if ($extension -eq ".yaml" -or $extension -eq ".yml") {
        Write-Host "Creating ConfigMap '$Name' from file '$File' in namespace '$namespace'..."
        kubectl create configmap $Name --from-file=$File --namespace $namespace
    }
    else {
        Write-Host "Creating ConfigMap '$Name' from env file '$File' in namespace '$namespace'..."
        kubectl create configmap $Name --from-env-file=$File --namespace $namespace
    }

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Successfully created ConfigMap '$Name'."
    }
    else {
        Write-Warning "Failed to create ConfigMap '$Name'. Please check the file format and permissions."
    }
}

# Main Execution

Write-Host "Starting deletion and recreation of Secrets and ConfigMaps..."

# Process Secrets
foreach ($secret in $secrets) {
    Delete-K8sResource -Type "secret" -Name $secret.Name
    Create-K8sSecret -Name $secret.Name -File $secret.File
}

# Process ConfigMaps
foreach ($configMap in $configMaps) {
    Delete-K8sResource -Type "configmap" -Name $configMap.Name
    Create-K8sConfigMap -Name $configMap.Name -File $configMap.File
}

Write-Host "All specified Secrets and ConfigMaps have been deleted and recreated successfully."
