# openbank-infrastructure

Lab project for a multi-site network infrastructure built on Stormshield SNS and Windows Server 2022. Simulates a banking company (Paris HQ + Nantes branch) with a remote worker scenario.

Completed as part of the AIS curriculum (RNCP Level 6) at GRETA CFA Aquitaine / OpenClassrooms, March 2026.

---

## What this covers

### Active Directory

- Forest `OPENBANK.LOC` deployed on SRV-DC-PARIS (Windows Server 2022 with GUI)
- Read-Only Domain Controller on SRV-RODC-NANTES (Server Core, configured entirely via PowerShell)
- OU structure, 10 users, 7 security groups
- Inter-site replication scheduled outside business hours

### Group Policy

- USB block for all users with a security-filtered exception for the IT group
- Login hours restriction (Mon–Fri, 06:00–20:00)
- Accessibility settings for a specific user (Narrator, Magnifier, High Contrast) — applied via registry GPP and logon script because the Personalization panel is locked on non-activated Windows
- Proxy CA certificate deployed domain-wide to avoid SSL errors

### VPN IPsec (site-to-site)

- IKEv2 with mutual X.509 authentication — internal CA (`CA-OpenBank`, RSA 4096)
- Post-Quantum Pre-Shared Key (PPK) enabled per RFC 8784
- Replaced the default PSK from the factory OVA

### VPN SSL (remote access)

- Stormshield SSL VPN client
- TOTP-based MFA (SHA1, 6 digits, 30 seconds)
- ZTNA pre-connection checks: domain machine, domain user, non-local-admin
- Split tunneling — only `10.0.1.0/24` routed through the tunnel

### Proxy and web filtering

- Transparent SSL inspection with SNS as MITM
- Captive portal for unauthenticated users (LDAP redirect)
- URL filtering profile blocking: illegal, pornography, warez, online advertising, online gaming
- Separate rules for HTTP and HTTPS authentication — required by SNS v4.8.6 (cannot combine captive portal action with URL filtering in a single rule)

---

## Network layout

```text
┌─────────────────────────┐       ┌───────────────────────┐       ┌─────────────────────────┐
│        LAN-PARIS        │       │   WAN / INTERNET      │       │       LAN-NANTES        │
│       10.0.1.0/24       │       │   192.36.253.0/24     │       │       10.0.2.0/24       │
├─────────────────────────┤       ├───────────────────────┤       ├─────────────────────────┤
│ SRV-DC-PARIS : 10.0.1.2 │       │                       │       │ SRV-RODC-NANTES:10.0.2.2│
│ ClientParis  : 10.0.1.10│       │   ClientTeleworker    │       │ ClientNantes   :10.0.2.10│
│                         │       │   IP: 192.36.253.3    │       │                         │
│ SNS-PARIS               │       │   VPN: 172.16.100.x   │       │ SNS-NANTES              │
│ LAN: 10.0.1.1           │       │                       │       │ LAN: 10.0.2.1           │
│ WAN: 192.36.253.10      ◄───────┼─────── IPsec ─────────┼───────► WAN: 192.36.253.20      │
└─────────────────────────┘       └───────────────────────┘       └─────────────────────────┘
```

---

## Repository structure

```text
scripts/               PowerShell scripts for AD, RODC deployment
configurations/        Stormshield filtering rules, VPN config notes
docs/                  IP plan, architecture notes, troubleshooting log
```

---

## Environment

- Hypervisor: Oracle VirtualBox 7
- Firewalls: Stormshield SNS OVA (EVA1 license, v4.8.6)
- OS: Windows Server 2022 Standard, Windows 10/11
- All machines run locally — no cloud, no external dependencies
