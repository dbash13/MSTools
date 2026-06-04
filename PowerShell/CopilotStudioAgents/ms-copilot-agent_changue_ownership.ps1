#requires -Modules Az.Accounts
<#
    .SYNOPSIS
        Simple script for changue Microsoft Copilot Studio Agent ownership

    .DESCRIPTION
        Based on official documentation from Microsoft Learn:
        - https://learn.microsoft.com/en-us/microsoft-copilot-studio/admin-api-reassign-ownership-orphaned-agent

    .PARAMETER EnvironmentId
        Environment ID where the agent is deployed. Can be obtained fast from the URL in PowerPlatform nor Copilot Studio.
        IE: https://copilotstudio.microsoft.com/environments/<<123456b3-a333-e343-9bca-0c04cb1cfc45>>/home

    .PARAMETER BotId
        ID of the bot that you want to modify the ownership, can be obtained from Copilot Studio URI:
        IE: https://copilotstudio.microsoft.com/environments/123456b3-a333-e343-9bca-0c04cb1cfc45/bots/<<d773ee3a-5257-f011-877b-7c1e522a014e>>

    .PARAMETER NewOwnerEntraId
        User ID from Microsoft EntraID user to assign the agent. Can be obtained from Azure portal or cmdlet Get-AzAdUser.
        IE:
            - $entraUserId = Connect-AzAccount ; (Get-AzAdUser -UserPrincipalName "someUser@domain.net").Id
    
    .EXAMPLE
         .\ms-copilot-agent_changue_ownership.ps1 -EnvironmentId "123456b3-a333-e343-9bca-0c04cb1cfc45" `
            -BotId "d773ee3a-5257-f011-877b-7c1e522a014e" -NewOwnerEntraId "bc9c04b0-5cfe-4b09-8a14-139721552d40"  
                
    .NOTES
        Daniel Fernandez Martinez 
        GitHub: dbash13
#>

param(
    [Parameter(Mandatory = $true, HelpMessage="Environment ID where the agent is on")]
    [string]$EnvironmentId,

    [Parameter(Mandatory = $true, HelpMessage="The ID of the Agent")]
    [string]$BotId,

    [Parameter(Mandatory = $true, HelpMessage="EntraID user ID")]
    [string]$NewOwnerEntraId

    # [Parameter(Mandatory = $false)]
    # [string]$TenantId
)


Write-Host "Checking Azure login..."

try {
    $context = Get-AzContext
    if (-not $context) {
        Connect-AzAccount | Out-Null
    }
} catch {
    Connect-AzAccount | Out-Null
}

Write-Host "Getting access token..."

$tokenSecure = (Get-AzAccessToken -ResourceUrl "https://api.powerplatform.com").Token

$accessToken = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
    [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenSecure)
) #If pwsh +7 can be used ConvertFrom-SecureString -AsPlainText...


$uri = "https://api.powerplatform.com/copilotstudio/environments/$EnvironmentId/bots/$BotId/api/botAdminOperations/reassign?api-version=1"

Write-Host "Calling API:"
Write-Host $uri


$body = @{
    newOwnerEntraObjectId = $NewOwnerEntraId
} | ConvertTo-Json


$headers = @{
    Authorization  = "Bearer $accessToken"
    "Content-Type" = "application/json"
}


try {
    $response = Invoke-RestMethod `
        -Method POST `
        -Uri $uri `
        -Headers $headers `
        -Body $body

    Write-Host "SUCCESS"
    $response | ConvertTo-Json -Depth 5
} catch {
    Write-Host "ERROR:"
    Write-Host $_.Exception.Message
}

# Read-Host "Finished execution... press any key to exit"