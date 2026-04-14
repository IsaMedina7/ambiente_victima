from flask import Flask, request, render_template_string, jsonify
import logging
import datetime
import os
import json
import time

app = Flask(__name__)

# --- CONFIGURACIÓN DE LOGS ---
LOG_DIR = "/honeypot/logs"
os.makedirs(LOG_DIR, exist_ok=True)
logging.basicConfig(
    filename=f"{LOG_DIR}/honeypot.log",
    level=logging.INFO,
    format="%(asctime)s - %(message)s",
)

# --- VARIABLES DE ESTADO ---
stats = {
    "conn_count": 0,
    "last_event": {
        "timestamp": "--:--:--",
        "event": "WAITING",
        "ip": "---.---.---.---",
        "method": "NONE",
        "path": "NONE",
        "agent": "NONE",
    },
    "new_event_flag": False,
}


def log_request(event_type):
    global stats
    log_entry = {
        "timestamp": datetime.datetime.now().strftime("%H:%M:%S"),
        "event": event_type,
        "ip": request.remote_addr,
        "method": request.method,
        "path": request.path,
        "agent": request.headers.get("User-Agent", "Unknown"),
    }
    logging.info(json.dumps(log_entry))
    stats["last_event"] = log_entry
    stats["new_event_flag"] = True
    stats["conn_count"] += 1
    return log_entry


# --- RUTAS DE LA API ---


@app.route("/api/stats")
def get_stats():
    """Endpoint para que el JS consulte el estado sin recargar la página"""
    global stats

    # Lógica de severidad basada en conexiones

    status = "OPTIMAL"
    usage = stats["conn_count"] * 2  # Simulación de carga
    if stats["conn_count"] > 30:
        status = "WARNING"
    if stats["conn_count"] > 80:
        status = "CRITICAL"

    if usage > 100:
        usage = 100

    data = {
        "conns": stats["conn_count"],
        "usage": usage,
        "status": status,
        "new_event": stats["new_event_flag"],
        "event": stats["last_event"],
    }
    stats["new_event_flag"] = False  # Resetear bandera tras informar al JS
    return jsonify(data)


# --- RUTAS DEL HONEYPOT ---


@app.route("/", defaults={"path": ""})
@app.route("/<path:path>", methods=["GET", "POST"])
def catch_all(path):
    # Si la petición es del monitor buscando stats, no loguear como intrusión
    if path == "api/stats":
        return get_stats()

    log_request("INTRUSION_DETECTED")

    # Renderizamos la UI solo en la carga inicial
    return render_template_string(HTML_UI)


# --- INTERFAZ DINÁMICA (HTML/CSS/JS) ---

