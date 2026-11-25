# Network topology

```mermaid
flowchart TB
    WAN["WAN — ISP uplink, DHCP client"]
    WG["WireGuard tunnel — Proton, US exit<br/>fail-closed: no WAN fallback rule"]

    subgraph ROUTER["MikroTik hAP ax³ — RouterOS 7.25.x"]
        BR["Bridge — VLAN filtering"]
        V10["VLAN 10 — PC<br/>wired workstation"]
        V20["VLAN 20 — Mobile<br/>5 GHz Wi-Fi + ether3"]
        V30["VLAN 30 — IoT 5 GHz<br/>Wi-Fi + ether4 wired streaming"]
        V40["VLAN 40 — IoT 2.4 GHz<br/>smart bulbs"]
        BR --- V10
        BR --- V20
        BR --- V30
        BR --- V40
    end

    V20 --> WG
    V30 --> WG
    V40 --> WG
    WG --> WAN
    V10 -->|"direct WAN egress — routes around the tunnel"| WAN

    ETH5["ether5 — out-of-band management<br/>WinBox / SSH, direct cable only"] --- ROUTER
```

Egress summary:

- **VLANs 20, 30, 40** are policy-routed through the WireGuard tunnel (`lookup-only-in-table`). If the tunnel drops, they lose internet entirely — fail-closed by design, never a silent fallback to the raw WAN.
- **VLAN 10** egresses directly to the WAN and never enters the tunnel. It is also the only segment permitted FastTrack, restricted to VLAN10↔WAN flows so policy-routed traffic cannot be FastTracked into a leak.
- **Segregation:** no client VLAN may initiate connections to any other client VLAN (not drawn pairwise — it applies to every pair). IoT devices are managed via vendor cloud apps, so no management exception exists.
- **DNS:** every client VLAN's DNS is redirected to the router resolver (DoH to Cloudflare + Quad9, AdList sinkholing); no client talks to an outside resolver directly.
- **Management:** ether5 is not part of the bridge and appears in no client accept list.
