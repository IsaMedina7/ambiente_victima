FROM python:3.8.5
WORKDIR /app

# Parche para repositorios antiguos de Debian + Instalación de tcpdump
RUN sed -i 's/deb.debian.org/archive.debian.org/g' /etc/apt/sources.list && \
  sed -i 's|security.debian.org/debian-security|archive.debian.org/debian-security|g' /etc/apt/sources.list && \
  sed -i '/stretch-updates/d' /etc/apt/sources.list && \
  apt-get update && apt-get install -y tcpdump libpcap-dev


# Instalación de librerías de Python
COPY flask_app_tesis/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copia del resto del código
COPY flask_app_tesis/ .
CMD ["python", "app.py"]
