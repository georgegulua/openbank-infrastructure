#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Installation du RODC — Site Nantes (Windows Server 2022 Core)
    Domaine : OPENBANK.LOC

.DESCRIPTION
    1. Configuration IP statique (10.0.2.2/24)
    2. Renommage (SRV-RODC-NANTES)
    3. Jonction au domaine OPENBANK.LOC
    4. Installation rôle AD DS
    5. Promotion en RODC
    6. Configuration lien de réplication inter-sites (20h–7h, toutes les heures)

.NOTES
    Source : Cahier des charges OpenBank
    IP RODC Nantes : 10.0.2.2/24 | GW : 10.0.2.1 (SNS-NANTES) | DNS : 10.0.1.2
    PRÉREQUIS : VPN IPSEC opérationnel + DC Paris (10.0.1.2) joignable
#>

# ============================================================
# VARIABLES
# ============================================================
$ServerName = "SRV-RODC-NANTES"
$DomainName = "OPENBANK.LOC"
$SiteName = "Nantes"
$DomainAdmin = "OPENBANK\Administrateur"

$IPAddress = "10.0.2.2"
$PrefixLength = 24
$DefaultGateway = "10.0.2.1"      # Interface LAN du SNS-NANTES
$DNSPrimary = "10.0.1.2"      # DC Paris
$DNSSecondary = "127.0.0.1"

$SafeModePassword = Read-Host -Prompt "Mot de passe DSRM (restauration AD)" -AsSecureString

# ============================================================
# PRÉ-REQUIS — Test connectivité vers DC Paris
# ============================================================
Write-Host "`n[PRE] Test de connectivité vers DC Paris ($DNSPrimary)..." -ForegroundColor Cyan

if (-not (Test-Connection -ComputerName $DNSPrimary -Count 2 -Quiet)) {
    Write-Host "    ✖ Impossible de joindre $DNSPrimary" -ForegroundColor Red
    Write-Host "      → Vérifier VPN IPSEC entre Paris et Nantes" -ForegroundColor Yellow
    Write-Host "      → Vérifier règle ICMP dans pare-feu Windows du DC Paris" -ForegroundColor Yellow
    exit 1
}
Write-Host "    ✔ DC Paris joignable" -ForegroundColor Green

# ============================================================
# ÉTAPE 1 — Configuration IP statique
# ============================================================
Write-Host "`n[1/5] Configuration réseau (IP : $IPAddress)..." -ForegroundColor Cyan

$adapter = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1
$iface = $adapter.Name

Remove-NetIPAddress -InterfaceAlias $iface -Confirm:$false -ErrorAction SilentlyContinue
Remove-NetRoute     -InterfaceAlias $iface -Confirm:$false -ErrorAction SilentlyContinue

New-NetIPAddress -InterfaceAlias $iface -IPAddress $IPAddress -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway
Set-DnsClientServerAddress -InterfaceAlias $iface -ServerAddresses $DNSPrimary, $DNSSecondary

Write-Host "    ✔ IP : $IPAddress/$PrefixLength — GW : $DefaultGateway — DNS : $DNSPrimary" -ForegroundColor Green

# ============================================================
# ÉTAPE 2 — Renommage
# ============================================================
Write-Host "`n[2/5] Renommage en '$ServerName'..." -ForegroundColor Cyan

if ($env:COMPUTERNAME -ne $ServerName) {
    Rename-Computer -NewName $ServerName -Force
    Write-Host "    ✔ Redémarrage requis — relancez le script après." -ForegroundColor Yellow
    Restart-Computer -Confirm
    exit
}
Write-Host "    ✔ Déjà nommé '$ServerName'" -ForegroundColor Green

# ============================================================
# ÉTAPE 3 — Jonction au domaine
# ============================================================
Write-Host "`n[3/5] Jonction au domaine $DomainName..." -ForegroundColor Cyan

if (-not (Get-WmiObject Win32_ComputerSystem).PartOfDomain) {
    $cred = Get-Credential -Credential $DomainAdmin -Message "Credentials administrateur du domaine"
    Add-Computer -DomainName $DomainName -Credential $cred -Restart -Force
    exit
}
Write-Host "    ✔ Déjà membre du domaine" -ForegroundColor Green

# ============================================================
# ÉTAPE 4 — Installation du rôle AD DS
# ============================================================
Write-Host "`n[4/5] Installation AD DS..." -ForegroundColor Cyan

if (-not (Get-WindowsFeature -Name AD-Domain-Services).Installed) {
    Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools
    Write-Host "    ✔ Rôle AD DS installé" -ForegroundColor Green
}
else {
    Write-Host "    ✔ Rôle déjà installé" -ForegroundColor Green
}

# ============================================================
# ÉTAPE 5 — Promotion en RODC
# ============================================================
Write-Host "`n[5/5] Promotion en RODC..." -ForegroundColor Cyan

Import-Module ADDSDeployment
$cred = Get-Credential -Credential $DomainAdmin -Message "Credentials pour promotion RODC"

Install-ADDSDomainController `
    -DomainName             $DomainName `
    -ReadOnlyReplica:$true `
    -SiteName               $SiteName `
    -InstallDns:$true `
    -Credential             $cred `
    -SafeModeAdministratorPassword $SafeModePassword `
    -DatabasePath           "C:\Windows\NTDS" `
    -LogPath                "C:\Windows\NTDS" `
    -SysvolPath             "C:\Windows\SYSVOL" `
    -NoRebootOnCompletion:$false `
    -Force:$true

Write-Host "`n✔ RODC installé." -ForegroundColor Green

# ============================================================
# ÉTAPE 6 — Lien de réplication inter-sites (20h–7h)
# À exécuter sur SRV-DC-PARIS après promotion du RODC
# ============================================================
Write-Host @"

=== Configuration réplication inter-sites (à exécuter sur SRV-DC-PARIS) ===

# Créer le site AD 'Nantes' s'il n'existe pas
New-ADReplicationSite -Name "Nantes" -ErrorAction SilentlyContinue

# Déplacer le RODC dans le site Nantes
Get-ADDomainController -Identity "SRV-RODC-NANTES" |
    Move-ADDirectoryServer -Site "Nantes"

# Créer un lien de site entre Paris et Nantes
New-ADReplicationSiteLink `
    -Name "Paris-Nantes" `
    -SitesIncluded "Default-First-Site-Name","Nantes" `
    -Cost 100 `
    -ReplicationFrequencyInMinutes 60

# Configurer le planning : uniquement de 20h à 7h
# (Utiliser ADSI ou la console Sites et services AD)
# Via console : Sites et services AD → Inter-Site Transports → IP
#   → clic droit Paris-Nantes → Propriétés → Modifier le planning
"@ -ForegroundColor Cyan
