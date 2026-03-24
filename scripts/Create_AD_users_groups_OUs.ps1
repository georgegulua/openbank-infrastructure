#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Création des OUs, Groupes et Utilisateurs Active Directory
    Domaine : OPENBANK.LOC
    Source  : Cahier des charges OpenBank

.NOTES
    À exécuter sur SRV-DC-PARIS APRÈS la promotion en DC
    Mot de passe initial : Utilisateur@2024! (à changer au 1er login)
#>

Import-Module ActiveDirectory

$DomainDN = "DC=OPENBANK,DC=LOC"
$Password = Read-Host -Prompt "Mot de passe initial par défaut pour les utilisateurs (ex: Utilisateur@2024!)" -AsSecureString

Write-Host "`n=== Création des Unités d'Organisation ===" -ForegroundColor Cyan

$OUs = @(
    # Racine
    @{ Name = "OPENBANK"; Path = $DomainDN },
    # Sites
    @{ Name = "Paris"; Path = "OU=OPENBANK,$DomainDN" },
    @{ Name = "Nantes"; Path = "OU=OPENBANK,$DomainDN" },
    # Direction (racine)
    @{ Name = "Direction"; Path = "OU=OPENBANK,$DomainDN" },
    # Paris
    @{ Name = "IT"; Path = "OU=Paris,OU=OPENBANK,$DomainDN" },
    @{ Name = "Banque"; Path = "OU=Paris,OU=OPENBANK,$DomainDN" },
    @{ Name = "Ordinateurs"; Path = "OU=Paris,OU=OPENBANK,$DomainDN" },
    # Nantes
    @{ Name = "Banque"; Path = "OU=Nantes,OU=OPENBANK,$DomainDN" },
    @{ Name = "Ordinateurs"; Path = "OU=Nantes,OU=OPENBANK,$DomainDN" },
    # Groupes globaux
    @{ Name = "Groupes"; Path = "OU=OPENBANK,$DomainDN" }
)

foreach ($ou in $OUs) {
    $fullDN = "OU=$($ou.Name),$($ou.Path)"
    if (-not (Get-ADOrganizationalUnit -Filter "DistinguishedName -eq '$fullDN'" -ErrorAction SilentlyContinue)) {
        New-ADOrganizationalUnit -Name $ou.Name -Path $ou.Path -ProtectedFromAccidentalDeletion $false
        Write-Host "    ✔ OU : $fullDN" -ForegroundColor Green
    }
    else {
        Write-Host "    − Existante : $fullDN" -ForegroundColor Gray
    }
}

Write-Host "`n=== Création des Groupes ===" -ForegroundColor Cyan

$Groups = @(
    @{ Name = "GRP_IT"; Path = "OU=Groupes,OU=OPENBANK,$DomainDN"; Desc = "Équipe IT (Paris)" },
    @{ Name = "GRP_Banque_Paris"; Path = "OU=Groupes,OU=OPENBANK,$DomainDN"; Desc = "Banque site Paris" },
    @{ Name = "GRP_Banque_Nantes"; Path = "OU=Groupes,OU=OPENBANK,$DomainDN"; Desc = "Banque site Nantes" },
    @{ Name = "GRP_Direction"; Path = "OU=Groupes,OU=OPENBANK,$DomainDN"; Desc = "Direction OpenBank" },
    @{ Name = "GRP_VPN_SSL"; Path = "OU=Groupes,OU=OPENBANK,$DomainDN"; Desc = "Utilisateurs VPN SSL (nomades)" },
    @{ Name = "GRP_Proxy"; Path = "OU=Groupes,OU=OPENBANK,$DomainDN"; Desc = "Utilisateurs proxy HTTP/HTTPS" },
    @{ Name = "GRP_USB_Autorise"; Path = "OU=Groupes,OU=OPENBANK,$DomainDN"; Desc = "USB autorisé (IT uniquement)" }
)

