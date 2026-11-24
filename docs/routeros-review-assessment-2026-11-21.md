# ChatGPT RouterOS 7.25.1 Review + Replacement Scripts — Independent Assessment
Date: 2026-11-21 · Device: MikroTik hAP ax³ (C53UiG+5HPaxD2HPaxD, ARM64) · Target: RouterOS 7.25.1

## Verdict
- ChatGPT's audit of the Gemini script: **substantially correct** — 6 of 7 headline findings hold up. Finding #2 (Quad9) is overstated for this hardware (see below).
- ChatGPT's replacement bundle (01 / 02A / 02B / 03 + README): **good, deployable-with-fixes** — materially better than the Gemini original. It correctly fixes the ether5 lockout, fail-open VPN, FastTrack/policy-routing conflict, obsolete SSH property, unencrypted backup, and destructive `[find]` removals. Staged 2A/2B install, fail-fast preflight, disabled client ports until firewall is live, and VLAN filtering enabled last are the right structure.
- **Do not deploy as-is without the fixes in §3.** None are architecture changes; all are patch-level.

## 1. Where the ChatGPT audit was right
1. ether5 under defconf: removing it from the bridge without first adding LAN-list membership / explicit input accepts would drop DHCP + IP WinBox/SSH. Replacement bootstrap fixes this correctly (LAN member + place-before=0 temp accepts + forward drop, temp rules removed in 2B).
2. SSH: `always-allow-password-login` is obsolete in 7.25; replacement uses `password-authentication=yes-if-no-key` — correct.
3. FastTrack + policy routing: original excluded only traffic currently on wg-proton, so WAN-fallback connections could get FastTracked in main and stay leaked. Replacement restricts FastTrack to VLAN10 PC <-> WAN only — correct and simpler than the audit's own suggested pattern.
4. VPN fallback: original `action=lookup` + VPN->WAN accept = leak path, not a kill switch. Replacement uses `lookup-only-in-table` and has no VPN->WAN forward rule — true fail-closed.
5. Backups: original `dont-encrypt=yes` on a backup containing keys/passwords was the worst single flaw. Replacement: AES-SHA256 encrypted binary + redacted export.
6. Destructive transitions: original `/ip firewall filter remove [find]` and `/interface list member remove [find]` replaced with comment-scoped disable/remove after the new firewall exists.
7. 7.25.1 over 7.25: correct — 7.25.1 (2026-11-02) fixes the dhcpv4-client packet-length bug introduced in 7.25, and the WAN here is a DHCP client.

## 2. Where the ChatGPT audit was wrong / overstated
- **Quad9 DoH:** The audit cited MikroTik's older help page listing Quad9 as incompatible (HTTP/2). Current MikroTik manual: ARM64 and x86 use HTTP/2 for DoH, and Quad9 works only on ARM64/x86. The hAP ax³ is ARM64, and DoH HTTP/2 support landed in 7.23 — forum reports on 7.23+ ARM64 show Quad9 working (with some log noise). So on *this* router, Quad9 DoH is not a verified-bad choice. The replacement's README actually corrects this, then still picks Cloudflare for predictability — a defensible preference, but present it as preference, not necessity. If Quad9's malware filtering matters to you, it remains a viable option to test.

## 3. Fixes to apply to the replacement bundle before deployment
1. **Cast / mDNS will break.** No `mdns-repeat-ifaces` is set and the input chain has no UDP 5353 accept. Your dedicated Google Cast device sits on IoT; VLAN20 phones will not discover it (README admits discovery is not enabled, but for your setup this is a regression, not a footnote). Current RouterOS syntax:
   `/ip dns set mdns-repeat-ifaces=vlan20-mobile,vlan30-iot5,vlan40-iot24`
   plus an input accept for udp/5353 from those VLANs before the default drop. Note mDNS repeater alone restores discovery; some Cast flows also need SSDP/DIAL help — test with your Cast device specifically.
