# Lab Active Directory — Windows Server

Projet personnel de lab réseau d'entreprise simplifié, monté avec VMware : un contrôleur de domaine Windows Server (AD DS, DNS, DHCP, partage de fichiers) et un poste client Windows 10 joint au domaine, avec des stratégies de groupe (GPO) appliquées. Objectif : démontrer des compétences concrètes d'administration système/réseau dans le cadre d'une recherche d'alternance (formation TSSR).

## Objectif

Mettre en place, configurer et documenter un petit réseau d'entreprise réaliste :
- Un **contrôleur de domaine** (Active Directory Domain Services) gérant l'authentification et l'annuaire.
- Un service **DNS** pour la résolution de noms du domaine.
- Un service **DHCP** pour la distribution automatique d'adresses IP.
- Un **partage de fichiers** utilisé par des stratégies de groupe.
- Des **postes clients** joints au domaine, avec des comptes utilisateurs et des GPO appliquées selon l'appartenance à un groupe.

## Architecture

```
                    ┌──────────────────────────────┐
                    │   DC02-AD-Lab (Windows Srv)   │
                    │   192.168.126.10              │
                    │   - AD DS (domaine lab.local2)│
                    │   - DNS                       │
                    │   - DHCP (192.168.126.100-200)│
                    │   - Services de fichiers       │
                    └───────────────┬────────────────┘
                                    │
                           réseau NAT (VMware, VMnet8)
                                    │
                    ┌───────────────┴───────────────┐
                    │   Client(s) Windows 10           │
                    │   IP via DHCP (ex: .100)         │
                    │   Membres du domaine lab.local2  │
                    │   GPO appliquées (fond d'écran,  │
                    │   lecteur réseau) selon le groupe│
                    └─────────────────────────────────┘
```

## Outils utilisés

- **VMware Workstation/Player** — virtualisation
- **Windows Server 2025** — contrôleur de domaine
- **Windows 10** — poste(s) client(s)
- PowerShell, invite de commandes, Gestionnaire de serveur, Gestion de stratégie de groupe

## Étapes réalisées

### 1. Mise en place du contrôleur de domaine
- Installation de Windows Server 2025 dans VMware (VM dédiée, réseau NAT).
- Ajout des rôles **AD DS**, **DNS**, **DHCP**, **Services de fichiers et de stockage** via le Gestionnaire de serveur.
- Promotion du serveur en contrôleur de domaine : création de la forêt et du domaine `lab.local2`.
- Attribution d'une adresse IP statique (`192.168.126.10`).

![Gestionnaire de serveur - rôles installés](screenshots/installed%20roles.png)

### 2. Configuration du DHCP
- Installation du rôle DHCP, création d'une étendue (`192.168.126.100` à `192.168.126.200`).
- Désactivation du DHCP intégré de VMware sur le réseau NAT pour éviter un conflit avec le DHCP du domaine.