foreach ($grp in $Groups) {
    if (-not (Get-ADGroup -Filter "Name -eq '$($grp.Name)'" -ErrorAction SilentlyContinue)) {
        New-ADGroup -Name $grp.Name -GroupScope Global -GroupCategory Security `
            -Description $grp.Desc -Path $grp.Path
        Write-Host "    ✔ Groupe : $($grp.Name)" -ForegroundColor Green
    }
    else {
        Write-Host "    − Existant : $($grp.Name)" -ForegroundColor Gray
    }
}

Write-Host "`n=== Création des Utilisateurs ===" -ForegroundColor Cyan

# Format : Prenom, Nom, SamAccountName, OU Path, Groupes
$Users = @(
    # Direction
    @{ First = "Louise"; Last = "Chapat"; Sam = "l.chapat"; OU = "OU=Direction,OU=OPENBANK,$DomainDN"; Groups = @("GRP_Direction") },

    # Paris — IT
    @{ First = "Samir"; Last = "Assal"; Sam = "s.assal"; OU = "OU=IT,OU=Paris,OU=OPENBANK,$DomainDN"; Groups = @("GRP_IT", "GRP_USB_Autorise") },
    @{ First = "Paul"; Last = "Bokadi"; Sam = "p.bokadi"; OU = "OU=IT,OU=Paris,OU=OPENBANK,$DomainDN"; Groups = @("GRP_IT", "GRP_USB_Autorise", "GRP_VPN_SSL") },
    # NOTE : vous-même (ASR Junior) — adaptez le nom
    @{ First = "Admin"; Last = "ASRJunior"; Sam = "asr.junior"; OU = "OU=IT,OU=Paris,OU=OPENBANK,$DomainDN"; Groups = @("GRP_IT", "GRP_USB_Autorise", "GRP_VPN_SSL") },

    # Paris — Banque
    @{ First = "Sabrina"; Last = "Ouazani"; Sam = "s.ouazani"; OU = "OU=Banque,OU=Paris,OU=OPENBANK,$DomainDN"; Groups = @("GRP_Banque_Paris", "GRP_Proxy") },
    @{ First = "Lucie"; Last = "Garrido"; Sam = "l.garrido"; OU = "OU=Banque,OU=Paris,OU=OPENBANK,$DomainDN"; Groups = @("GRP_Banque_Paris", "GRP_Proxy") },
    @{ First = "David"; Last = "Azoulay"; Sam = "d.azoulay"; OU = "OU=Banque,OU=Paris,OU=OPENBANK,$DomainDN"; Groups = @("GRP_Banque_Paris", "GRP_Proxy") },

    # Nantes — Banque
    @{ First = "Théo"; Last = "Perrier"; Sam = "t.perrier"; OU = "OU=Banque,OU=Nantes,OU=OPENBANK,$DomainDN"; Groups = @("GRP_Banque_Nantes", "GRP_Proxy", "GRP_VPN_SSL") },
    @{ First = "Ana"; Last = "Garcia"; Sam = "a.garcia"; OU = "OU=Banque,OU=Nantes,OU=OPENBANK,$DomainDN"; Groups = @("GRP_Banque_Nantes", "GRP_Proxy", "GRP_VPN_SSL") },
    @{ First = "Salif"; Last = "Diallo"; Sam = "s.diallo"; OU = "OU=Banque,OU=Nantes,OU=OPENBANK,$DomainDN"; Groups = @("GRP_Banque_Nantes", "GRP_Proxy", "GRP_VPN_SSL") }
)

foreach ($u in $Users) {
    $upn = "$($u.Sam)@OPENBANK.LOC"
    $name = "$($u.First) $($u.Last)"

    if (-not (Get-ADUser -Filter "SamAccountName -eq '$($u.Sam)'" -ErrorAction SilentlyContinue)) {
        New-ADUser `
            -GivenName $u.First -Surname $u.Last -Name $name -DisplayName $name `
            -SamAccountName $u.Sam -UserPrincipalName $upn `
            -Path $u.OU -AccountPassword $Password `
            -PasswordNeverExpires $false -MustChangePasswordAtLogon $true -Enabled $true

        foreach ($grp in $u.Groups) {
            Add-ADGroupMember -Identity $grp -Members $u.Sam -ErrorAction SilentlyContinue
        }
        Write-Host "    ✔ $name ($($u.Sam))" -ForegroundColor Green
    }
    else {
        Write-Host "    − Existant : $($u.Sam)" -ForegroundColor Gray
    }
}

Write-Host "`n✔ Structure AD créée pour OPENBANK.LOC" -ForegroundColor Green
Write-Host "  → Vérifiez dans 'Utilisateurs et Ordinateurs Active Directory'" -ForegroundColor Yellow