2. **DNS-over-Proton leak (disclosed, but decide consciously).** All client port-53 is redirected to the router resolver, whose DoH egress is via Xfinity WAN in main — not inside Proton. VPN VLANs get a Proton *web* exit IP but Cloudflare/Xfinity-visible DNS. Options: (a) accept it (documented tradeoff), or (b) for VPN VLANs only, dstnat DNS to Proton's in-tunnel resolver (10.2.0.1) instead of redirecting to the router, losing adlist filtering for those VLANs, or (c) a separate resolver (container/AdGuard) whose upstream is policy-routed. RouterOS's single native resolver cannot split upstream per-VLAN.
3. **No WireGuard endpoint pinning / no tunnel health monitoring.** The audit recommended a /32 endpoint route via WAN; the replacement omits it. Router-originated handshake traffic uses main today, so it works — but add a Netwatch/script watchdog: if `last-handshake` > 180s, log + alert (and optionally restart the interface). Right now a dead tunnel is silent except clients losing Internet (fail-closed working as designed, with no signal to you).
4. **No drop logging / visibility.** Final input/forward drops are silent. Add `log=yes log-prefix` on the two default drops (or a separate log-only rule) — cheap, and it's your only IDS on this box.
5. **Scheduler anchor is stale.** Backup scheduler `start-date=2026-11-15` — it does roll forward by 7d intervals (next: Sun 2026-11-22 03:00), but verify the first run fires and produces both files, per README. Don't assume.
6. **Copy-paste drift in 02A header** — its comment block still tells you to import `02-master-configuration.rsc`. Harmless, fix to avoid running the combined master by mistake. Prefer the staged files; treat the combined master as reference only (also: a single Safe Mode session over ~120 changes would exceed the 100-action rollback limit the README warns about).
7. **IoT Wi-Fi posture:** `client-isolation=no` on the shared datapath and WPA2-only on the 2.4 GHz IoT SSID. WPA2-only is a reasonable compatibility call; client isolation on IoT SSIDs is worth enabling if your IoT devices don't need peer-to-peer (Cast receiver is the usual exception — test).
8. **Validation script is print-only.** 03 produces output for eyeballing, no pass/fail. Pair it with a client-side test matrix (per-VLAN: DHCP, DNS, exit IP, cross-VLAN ping matrix, WG-down fail-closed test) — your existing PowerShell backup/test tooling is the natural home for this.

## 4. New recommendations — better network management (not in either script)
- **Off-router, versioned config management:** pull the encrypted backup + redacted export to your PC on schedule (you already have PowerShell backup automation), commit redacted exports to private git. The on-router weekly backup with its password embedded in the script source (acknowledged in README) should be a fallback, not the system of record. Test a restore once.
- **Update management:** scheduled `/system package update check` that *notifies only* — no auto-install on a box whose changelog you read (7.25 -> 7.25.1 is exactly why). Include RouterBOOT firmware in the check.
- **Alerting:** log-action to email/Telegram for: WG handshake stale, DHCP pool >80%, failed logins, backup failure. RouterOS can do all of this natively; neither script sets any of it up.
- **SQM on WAN:** a simple CAKE/FQ-CoDel queue on ether1 upload/download (~90-95% of measured Xfinity rates) — biggest single quality-of-life win for a shared home uplink, absent from both designs.
- **Static DHCP leases + local DNS names** for infrastructure (Cast, NAS-when-built, printer) so firewall exceptions and troubleshooting use names/stable IPs, not pool addresses.
- **Guest network:** currently no place to put a visitor that isn't your PC VLAN or a VPN/IoT VLAN. A VLAN 50, WAN-only, client-isolated, no Proton, is a cheap add while you're rebuilding anyway.

## Bottom line
Trust the audit's direction, deploy the replacement's architecture — after the §3 patches, with mDNS/Cast and the DNS-egress decision made explicitly rather than by default.
