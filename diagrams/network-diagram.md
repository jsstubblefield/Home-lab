# Network topology

```mermaid
flowchart TB
    WAN["WAN — DHCP client uplink"]
    WG["WireGuard tunnel — Proton, US exit<br/>fail-closed, no WAN fallback"]

    subgraph ROUTER["MikroTik hAP ax³ — RouterOS 7.25.x"]
        BR["Bridge — VLAN filtering"]
        RES["DNS resolver — DoH to Cloudflare + Quad9<br/>AdList sinkholing"]
    end

    WAN --> ROUTER
    ROUTER --> WG

    BR --> V10["VLAN 10 — PC<br/>wired workstation<br/>direct WAN egress"]
    BR --> V20["VLAN 20 — Mobile<br/>5 GHz Wi-Fi + ether3<br/>via WireGuard"]
    BR --> V30["VLAN 30 — IoT 5 GHz<br/>Wi-Fi + ether4 wired streaming<br/>via WireGuard"]
    BR --> V40["VLAN 40 — IoT 2.4 GHz<br/>smart bulbs<br/>via WireGuard"]
    ETH5["ether5 — out-of-band management<br/>WinBox / SSH, direct cable only"] --- ROUTER

    V10 -. "no initiation<br/>to any VLAN" .-x V20
    V20 -. "full segregation" .-x V30
    V30 -. "full segregation" .-x V40
```

Notes:

- Every client VLAN's DNS is redirected to the router resolver; no client talks to an outside resolver directly.
- VLANs 20/30/40 lose internet entirely if the tunnel drops — that is the intended fail-closed behavior, not an outage mode.
- ether5 is not part of the bridge and appears in no client accept list.