![Console DHCP avec l'étendue active](screenshots/DHCP.png)

### 3. Création des comptes de domaine
- Création de plusieurs comptes utilisateurs (dont Pierre Beau, Paul Bois, Clément Croix) et d'un groupe de sécurité **Responsable**, dans Active Directory Users and Computers.

![Utilisateurs créés dans l'annuaire](screenshots/AD%20users.png)

### 4. Jonction de postes clients
- Installation de postes Windows 10, jonction au domaine `lab.local2`.
- Connexion réussie avec des comptes de domaine.

![Poste client joint au domaine](screenshots/domain-joined%20client.png)
![ipconfig côté client](screenshots/ipconfig.png)

### 5. Stratégies de groupe (GPO)
- **Fond d'écran imposé** : GPO (Configuration utilisateur → Modèles d'administration → Bureau) pointant vers une image sur le partage de fichiers du serveur.
- **Lecteur réseau automatique** : GPO dédiée (Préférences → Mappages de lecteurs) montant un lecteur vers le dossier partagé à l'ouverture de session.
- Les deux GPO sont **ciblées sur le groupe de sécurité "Responsable"** via le ciblage au niveau de l'élément, pour ne s'appliquer qu'aux comptes concernés, même si la GPO est liée à tout le domaine.

![GPO du lecteur réseau mappé - liaison, propriétés et résultat côté client](screenshots/gpo_dossier_partage.png)

### 6. Organisation de l'annuaire (OU) et restrictions
- Création de trois unités d'organisation (OU) : `Accounts`, `WorkStations` et `Groups`, et déplacement des comptes, du groupe `Responsable` et du poste client depuis les conteneurs par défaut vers ces OU. Les conteneurs `Users`/`Computers` par défaut ne sont pas de vraies OU et ne permettent pas de lier une GPO dessus, d'où ce rangement.
- Deux GPO de restriction ajoutées, liées à tout le domaine : blocage du Panneau de configuration/Paramètres, et blocage de l'invite de commandes (`cmd.exe`).

### 7. Exports de configuration
- Rapport complet de toutes les GPO (réglages, liaisons, ciblage) exporté avec `Get-GPOReport -All -ReportType Html` → [`exports/GPO-Report.html`](exports/GPO-Report.html)
- Zone DNS exportée avec `Export-DnsServerZone` → [`exports/lab.local2-export.dns`](exports/lab.local2-export.dns)
- Configuration DHCP (étendue, options, baux) exportée avec `Export-DhcpServer` → [`exports/DHCP-Export.xml`](exports/DHCP-Export.xml)

### 8. Politique de mot de passe affinée (Fine-Grained Password Policy)
- Création d'une PSO (`PSO-Responsable`) via le Centre d'administration Active Directory, ciblée sur le groupe `Responsable` : longueur minimale 12 caractères, historique de 24 mots de passe, expiration à 30 jours, verrouillage après 3 tentatives échouées.
- Vérifiée avec `Get-ADUserResultantPasswordPolicy` : la politique s'applique bien par-dessus la Default Domain Policy pour ce groupe.

### 9. Deuxième poste client
- Nouvelle VM Windows 10 (pas une copie de la première), jointe au domaine `lab.local2` et placée dans l'OU `WorkStations`, pour se rapprocher d'un vrai petit parc informatique.
- Le DHCP ne répondait pas au premier essai sur cette VM (adresse APIPA) : IP manuelle temporaire pour confirmer la jonction au domaine, puis carte réseau remise en "Automatique (DHCP)" — IP bien obtenue ensuite via le serveur DHCP du domaine.

### 10. Audit des connexions
- Stratégie d'audit des ouvertures de session activée sur le contrôleur de domaine (Default Domain Controllers Policy) et étendue aux postes clients via une GPO dédiée (`Audit-Connexions-Clients`) liée à l'OU `WorkStations`.
- Vérifiée dans l'Observateur d'événements (ID 4624) et avec `auditpol /get`, sur le serveur et sur un client. Chaque machine garde son propre journal Sécurité local — aucune centralisation automatique entre elles dans ce lab.

### 11. Sauvegarde de l'état système
- Fonctionnalité **Sauvegarde Windows Server** installée, avec un deuxième disque virtuel dédié (`E:`) ajouté à la VM pour servir de cible — l'état système ne peut pas être sauvegardé sur le disque qu'il protège (`C:`).
- Sauvegarde lancée avec `wbadmin start systemstatebackup -backuptarget:E:` et vérifiée avec `wbadmin get versions` (base Active Directory, SYSVOL, registre, état du système inclus).

## Problèmes rencontrés et comment ils ont été résolus

**Autorisation du serveur DHCP en échec (erreur 20070)**
Sur une itération précédente de ce lab, l'autorisation du serveur DHCP dans Active Directory échouait systématiquement après l'installation du rôle, avec un message d'erreur générique. Diagnostic mené avec `dcdiag` (contrôleur de domaine en bonne santé) puis avec l'équivalent PowerShell de l'action (`Add-DhcpServerInDC`), qui a renvoyé une erreur précise : **Access Denied**. La cause réelle : le compte utilisé pour administrer le serveur n'était pas le vrai compte intégré *Administrateur*, mais un compte local secondaire créé automatiquement par l'hyperviseur — qui n'hérite pas des droits les plus élevés (*Enterprise Admins*) accordés uniquement au vrai compte Administrateur lors de la création de la première forêt. Reconnexion avec le bon compte → problème résolu.

**Fond d'écran GPO qui ne s'affichait pas (fond noir)**
La GPO de fond d'écran s'appliquait bien (confirmé avec `gpresult /r`) et le fichier était accessible manuellement, mais l'écran restait noir. En comparant le début et la fin du champ "Nom du papier peint" dans l'éditeur de GPO (le champ, trop étroit, n'affichait que la fin du texte), le chemin contenait en fait **le nom du dossier partagé en double** (`...interne\Dossier_Partage_interne\...`), pointant vers un dossier inexistant. Correction du chemin → problème résolu.

**Lecteur réseau "orphelin" après modification d'une GPO**
En réorganisant les GPO (séparation du fond d'écran et du mappage de lecteur en deux objets distincts), le lecteur réseau restait mappé sur le client avec l'ancien chemin, même après suppression du réglage dans la GPO d'origine (confirmé avec `net use`). Cause : une Préférence de stratégie de groupe supprimée ne retire pas automatiquement ce qu'elle avait déjà appliqué sur le client, sauf si l'option **"Supprimer cet élément lorsqu'il n'est plus appliqué"** avait été cochée dès sa création. Correction ponctuelle avec `net use X: /delete` puis `gpupdate /force`.

**GPO de restriction liées au domaine entier, bloquant le serveur lui-même**
Les GPO de blocage du Panneau de configuration et de l'invite de commandes avaient été liées directement au domaine `lab.local2`, donc appliquées aussi à l'OU `Domain Controllers` — y compris au compte Administrateur en session sur le serveur. Au-delà de ça, le mauvais objet avait été visé : ces GPO ciblent la **Configuration Utilisateur**, qui s'applique selon l'OU du **compte utilisateur** connecté, pas celle de l'ordinateur — les lier à `WorkStations` (qui ne contient que des objets ordinateur) n'avait donc aucun effet. Correction : liens supprimés du domaine et déplacés vers l'OU `Accounts` (où se trouvent les comptes utilisateurs), ce qui a résolu les deux problèmes en même temps.

## Compétences démontrées

- Installation et configuration de rôles Windows Server (AD DS, DNS, DHCP, Services de fichiers)
- Création et gestion d'un domaine Active Directory (utilisateurs, groupes de sécurité)
- Gestion d'adressage IP (statique, DHCP, résolution de conflits réseau)
- Création et ciblage de stratégies de groupe (GPO), y compris le ciblage au niveau de l'élément
- Structuration de l'annuaire avec des unités d'organisation (OU)
- Diagnostic de pannes avec les outils natifs Windows (`dcdiag`, `gpresult`, PowerShell)
- Jonction de postes clients à un domaine Active Directory
- Durcissement des mots de passe avec une Fine-Grained Password Policy ciblée
- Mise en place et vérification d'une stratégie d'audit des connexions (Observateur d'événements, `auditpol`)
- Sauvegarde de l'état système d'un contrôleur de domaine (Windows Server Backup)

## Prochaines étapes

- [ ] Tester une vraie restauration à partir de la sauvegarde de l'état système (pour l'instant, seule la sauvegarde a été validée)
- [ ] Centraliser les journaux de sécurité de toutes les machines sur le serveur (transfert d'événements / Windows Event Collector)
- [ ] Étendre le blocage à PowerShell, pas seulement `cmd.exe` (AppLocker ou stratégies de restriction logicielle)
- [ ] Affiner les permissions NTFS du partage de fichiers par groupe, plutôt qu'un accès ouvert à tous

---

*Projet en cours, documenté au fur et à mesure. Dernière mise à jour : 02/11/2026.*
