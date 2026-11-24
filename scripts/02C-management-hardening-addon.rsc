# ============================================================================
# hAP ax3 (C53UiG+5HPaxD2HPaxD) - RouterOS 7.25.1+
# STAGE 2C (ADD-ON): management hardening + fixes from independent review.
# Run ONCE, only AFTER: 01 bootstrap -> 02A -> 02B -> reboot -> 03 validation
# all passed, and you are connected via ether5 / 10.10.99.1.
# NOT idempotent. NOT a substitute for 02A/02B. Do not run on a partial install.
#
# What this does:
#   1. mDNS repeater between Mobile + IoT VLANs (Google Cast / AirPlay discovery)
#      + the input-firewall accept mDNS needs to survive the default drop.
#   2. Drop logging on the two MASTER default-deny rules (input + forward).
#   3. WireGuard watchdog: logs a stale handshake, maintains the endpoint /32
#      pin route via the current Xfinity DHCP gateway, optional auto-restart.
#   4. OPTIONAL (off by default): send VPN-VLAN DNS to Proton's in-tunnel
#      resolver (10.2.0.1) instead of the router resolver. See Section D notes.
#   5. OPTIONAL (on by default): client isolation on the two IoT SSIDs only.
#
# Test first:  /import file-name=02C-management-hardening-addon.rsc verbose=yes dry-run
# Then run it inside a Safe Mode session (Ctrl+X) from ether5, verify, commit.
# ============================================================================

# ---- SECTION A. FILL IN / DECIDE BEFORE IMPORT ----
# Must match the endpoint IP you used in 02A (an IP, not a hostname).
:global wgEndpointIP "REPLACE_WITH_PROTON_WG_ENDPOINT_IP"
# true  = VPN VLANs (20/30/40) resolve via Proton 10.2.0.1 inside the tunnel.
#         DNS egress then matches the Proton exit, BUT those VLANs lose the
#         router's Cloudflare DoH + StevenBlack adlist filtering entirely.
# false = status quo from 02B (default): all VLANs use the router resolver;
#         queries are DoH-encrypted to Cloudflare but egress via Xfinity WAN.
:global vpnDnsViaProton false
# true = if the WG handshake is stale for 3 consecutive checks (3 minutes),
#        bounce wg-proton once. false = log a warning only, never touch it.
:global wgAutoRestart false
# true = wireless clients on the IoT SSIDs (VLAN30/40) cannot talk to each
#        other. Wired devices (e.g. a Cast receiver on ether4) are unaffected.
#        Set false if an IoT Wi-Fi device must reach another IoT Wi-Fi device.
:global enableIotIsolation true

# ---- SECTION B. FAIL FAST BEFORE MODIFYING THE ROUTER ----
:if ($wgEndpointIP = "REPLACE_WITH_PROTON_WG_ENDPOINT_IP") do={ :error "Set wgEndpointIP to the Proton endpoint IP used in 02A." }
:if ([:len [/interface wireguard find name=wg-proton]] = 0) do={ :error "wg-proton missing; run 02A first." }
:if ([:len [/interface bridge find name=br-clients]] = 0) do={ :error "br-clients missing; run 02A/02B first." }
:if ([/interface bridge get [find name=br-clients] vlan-filtering] != true) do={ :error "VLAN filtering is not on; finish 02B and reboot before 02C." }
:if ([:len [/system script find name=wg-watchdog]] > 0) do={ :error "wg-watchdog already exists; 02C is one-time only. Inspect before retrying." }
:if ([:len [/ip firewall filter find where comment="02C: mDNS repeater accept"]] > 0) do={ :error "02C mDNS rule already exists; 02C is one-time only. Inspect before retrying." }

# ---- SECTION C. mDNS REPEATER (CAST / AIRPLAY DISCOVERY ACROSS VLANS) ----
# Current RouterOS syntax is a property of /ip dns, not a separate menu.
# Repeating adds multicast traffic to every listed VLAN; PC VLAN10 is
# deliberately NOT listed (it has no discovery need into IoT in this design).
/ip dns set mdns-repeat-ifaces=vlan20-mobile,vlan30-iot5,vlan40-iot24
# The repeater hands packets to the router itself, so they hit the input
# chain. Insert the accept immediately BEFORE the MASTER default drop,
# otherwise it would be appended after the drop and never match.
:local inputDrop [:pick [/ip firewall filter find where comment="MASTER: input default deny"] 0]
:if ([:len $inputDrop] = 0) do={ :error "MASTER input default-deny rule not found; do not append an mDNS rule after an unknown drop rule." }
/ip firewall filter add chain=input in-interface-list=CLIENT_VLANS protocol=udp dst-address=224.0.0.251 dst-port=5353 action=accept place-before=$inputDrop comment="02C: mDNS repeater accept"
:log info "02C: mDNS repeater enabled on vlan20/30/40. Note: this restores discovery; test your Cast receiver end-to-end (discovery + playback)."

# ---- SECTION D. DROP LOGGING (YOUR ONLY INTRUSION SIGNAL ON THIS BOX) ----
/ip firewall filter set [find where comment="MASTER: input default deny"] log=yes log-prefix="DROP-INPUT: "
/ip firewall filter set [find where comment="MASTER: forward default deny"] log=yes log-prefix="DROP-FWD: "
:log info "02C: default-deny logging enabled. Watch /log for DROP-INPUT / DROP-FWD."

