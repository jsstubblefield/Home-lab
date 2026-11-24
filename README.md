# Home Lab — MikroTik RouterOS Network

A segmented, security-first home network built on a MikroTik hAP ax³ running RouterOS 7.25.x. Four client VLANs with full inter-VLAN segregation, fail-closed VPN routing for IoT/mobile segments, DNS-over-HTTPS with ad/malware sinkholing, and a dedicated out-of-band management port.

This repository holds the sanitized build scripts, design documentation, and topology diagram for the lab. All secrets in the scripts are placeholders (`REPLACE_WITH_...`) — the scripts refuse to run until real values are filled in locally.

## Design principles

- **Segregation by default.** No client VLAN may initiate connections to any other VLAN. IoT devices are managed through vendor cloud apps, so no LAN-to-IoT management exception exists.
- **Fail closed.** VPN-routed VLANs use `lookup-only-in-table` policy routing with no WAN fallback rule. If the WireGuard tunnel dies, those clients lose internet — they never leak onto the raw WAN.
- **Management is out-of-band.** Router administration is possible only from ether5 (direct cable, WinBox/SSH). No client VLAN has router access.
- **Band splits are not trust splits.** VLAN30 (5 GHz) and VLAN40 (2.4 GHz) both exist because real devices are band-locked (smart bulbs are 2.4 GHz-only; the sleep Pod is 5 GHz-only), not because they need different policy.

## Network at a glance

| Segment | Interface / SSID | Routing | Notes |
|---|---|---|---|
| VLAN 10 — PC | Wired + trusted PC | Direct WAN | Total inter-VLAN isolation; the only segment allowed FastTrack |
| VLAN 20 — Mobile | 5 GHz Wi-Fi + ether3 | WireGuard (Proton, US exit) | Guests use this segment |
| VLAN 30 — IoT 5 GHz | 5 GHz Wi-Fi + ether4 (wired Cast) | WireGuard | Streaming device is standalone; no casting from phones |
| VLAN 40 — IoT 2.4 GHz | 2.4 GHz Wi-Fi | WireGuard | Smart bulbs only |
| Management | ether5 only | — | Out-of-band; laptop/PC Ethernet for WinBox |

DNS for all segments is forced to the router resolver: Cloudflare and Quad9 over HTTPS (DoH), with RouterOS AdList sinkholing. IPv6 is disabled. Backups are manual, encrypted "golden" backups only — the earlier weekly scheduler and PowerShell automation were retired deliberately.

## Repository layout

- `scripts/` — the staged RouterOS build, in deploy order:
  - `01-ether5-bootstrap.rsc` — carves ether5 out of the default config safely for out-of-band management
  - `02A-master-network-vpn.rsc` — interfaces, VLANs, DHCP, Wi-Fi, WireGuard, DNS
  - `02B-master-firewall-finalize.rsc` — firewall, hardening, admin user, encrypted backup job
  - `02-master-configuration.rsc` — the combined single-file version (reference only; prefer the staged files)
  - `02C-management-hardening-addon.rsc` — mDNS accept, WireGuard watchdog, drop logging
  - `02D-topology-tightening.rsc` — topology/policy tightening pass
  - `02E-full-segregation.rsc` — removes the last Mobile→IoT exception; full segregation (deploy last)
  - `03-validation-only.rsc`, `03B-validation-checks.rsc` — read-only validation output
- `docs/architecture.md` — design decisions and tradeoffs
- `docs/deploy-order.md` — the exact deployment sequence and why it is ordered that way
- `docs/routeros-review-assessment-2026-11-21.md` — an independent review of an earlier generated build, with corrections (several findings were adopted; one — Quad9 DoH compatibility — was refuted for this ARM64 hardware)
- `diagrams/network-diagram.md` — topology diagram (Mermaid)

## Sanitization

Published copies have had the following stripped or replaced with placeholders: all passwords and passphrases, WireGuard private/peer keys, the VPN endpoint address, and the trusted phone's MAC address (bound to a static lease in the live config). SSIDs in the scripts are generic by design. Private (RFC 1918) addressing is shown as-is — it is not routable or identifying, and it is the substance of the design.

## Status

Live and in production. Known deliberate tradeoffs are documented in `docs/architecture.md` (DNS egress path, no guest VLAN yet, silent drops vs. logging).
