# Architecture and design decisions

Hardware: MikroTik hAP ax³ (C53UiG+5HPaxD2HPaxD, ARM64), RouterOS 7.25.x. WAN is a DHCP client connection.

## Segmentation model

Four client VLANs hang off a single bridge with VLAN filtering enabled last in the build (enabling it earlier, before the firewall exists, is how you lock yourself out — the staged scripts exist for exactly this reason).

- **VLAN 10 — PC.** Wired workstation segment. Direct WAN egress, no VPN. It is the only segment permitted FastTrack, and FastTrack is restricted to VLAN10↔WAN flows so policy-routed traffic can never be FastTracked into a leak.
- **VLAN 20 — Mobile.** Phones on 5 GHz Wi-Fi, plus ether3. Guests use this segment too. Egress via WireGuard.
- **VLAN 30 — IoT 5 GHz.** 5 GHz-only devices (sleep Pod), plus the wired streaming device on ether4.
- **VLAN 40 — IoT 2.4 GHz.** 2.4 GHz-only devices (smart bulbs).

VLANs 20/30/40 are policy-routed through a Proton WireGuard tunnel (US exit, chosen for throughput). The tunnel is **fail-closed**: routing uses `lookup-only-in-table` and there is deliberately no VPN→WAN forward rule. The earlier design this replaced used `action=lookup` with a WAN accept — a leak path, not a kill switch.

**Full segregation:** the forward chain drops any client-VLAN-initiated traffic toward any other client VLAN. An earlier iteration allowed Mobile→IoT for device management; it was removed (02E) because every IoT device here is managed through its vendor's cloud app — the exception carried exposure and no function. The streaming device is standalone (its own apps and remote), so no casting exception exists either, and the mDNS repeater is disabled: cross-VLAN discovery has no remaining purpose.

## Management plane

ether5 is removed from the bridge and is the only management path: WinBox/SSH over a direct cable from a laptop/PC. No client VLAN is in the router's input accept list. SSH uses strong crypto and `password-authentication=yes-if-no-key`. The factory admin is replaced by a named administrator.

## DNS

All client DNS is redirected to the router resolver. Upstream is DNS-over-HTTPS to Cloudflare and Quad9 (both verified working on this ARM64 build — RouterOS on ARM64/x86 uses HTTP/2 for DoH, which is what Quad9 requires). RouterOS AdList provides sinkholing. DoH bootstrap names are pinned with static A records so the resolver can reach its own upstreams before DNS exists.

**Known tradeoff:** the resolver's DoH egress leaves via the WAN in the main routing table, not inside the tunnel. VPN VLANs get a VPN web exit but WAN-visible DNS egress (to Cloudflare/Quad9 over TLS). Splitting upstream resolvers per-VLAN is not something RouterOS's single native resolver can do; the alternatives (in-tunnel resolver per VLAN, losing AdList; or a separate container resolver) were considered and deferred consciously.

## Backups

Manual, encrypted "golden" backups only. The original design's weekly on-router scheduler (with the backup passphrase embedded in the scheduled script's source) and the later PowerShell automation were both retired: an automated job with an embedded secret is a liability, and an untested backup is a rumor. Current practice: deliberate manual backup after any change, encrypted (AES-SHA256), copied off-router.

## Deliberate omissions / future work

- **No guest VLAN.** Guests share VLAN 20 today. A WAN-only, client-isolated VLAN 50 is the planned fix.
- **Drop logging** was added for the default input/forward drops in 02C — silent drops are invisible failures.
- **WireGuard watchdog:** 02C logs stale handshakes and pins the endpoint /32 via WAN. A dead tunnel is otherwise silent by design (fail-closed working as intended, with no signal).
- **IPv6 disabled** until the segmentation model is deliberately extended to it.
- **NAS / self-hosted services** are planned; they will get their own segment rather than being folded into an existing VLAN.