# ---- SECTION E. OPTIONAL: VPN-VLAN DNS VIA PROTON IN-TUNNEL RESOLVER ----
# Placed at the TOP of dstnat so these match before the 02B port-53 redirect
# to the router resolver. Forwarding to 10.2.0.1 exits via wg-proton, which
# the existing 'VPN clients to WG ONLY' forward rule already permits.
:if ($vpnDnsViaProton) do={
    /ip firewall nat add chain=dstnat in-interface-list=VPN_VLANS protocol=udp dst-port=53 action=dst-nat to-addresses=10.2.0.1 to-ports=53 place-before=0 comment="02C: VPN VLAN DNS to Proton resolver UDP"
    /ip firewall nat add chain=dstnat in-interface-list=VPN_VLANS protocol=tcp dst-port=53 action=dst-nat to-addresses=10.2.0.1 to-ports=53 place-before=0 comment="02C: VPN VLAN DNS to Proton resolver TCP"
    :log warning "02C: VPN-VLAN DNS now bypasses router adlist/DoH and uses Proton 10.2.0.1. PC VLAN10 is unchanged."
} else={
    :log info "02C: VPN-VLAN DNS left on router resolver (adlist + Cloudflare DoH, egress via WAN). Set vpnDnsViaProton=true and rerun only this section's rules manually to change it."
}

# ---- SECTION F. OPTIONAL: IOT WI-FI CLIENT ISOLATION ----
# 02A put every SSID on one shared datapath, so isolation cannot be toggled
# per-SSID in place. Give the two IoT BSS their own isolated datapath;
# the Mobile SSID (wifi1 / VLAN20) keeps the original non-isolated datapath.
:if ($enableIotIsolation) do={
    /interface wifi datapath add name=dp-iot-isolated client-isolation=yes comment="02C: IoT SSIDs only"
    /interface wifi set [find name=wifi1-iot5] datapath=dp-iot-isolated
    /interface wifi set [find default-name=wifi2] datapath=dp-iot-isolated
    :log info "02C: client isolation enabled on IoT SSIDs (VLAN30 5GHz, VLAN40 2.4GHz). Mobile SSID unchanged."
}

# ---- SECTION G. WIREGUARD WATCHDOG + ENDPOINT PIN (SCRIPT + SCHEDULER) ----
# Runs every minute. Two jobs:
#  (1) Endpoint pin: ensure a /32 route for the Proton endpoint via the
#      CURRENT Xfinity DHCP gateway exists in main, and repair it if the
#      gateway changes. This is the pin the ChatGPT audit recommended and
#      its own replacement omitted.
#  (2) Health: if last-handshake is older than 180s, log a warning and
#      count consecutive failures in a global. Auto-restart only if you
#      set wgAutoRestart=true above, and only once per stale episode
#      (counter resets on a fresh handshake).
:global wgFailCount 0
:global wgWatchdogSource (":local peer [:pick [/interface wireguard peers find interface=\"wg-proton\"] 0]\r\n" . \
    ":if ([:len \$peer] = 0) do={ :log error \"WG-WATCHDOG: no wg-proton peer found\"; :return }\r\n" . \
    ":local ep [/interface wireguard peers get \$peer endpoint-address]\r\n" . \
    ":local gw [/ip dhcp-client get [find interface=ether1] gateway]\r\n" . \
    ":if ([:len \$gw] > 0) do={ :local pin [/ip route find where dst-address=(\$ep . \"/32\") comment=\"02C: Proton endpoint pin\"]; :if ([:len \$pin] = 0) do={ /ip route add dst-address=(\$ep . \"/32\") gateway=\$gw comment=\"02C: Proton endpoint pin\"; :log info (\"WG-WATCHDOG: endpoint pin added \" . \$ep . \"/32 via \" . \$gw) } else={ :if ([/ip route get \$pin gateway] != \$gw) do={ /ip route set \$pin gateway=\$gw; :log warning (\"WG-WATCHDOG: endpoint pin gateway updated to \" . \$gw) } } }\r\n" . \
    ":local hs [/interface wireguard peers get \$peer last-handshake]\r\n" . \
    ":global wgFailCount\r\n" . \
    ":global wgAutoRestart\r\n" . \
    ":if ([:len \$hs] = 0) do={ :set wgFailCount (\$wgFailCount + 1); :log warning (\"WG-WATCHDOG: no handshake yet, stale count \" . \$wgFailCount) } else={ :if (\$hs > 00:03:00) do={ :set wgFailCount (\$wgFailCount + 1); :log warning (\"WG-WATCHDOG: handshake stale \" . \$hs . \", count \" . \$wgFailCount) } else={ :if (\$wgFailCount > 0) do={ :log info \"WG-WATCHDOG: handshake recovered\" }; :set wgFailCount 0 } }\r\n" . \
    ":if ((\$wgFailCount >= 3) && (\$wgAutoRestart = true)) do={ :log error \"WG-WATCHDOG: restarting wg-proton after 3 stale checks\"; /interface wireguard disable wg-proton; :delay 2s; /interface wireguard enable wg-proton; :set wgFailCount 0 }\r\n")
/system script add name=wg-watchdog policy=read,write,test source=$wgWatchdogSource comment="02C: WG health + endpoint pin"
/system scheduler add name=wg-watchdog-schedule interval=1m start-time=startup on-event=wg-watchdog policy=read,write,test comment="02C: WG health + endpoint pin"
:log warning "02C COMPLETE: verify Cast discovery from a VLAN20 phone, check /log for WG-WATCHDOG lines within 2 minutes, and confirm the backup scheduler's next-run in 03B validation."

# Forget setup globals (the uploaded .rsc still contains the endpoint IP
# until YOU delete it from WinBox -> Files; it is not a secret, but tidy up).
:set wgEndpointIP
:set vpnDnsViaProton
:set wgWatchdogSource
# Deliberately retained globals: wgFailCount, wgAutoRestart (watchdog state).
