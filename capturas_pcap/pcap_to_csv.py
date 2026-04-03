# pcap_to_basic_csv.py
from scapy.all import rdpcap, IP, TCP, UDP
import csv
from collections import defaultdict
import time


def pcap_to_csv(pcap_file, output_csv):
    packets = rdpcap(pcap_file)

    # Diccionario para agrupar flujos
    flows = defaultdict(
        lambda: {
            "packets": 0,
            "bytes": 0,
            "start_time": float("inf"),
            "end_time": 0,
            "flags": set(),
        }
    )

    for pkt in packets:
        if IP in pkt:
            # Crear clave de flujo (src_ip:src_port -> dst_ip:dst_port)
            if TCP in pkt or UDP in pkt:
                proto = "TCP" if TCP in pkt else "UDP"
                src = (pkt[IP].src, pkt[proto].sport)
                dst = (pkt[IP].dst, pkt[proto].dport)
                flow_key = f"{src[0]}:{src[1]}->{dst[0]}:{dst[1]}"

                # Actualizar estadísticas
                flow = flows[flow_key]
                flow["packets"] += 1
                flow["bytes"] += len(pkt)
                flow["start_time"] = min(flow["start_time"], pkt.time)
                flow["end_time"] = max(flow["end_time"], pkt.time)

                if TCP in pkt:
                    flow["flags"].add(pkt[TCP].flags)

    # Escribir CSV
    with open(output_csv, "w", newline="") as f:
        writer = csv.writer(f)
        writer.writerow(
            [
                "Flow ID",
                "Src IP",
                "Dst IP",
                "Src Port",
                "Dst Port",
                "Protocol",
                "Duration",
                "Total Packets",
                "Total Bytes",
                "Packets/s",
                "Bytes/s",
            ]
        )

        for flow_key, stats in flows.items():
            src_ip, src_port = flow_key.split("->")[0].rsplit(":", 1)
            dst_ip, dst_port = flow_key.split("->")[1].rsplit(":", 1)

            duration = stats["end_time"] - stats["start_time"] or 0.001
            writer.writerow(
                [
                    flow_key,
                    src_ip,
                    dst_ip,
                    src_port,
                    dst_port,
                    "TCP",
                    duration,
                    stats["packets"],
                    stats["bytes"],
                    stats["packets"] / duration,
                    stats["bytes"] / duration,
                ]
            )

    print(f"✅ CSV generado: {output_csv}")
    print(f"   Flujos extraídos: {len(flows)}")


# Uso
pcap_to_csv("./goldeneye.pcap", "./goldeneye.csv")
