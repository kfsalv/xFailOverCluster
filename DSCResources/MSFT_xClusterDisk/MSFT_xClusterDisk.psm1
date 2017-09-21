Import-Module -Name (Join-Path -Path (Split-Path -Path $PSScriptRoot -Parent) `
        -ChildPath 'CommonResourceHelper.psm1')

$script:localizedData = Get-LocalizedData -ResourceName 'MSFT_xClusterDisk'

<#
    .SYNOPSIS
        Returns the current state of the failover cluster disk resource.

    .PARAMETER UniqueId
        The disk UniqueId of the cluster disk.
#>
function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $UniqueId
    )

    Write-Verbose -Message ($script:localizedData.GetClusterDiskInformation -f $UniqueId)

    if ($null -ne ($diskInstance = Get-CimInstance -ClassName MSCluster_Disk -Namespace 'Root\MSCluster' -Filter "UniqueId = '$UniqueID'"))
    {
        $diskResource = Get-ClusterResource |
            Where-Object -FilterScript { $_.ResourceType -eq 'Physical Disk' } |
            Where-Object -FilterScript { ($_ | Get-ClusterParameter -Name DiskIdGuid).Value -eq $diskInstance.Id }

        @{
            UniqueId = $UniqueId
            Ensure   = 'Present'
            Label    = $diskResource.Name
        }
    }
    else
    {
        @{
            UniqueId = $UniqueId
            Ensure   = 'Absent'
            Label    = ''
        }
    }
}

<#
    .SYNOPSIS
        Adds or removed the failover cluster disk resource from the failover cluster.

    .PARAMETER UniqueId
        The disk UniqueId of the cluster disk.

    .PARAMETER Ensure
        Define if the cluster disk should be added (Present) or removed (Absent).
        Default value is 'Present'.

    .PARAMETER Label
        The disk label that should be assigned to the disk on the Failover Cluster
        disk resource.
#>
function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $UniqueId,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $Label
    )

    $getTargetResourceResult = Get-TargetResource -UniqueId $UniqueId

    if ($Ensure -eq 'Present')
    {
        if ($getTargetResourceResult.Ensure -ne $Ensure)
        {
            Write-Verbose -Message ($script:localizedData.AddDiskToCluster -f $UniqueId)
            $disk = Get-Disk -UniqueId $UniqueId
            Get-ClusterAvailableDisk | Where-Object -FilterScript {
                $_.Number -eq $disk.Number
            } | Add-ClusterDisk | Out-Null
        }

        if ($getTargetResourceResult.Label -ne $Label)
        {
            Write-Verbose -Message ($script:localizedData.SetDiskLabel -f $UniqueId, $Label)

            $diskInstance = Get-CimInstance -ClassName MSCluster_Disk -Namespace 'Root\MSCluster' -Filter "UniqueId = '$UniqueID'"

            $diskResource = Get-ClusterResource |
                Where-Object -FilterScript { $_.ResourceType -eq 'Physical Disk' } |
                Where-Object -FilterScript {
                ($_ | Get-ClusterParameter -Name DiskIdGuid).Value -eq $diskInstance.Id
            }

            # Set the label of the cluster disk
            $diskResource.Name = $Label
            $diskResource.Update()
        }
    }
    else
    {
        if ($getTargetResourceResult.Ensure -eq 'Present' -and $Ensure -eq 'Absent')
        {
            Write-Verbose -Message ($script:localizedData.RemoveDiskFromCluster -f $UniqueId)

            $diskInstance = Get-CimInstance -ClassName MSCluster_Disk -Namespace 'Root\MSCluster' -Filter "UniqueId = '$UniqueID'"

            $diskResource = Get-ClusterResource |
                Where-Object -FilterScript { $_.ResourceType -eq 'Physical Disk' } |
                Where-Object -FilterScript {
                ($_ | Get-ClusterParameter -Name DiskIdGuid).Value -eq $diskInstance.Id
            }

            # Remove the cluster disk
            $diskResource | Remove-ClusterResource -Force
        }
    }
}

<#
    .SYNOPSIS
       Tests that the failover cluster disk resource exist in the failover cluster,
       and that is has the correct label.

    .PARAMETER UniqueId
        The disk UniqueId of the cluster disk.

    .PARAMETER Ensure
        Define if the cluster disk should be added (Present) or removed (Absent).
        Default value is 'Present'.

    .PARAMETER Label
        The disk label that should be assigned to the disk on the Failover Cluster
        disk resource.
#>
function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [Parameter(Mandatory = $true)]
        [System.String]
        $UniqueId,

        [Parameter()]
        [ValidateSet('Present', 'Absent')]
        [System.String]
        $Ensure = 'Present',

        [Parameter()]
        [System.String]
        $Label
    )

    Write-Verbose -Message ($script:localizedData.EvaluatingClusterDiskInformation -f $UniqueId)

    $getTargetResourceResult = Get-TargetResource -UniqueId $UniqueId

    if ($Ensure -eq 'Present')
    {
        return (
            ($Ensure -eq $getTargetResourceResult.Ensure) -and
            (($Label -eq $getTargetResourceResult.Label) -or (-not $PSBoundParameters.ContainsKey('Label')))
        )
    }
    else
    {
        return $Ensure -eq $getTargetResourceResult.Ensure
    }
}

Export-ModuleMember -Function *-TargetResource
