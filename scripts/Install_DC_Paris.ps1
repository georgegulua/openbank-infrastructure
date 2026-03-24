#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installation du Contrôleur de Domaine Principal — Site Paris
    Domaine : OPENBANK.LOC

.DESCRIPTION
    1. Configuration IP statique (10.0.1.2/24)
    2. Renommage du serveur (SRV-DC-PARIS)
    3. Installation rôle AD DS
    4. Promotion en contrôleur de domaine (nouvelle forêt OPENBANK.LOC)

.NOTES
    Source : Cahier des charges OpenBank
    IP DC Paris   : 10.0.1.2/24 | GW : 10.0.1.1 (SNS-PARIS) | DNS : 127.0.0.1
    Exécuter en tant qu'Administrateur sur Windows Server 2022
#>

# ============================================================
# VARIABLES
# ============================================================
$ServerName = "SRV-DC-PARIS"
$DomainName = "OPENBANK.LOC"
$NetBiosName = "OPENBANK"
$SafeModePassword = Read-Host -Prompt "Mot de passe DSRM (restauration AD)" -AsSecureString

$IPAddress = "10.0.1.2"
$PrefixLength = 24
$DefaultGateway = "10.0.1.1"       # Interface LAN du SNS-PARIS
$DNSServer = "127.0.0.1"      # Lui-même (après promotion)

# ============================================================
# ÉTAPE 1 — Configuration IP statique
# ============================================================
Write-Host "`n[1/4] Configuration réseau (IP : $IPAddress)..." -ForegroundColor Cyan

$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
$iface = $adapter.Name

Remove-NetIPAddress -InterfaceAlias $iface -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute     -InterfaceAlias $iface -Confirm:$false -ErrorAction SilentlyContinue

New-NetIPAddress -InterfaceAlias $iface -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway
Set-DnsClientServerAddress -InterfaceAlias $iface -ServerAddresses $DNSServer

Write-Host "    ✔ IP : $IPAddress/$PrefixLength — GW : $DefaultGateway — DNS : $DNSServer" -ForegroundColor Green

# ============================================================
# ÉTAPE 2 — Renommage du serveur
# ============================================================
Write-Host "`n[2/4] Renommage en '$ServerName'..." -ForegroundColor Cyan

if ($env:COMPUTERNAME -ne $ServerName) {
    Rename-Computer -NewName $ServerName -Force
    Write-Host "    ✔ Renommé. Redémarrage requis — relancez le script après." -ForegroundColor Yellow
    Restart-Computer -Confirm
    exit
}
else {
    Write-Host "    ✔ Déjà nommé '$ServerName'" -ForegroundColor Green
}

# ============================================================
# ÉTAPE 3 — Installation du rôle AD DS
# ============================================================
Write-Host "`n[3/4] Installation du rôle AD DS..." -ForegroundColor Cyan

if (-not (Get-WindowsFeature -Name AD-Domain-Services).Installed) {
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Write-Host "    ✔ Rôle AD DS installé" -ForegroundColor Green
}
else {
    Write-Host "    ✔ Rôle déjà installé" -ForegroundColor Green
}

# ============================================================
# ÉTAPE 4 — Promotion en DC (nouvelle forêt OPENBANK.LOC)
# ============================================================
Write-Host "`n[4/4] Promotion en contrôleur de domaine (forêt : $DomainName)..." -ForegroundColor Cyan

Import-Module ADDSDeployment

Install-ADDSForest `
    -DomainName             $DomainName `
    -DomainNetbiosName      $NetBiosName `
    -DomainMode             "WinThreshold" `
    -ForestMode             "WinThreshold" `
    -DatabasePath           "C:\Windows\NTDS" `
    -LogPath                "C:\Windows\NTDS" `
    -SysvolPath             "C:\Windows\SYSVOL" `
    -SafeModeAdministratorPassword $SafeModePassword `
    -InstallDns:$true `
    -CreateDnsDelegation:$false `
    -NoRebootOnCompletion:$false `
    -Force:$true

Write-Host "`n✔ Promotion terminée. Le serveur va redémarrer automatiquement." -ForegroundColor Green
Write-Host "  → Après redémarrage, exécutez : 02_create_AD_users_groups_OUs.ps1" -ForegroundColor Yellow
