# ============================================================================
# hAP ax3 - STAGE 2E (ADD-ON): FULL VLAN SEGREGATION + TRUSTED MOBILE LEASE.
# Run ONCE after 02B + 02D (02C optional but recommended), from ether5,
# Safe Mode, dry-run first:
#   /import file-name=02E-full-segregation.rsc verbose=yes dry-run
#
# Policy change encoded here (John, 2026-11-21):
#   The broad 02B rule "Mobile may initiate IoT connections" is REMOVED.
#   Pod (VLAN30 Wi-Fi) and bulbs (VLAN40) are managed through their vendor
#   cloud apps, so Mobile -> IoT management was exposure with no function.
#   Result: NO client VLAN may initiate to any other client VLAN. Full stop.
#
#   NO Cast exception: the VLAN30 streaming device is a standalone Google TV
#   (own remote, own apps, streams directly) - it is NOT reliant on phone
#   casting, so there is no functional need for any Mobile -> IoT path at
#   all (John, 2026-11-21). allowCast therefore defaults to false below.
#   Section E is retained, dormant, only in case a phone-cast need ever
#   appears; the broad rule is removed regardless.
#
# VLAN30 + VLAN40 both remain necessary: they are band splits, not device
# splits - bulbs are 2.4GHz-only, the Pod is 5GHz-only (field-tested).
# ============================================================================

# ---- SECTION A. DECISIONS / VALUES ----
:global mobileMAC "REPLACE_WITH_TRUSTED_MOBILE_MAC"
:global mobileIP "10.10.20.10"
# Planned Cast address on VLAN30. Make it real with a static lease for the
# Cast receiver's ether4 MAC once known, or edit this to its reserved IP.
:global castIP "10.10.30.10"
:global allowCast false

# ---- SECTION B. FAIL FAST ----
:if ([:len [/ip firewall filter find where comment="MASTER: mobile may initiate IoT connections"]] = 0) do={ :error "Broad Mobile->IoT rule not found; either 02B differs or 02E already ran. Inspect before retrying." }
:if ([:len [/ip dhcp-server lease find where mac-address=$mobileMAC]] > 0) do={ :error "A DHCP lease for this MAC already exists. Inspect it instead of duplicating." }
:if ([:len [/ip firewall filter find where comment="02E: mobile to iot drop"]] > 0) do={ :error "02E already applied. Inspect before retrying." }

# ---- SECTION C. STATIC LEASE + TRUSTED LIST FOR JOHN'S PHONE ----
# NOTE: this binds to the MAC the phone presents ON THIS SSID. On the Pixel,
# per-network MAC randomization is persistent per SSID, so the lease holds -
# but if you ever reset network settings or switch the SSID to a fresh
# randomized MAC, the lease and the trust below silently stop matching.
# Setting this SSID to "Use device MAC" on the phone removes that risk.
/ip dhcp-server lease add address=$mobileIP mac-address=$mobileMAC server=dhcp20 comment="02E: John mobile - trusted (static)"
/ip firewall address-list add list=TRUSTED_MOBILES address=$mobileIP comment="02E: John mobile"
:log info ("02E: static lease " . $mobileIP . " bound to " . $mobileMAC . " and added to TRUSTED_MOBILES.")

# ---- SECTION D. REMOVE THE BROAD RULE + LOGGED FULL-SEGREGATION DROP ----
/ip firewall filter remove [find where comment="MASTER: mobile may initiate IoT connections"]
:local fwdDrop [:pick [/ip firewall filter find where comment="MASTER: forward default deny"] 0]
:if ([:len $fwdDrop] = 0) do={ :error "MASTER forward default-deny not found; the broad rule is already removed - inspect the forward chain manually before proceeding." }

# ---- SECTION E. OPTIONAL NARROW CAST EXCEPTION (BEFORE THE DROP) ----
# Cast control: TCP 8008 (HTTP APIs), 8009 (Cast TLS), 8443 (remote/display).
# Some apps add UDP media paths; if a specific app fails, /log will show
# XVLAN-MOBILE drops to the Cast IP - widen deliberately, per app, not by
# restoring the broad rule.
:if ($allowCast) do={
    /ip firewall filter add chain=forward connection-state=new in-interface=vlan20-mobile src-address-list=TRUSTED_MOBILES dst-address=$castIP protocol=tcp dst-port=8008,8009,8443 action=accept place-before=$fwdDrop comment="02E: trusted mobile to Cast only"
    :log info ("02E: Cast exception ON - TRUSTED_MOBILES may reach " . $castIP . " tcp 8008,8009,8443 only.")
} else={
    :log warning "02E: Cast exception OFF - hard segregation. Phones will discover nothing usable and casting will fail by design."
}

# Now the segregation drop, inserted before the default deny but AFTER the
# Cast accept above (each place-before targets the default deny, so the
# accept stays ahead of this drop in the final chain order).
/ip firewall filter add chain=forward connection-state=new in-interface=vlan20-mobile out-interface-list=IOT_VLANS action=drop log=yes log-prefix="XVLAN-MOBILE: " place-before=$fwdDrop comment="02E: mobile to iot drop"
:log info "02E: Mobile -> IoT is now dropped and logged (except any Cast exception above)."

# ---- SECTION F. TIGHTEN mDNS TO MATCH (ONLY IF 02C IS INSTALLED) ----
# Bulbs/Pod need no local discovery under full segregation, so VLAN40 comes
# off the repeater. VLAN20<->VLAN30 stays ONLY to support Cast discovery,
# and only when the Cast exception is on.
:if ($allowCast) do={
    /ip dns set mdns-repeat-ifaces=vlan20-mobile,vlan30-iot5
    :log info "02E: mDNS repeater narrowed to vlan20-mobile + vlan30-iot5 (Cast discovery only)."
} else={
    /ip dns set mdns-repeat-ifaces=""
    :log info "02E: mDNS repeater disabled (no Cast exception, no discovery needed)."
}

:set mobileMAC
:set mobileIP
:set castIP
# allowCast deliberately retained as a global for later reference.
:log warning "02E COMPLETE: test (1) phone gets 10.10.20.10, (2) Pod/bulb apps still work via cloud, (3) phone cannot ping Pod/bulbs (watch for XVLAN-MOBILE in /log), (4) casting works if the exception is on."