HTML_UI = """
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>GAIA | NODE MONITOR</title>
    <style>
        :root { 
            --accent: #00d4ff; 
            --glow: rgba(0, 212, 255, 0.4);
            --bg: #08080a;
            --panel-bg: rgba(20, 20, 25, 0.85);
        }
        body { 
            background: var(--bg); color: var(--accent); 
            font-family: 'Segoe UI', Tahoma, sans-serif; 
            margin: 0; overflow: hidden; display: flex; flex-direction: column; height: 100vh;

        }
        body::before {
            content: ""; position: absolute; width: 100%; height: 100%;
            background: radial-gradient(circle at center, transparent 0%, var(--bg) 90%),

                        url('https://www.transparenttextures.com/patterns/stardust.png');
            opacity: 0.2; z-index: -1;
        }
        .navbar {
            display: flex; justify-content: space-between; align-items: center;
            padding: 15px 40px; background: var(--panel-bg);
            border-bottom: 2px solid var(--accent); backdrop-filter: blur(10px);
            box-shadow: 0 5px 20px var(--glow);
        }
        .nav-label { font-size: 0.6rem; opacity: 0.5; text-transform: uppercase; letter-spacing: 2px; }
        .nav-value { font-size: 1rem; font-weight: bold; color: #fff; display: block; }

        .container { display: grid; grid-template-columns: 1fr 320px; gap: 20px; padding: 20px; flex-grow: 1; }
        
        .terminal {

            background: rgba(0, 0, 0, 0.8); border: 1px solid rgba(0, 212, 255, 0.2);
            border-radius: 8px; padding: 20px; overflow-y: auto;
        }
        .log-line { 
            margin-bottom: 10px; border-left: 2px solid var(--accent); 
            padding: 8px 15px; background: rgba(0, 212, 255, 0.05); animation: slideIn 0.3s ease;
        }
        .log-header { color: #fff; font-size: 0.8rem; font-weight: bold; }
        .log-body { font-size: 0.75rem; color: #00ffaa; font-family: monospace; }

        .sidebar {
            background: var(--panel-bg); border: 1px solid rgba(255,255,255,0.1);

            border-radius: 8px; padding: 20px; display: flex; flex-direction: column; gap: 20px;
        }
        .health-circle {
            width: 140px; height: 140px; border-radius: 50%; border: 6px double var(--accent);

            margin: 0 auto; display: flex; align-items: center; justify-content: center;
            box-shadow: 0 0 25px var(--glow); transition: 0.5s;
        }
        .info-card {
            background: rgba(255,255,255,0.03); padding: 12px; border-radius: 4px;
            border-right: 3px solid var(--accent);
        }

        .info-card strong { font-size: 0.65rem; opacity: 0.6; display: block; }

        .info-card span { font-size: 0.85rem; color: #fff; }

        @keyframes slideIn { from { opacity: 0; transform: translateX(-10px); } }
    </style>
</head>
<body>
    <div class="navbar">
        <div class="nav-item">
            <span class="nav-label">Node_ID</span>
            <span class="nav-value">GAIA-CORE-01</span>
        </div>
        <div class="nav-item">
            <span class="nav-label">Traffic_Load</span>
            <span id="load-val" class="nav-value">0 REQ</span>
        </div>
        <div class="nav-item">
            <span class="nav-label">Latency</span>
            <span id="latency-val" class="nav-value">0ms</span>
        </div>

        <div class="nav-item">
            <span class="nav-label">System_Status</span>
            <span id="status-val" class="nav-value">READY</span>
        </div>
    </div>

    <div class="container">
        <div class="terminal" id="term">
            <div class="log-line">
                <div class="log-header">BOOT_SEQUENCE [OK]</div>
                <div class="log-body">Honeypot active. Listening for unauthorized access...</div>
            </div>
        </div>

        <div class="sidebar">
            <div class="health-circle" id="circle">

                <span id="usage-pct" style="font-size: 2rem; font-weight: bold; color: #fff;">0%</span>
            </div>
            <div class="info-card">
                <strong>LAST_INTERACTION_IP</strong>
                <span id="last-ip">---.---.---.---</span>
            </div>
            <div class="info-card">
                <strong>ACTIVE_RESOURCE_PATH</strong>
                <span id="target-path">/</span>
            </div>
        </div>
    </div>


    <script>

        const term = document.getElementById('term');
        const loadVal = document.getElementById('load-val');
        const latencyVal = document.getElementById('latency-val');
        const statusVal = document.getElementById('status-val');
        const usagePct = document.getElementById('usage-pct');
        const circle = document.getElementById('circle');

        async function fetchMetrics() {
            const start = Date.now();
            try {
                const response = await fetch('/api/stats');
                const data = await response.json();
                const rtt = Date.now() - start;

                loadVal.innerText = data.conns + " REQ";
                latencyVal.innerText = rtt + "ms";
                statusVal.innerText = data.status;
                usagePct.innerText = data.usage + "%";

                if (data.new_event) {
                    const div = document.createElement('div');
                    div.className = 'log-line';
                    div.innerHTML = `
                        <div class="log-header">[${data.event.timestamp}] ${data.event.event}</div>
                        <div class="log-body">${data.event.method} ${data.event.path} FROM ${data.event.ip}</div>
                    `;
                    term.prepend(div);
                    if (term.childNodes.length > 15) term.removeChild(term.lastChild);
                    
                    document.getElementById('last-ip').innerText = data.event.ip;
                    document.getElementById('target-path').innerText = data.event.path;
                }


                // Colores dinámicos
                let color = "#00d4ff";
                if (data.usage > 40) color = "#ffcc00";
                if (data.usage > 75) color = "#ff003c";
                document.documentElement.style.setProperty('--accent', color);
                circle.style.borderColor = color;

            } catch (e) { console.error("Update failed"); }
            setTimeout(fetchMetrics, 1500);
        }
        fetchMetrics();
    </script>
</body>
</html>
"""

if __name__ == "__main__":
    # Importante: Puerto 80 suele requerir sudo en Linux
    app.run(host="0.0.0.0", port=80, debug=False)
