# hAP ax3: PASS/FAIL validation for the 02C add-on (companion to 03).
# Read-only except for :put output. Run from ether5 after 02C + 2 minutes:
#   /import file-name=03B-validation-checks.rsc verbose=yes
# A FAIL tells you which 02C section to inspect; it changes nothing.

:put "=== 02C VALIDATION ==="

# 1. VLAN filtering actually on
:if ([/interface bridge get [find name=br-clients] vlan-filtering] = true) do={ :put "PASS: br-clients vlan-filtering = yes" } else={ :put "FAIL: br-clients vlan-filtering is off (finish 02B + reboot)" }

# 2. mDNS repeater interfaces
:local mdns [:tostr [/ip dns get mdns-repeat-ifaces]]
:if ([:find $mdns "vlan20-mobile"] >= 0) do={ :put ("PASS: mDNS repeater ifaces = " . $mdns) } else={ :put ("FAIL: mDNS repeater not set for vlan20-mobile (current: " . $mdns . ")") }

# 3. mDNS input accept exists and sits before the default drop
:if ([:len [/ip firewall filter find where comment="02C: mDNS repeater accept"]] > 0) do={ :put "PASS: mDNS input accept rule present" } else={ :put "FAIL: mDNS input accept rule missing" }

# 4. Drop logging on both default-deny rules
:if (([/ip firewall filter get [:pick [find where comment="MASTER: input default deny"] 0] log] = true) && ([/ip firewall filter get [:pick [find where comment="MASTER: forward default deny"] 0] log] = true)) do={ :put "PASS: default-deny logging on (input + forward)" } else={ :put "FAIL: default-deny logging off on at least one chain" }

# 5. WireGuard handshake freshness
:local hs [/interface wireguard peers get [:pick [find interface=wg-proton] 0] last-handshake]
:if ([:len $hs] = 0) do={ :put "FAIL: WireGuard has never handshaked - check endpoint/keys" } else={ :if ($hs < 00:05:00) do={ :put ("PASS: WireGuard handshake age " . $hs) } else={ :put ("FAIL: WireGuard handshake stale: " . $hs) } }

# 6. Endpoint pin route exists
:if ([:len [/ip route find where comment="02C: Proton endpoint pin"]] > 0) do={ :put "PASS: Proton endpoint /32 pin route present" } else={ :put "FAIL: endpoint pin route missing (watchdog may need a minute, or DHCP gateway was empty)" }

# 7. Watchdog script + scheduler present and running
:if (([:len [/system script find name=wg-watchdog]] > 0) && ([:len [/system scheduler find name=wg-watchdog-schedule]] > 0)) do={ :put "PASS: wg-watchdog script + scheduler present" } else={ :put "FAIL: wg-watchdog script or scheduler missing" }

# 8. DNS: DoH configured with certificate verification
:if (([:len [/ip dns get use-doh-server]] > 0) && ([/ip dns get verify-doh-cert] = true)) do={ :put ("PASS: DoH = " . [/ip dns get use-doh-server] . " with cert verification") } else={ :put "FAIL: DoH unset or cert verification off" }

# 9. Adlist actually loaded (a configured URL with 0 names is a silent failure)
:local adCount 0
:foreach a in=[/ip dns adlist find] do={ :set adCount ($adCount + [/ip dns adlist get $a name-count]) }
:if ($adCount > 0) do={ :put ("PASS: adlist names loaded = " . $adCount) } else={ :put "FAIL: adlist loaded 0 names - check NTP, DNS, and /log topic dns" }

# 10. Weekly backup must be ABSENT (John switched to manual golden backups, 2026-11-21)
:if ([:len [/system scheduler find where name="weekly-encrypted-backup-schedule"]] = 0) do={ :put "PASS: no weekly backup scheduler (manual golden backups by design)" } else={ :put "FAIL: weekly backup scheduler still present - run 02D Section A or remove it" }
:put "INFO: golden backup reminder - after any config change, from ether5: encrypted /system backup save + redacted /export, copy BOTH off-router, note the RouterOS version with them"

# 11. Management surface is still ether5-only
:put ("INFO: ssh address = " . [/ip service get ssh address] . " / winbox address = " . [/ip service get winbox address] . " (both should read 10.10.99.0/24)")

:put "=== END 02C VALIDATION (client-side tests still required: per-VLAN DHCP/DNS, exit-IP check on 20/30/40, cross-VLAN ping matrix, WG-down fail-closed test) ==="
