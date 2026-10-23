<#
.SYNOPSIS
    Script récapitulatif de la mise en place du lab Active Directory DC02-AD-Lab.

.DESCRIPTION
    Reconstitue en PowerShell les étapes réalisées manuellement (via le Gestionnaire de
    serveur et les assistants graphiques) pour monter ce lab : rôle AD DS + promotion en
    contrôleur de domaine, rôle DHCP + étendue + autorisation, création d'un groupe de
    sécurité et de comptes utilisateurs de domaine.

    À lancer en PowerShell, en tant qu'Administrateur, section par section (pas forcément
    d'un coup) — certaines étapes (la promotion notamment) demandent un redémarrage avant
    de pouvoir continuer.

.NOTES
    Environnement : Windows Server 2025, domaine lab.local2, IP fixe 192.168.126.10.
#>

# ============================================================
# 1. Installation du rôle AD DS (Active Directory Domain Services)
# ============================================================
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools


# ============================================================
# 2. Promotion en contrôleur de domaine (nouvelle forêt)
# ============================================================
# Demande un mot de passe pour le mode de restauration des services d'annuaire (DSRM) —
# un mot de passe de secours, différent du mot de passe Administrateur habituel.
$SafeModePassword = Read-Host -AsSecureString "Mot de passe DSRM"

Install-ADDSForest `
    -DomainName "lab.local2" `
    -DomainNetbiosName "LAB" `
    -SafeModeAdministratorPassword $SafeModePassword `
    -InstallDns:$true `
    -Force:$true

# Le serveur redémarre automatiquement ici pour finaliser la promotion.
# Les étapes suivantes se lancent après ce redémarrage, une fois reconnecté.


# ============================================================
# 3. Adresse IP statique (si pas déjà configurée manuellement)
# ============================================================
# Remplacer "Ethernet0" par le vrai nom de la carte réseau (Get-NetAdapter pour vérifier).
New-NetIPAddress -InterfaceAlias "Ethernet0" `
    -IPAddress 192.168.126.10 `
    -PrefixLength 24 `
    -DefaultGateway 192.168.126.254

Set-DnsClientServerAddress -InterfaceAlias "Ethernet0" -ServerAddresses 127.0.0.1


# ============================================================
# 4. Installation du rôle DHCP
# ============================================================
Install-WindowsFeature -Name DHCP -IncludeManagementTools


# ============================================================
# 5. Autorisation du serveur DHCP dans Active Directory
# ============================================================
# Nécessite le vrai compte Administrateur (droits Enterprise Admins) — voir le README
# pour le détail du problème rencontré avec un compte local secondaire.
Add-DhcpServerInDC -DnsName "DC02-AD-Lab.lab.local2" -IPAddress 192.168.126.10


# ============================================================
# 6. Création de l'étendue DHCP
# ============================================================
Add-DhcpServerv4Scope `
    -Name "Lab-192.168.126" `
    -StartRange 192.168.126.100 `
    -EndRange 192.168.126.200 `
    -SubnetMask 255.255.255.0 `
    -State Active

Set-DhcpServerv4OptionValue `
    -ScopeId 192.168.126.0 `
    -Router 192.168.126.254 `
    -DnsServer 192.168.126.10 `
    -DnsDomain "lab.local2"


# ============================================================
# 7. Groupe de sécurité et comptes utilisateurs du domaine
# ============================================================
New-ADGroup -Name "Responsable" -GroupScope Global -GroupCategory Security

# Convention retenue : nom d'ouverture de session = prénom + initiale du nom de famille
# (ex: Paul Bois -> PaulB, Pierre Beau -> PierreB, Clément Croix -> ClementC).
# Un mot de passe est demandé pour chaque compte, à la volée.

New-ADUser `
    -Name "Paul Bois" `
    -GivenName "Paul" `
    -Surname "Bois" `
    -SamAccountName "PaulB" `
    -UserPrincipalName "PaulB@lab.local2" `
    -AccountPassword (Read-Host -AsSecureString "Mot de passe pour PaulB") `
    -Enabled $true

New-ADUser `
    -Name "Pierre Beau" `
    -GivenName "Pierre" `
    -Surname "Beau" `
    -SamAccountName "PierreB" `
    -UserPrincipalName "PierreB@lab.local2" `
    -AccountPassword (Read-Host -AsSecureString "Mot de passe pour PierreB") `
    -Enabled $true

New-ADUser `
    -Name "Clement Croix" `
    -GivenName "Clement" `
    -Surname "Croix" `
    -SamAccountName "ClementC" `
    -UserPrincipalName "ClementC@lab.local2" `
    -AccountPassword (Read-Host -AsSecureString "Mot de passe pour ClementC") `
    -Enabled $true

# Ajouter les comptes concernés au groupe Responsable (ceux ciblés par les GPO) :
Add-ADGroupMember -Identity "Responsable" -Members "PaulB", "PierreB", "ClementC"
