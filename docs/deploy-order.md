# Final Deploy Order — hAP ax³ Hard-Segregation Build
Locked 2026-11-21. Policy: NO client VLAN initiates to any other client VLAN.
VLAN10 direct WAN · VLAN20/30/40 via Proton WireGuard (US exit, fail-closed) ·
management on ether5 only · manual golden backups only.

## Order (do not reorder — later stages assume earlier ones)
1. **Upgrade** to RouterOS 7.25.1+ (router + wifi-qcom + RouterBOOT), back up the factory config off-router.
2. **01-ether5-bootstrap.rsc** — from ether2 on factory defconf. Verify IP WinBox to 10.10.99.1 from ether5 before continuing. No Safe Mode for the cable move.
3. **02A-master-network-vpn.rsc** — from ether5, dry-run, then Safe Mode import. Fill in: Proton WG keys/endpoint (US server), SSIDs/passwords. Client ports and Wi-Fi stay disabled.
4. **02B-master-firewall-finalize.rsc** — from ether5, dry-run, then Safe Mode import. Fill in: admin user/password, SSH public key. (Section M weekly backup may be left in — 02D removes it.)
5. **Reboot** from ether5. Run **03-validation-only.rsc**. Verify the new admin in a second session before disabling factory `admin`.
6. **02C-management-hardening-addon.rsc** — for drop logging, the WireGuard watchdog + endpoint pin, and IoT Wi-Fi client isolation. Its mDNS repeater setting is temporary: 02E turns it off again. Fill in the Proton endpoint IP; leave `vpnDnsViaProton=false` unless you deliberately choose Proton-resolver DNS for VPN VLANs.
7. **02D-topology-tightening.rsc** — removes the weekly backup, adds logged inter-VLAN drops, sets VLAN30 split horizon (Google TV on ether4 vs Pod on Wi-Fi), enables ether5 lease logging.
8. **02E-full-segregation.rsc** — LAST. Removes the broad Mobile→IoT rule, adds the logged Mobile→IoT drop, binds John's phone (REPLACE_WITH_TRUSTED_MOBILE_MAC) to 10.10.20.10, disables the mDNS repeater. `allowCast=false` — do not change it; the Google TV is standalone.
9. **03B-validation-checks.rsc** — expect all PASS. Then client-side tests: per-VLAN DHCP/DNS, exit-IP check on VLAN20/30/40 (Proton US), cross-VLAN ping matrix (all must fail), WG-down fail-closed test (disable wg-proton from ether5: 20/30/40 lose Internet, VLAN10 unaffected, re-enable).
10. **Golden backup** — from ether5: encrypted `/system backup save` + redacted `/export`, copy both off-router, record RouterOS version + date with them. Repeat after every future config change. Delete the uploaded .rsc files (they contain secrets) from WinBox → Files.

## Final firewall posture (what "done" looks like)
- Input: only ether5 administers (SSH/WinBox, 10.10.99.0/24); client VLANs get DNS/DHCP only; everything else dropped and logged.
- Forward: VLAN10 → WAN only. VLAN20/30/40 → wg-proton only. Every inter-VLAN initiation dropped and logged (XVLAN-* prefixes). Established return traffic allowed.
- Intra-VLAN: VLAN30 wired/wireless split by bridge horizon; IoT SSIDs client-isolated (02C).
- If a streaming app on the Google TV ever reports VPN use: swap the Proton US server config first — do not loosen segregation for it.
