# ═══════════════════════════════════════════════════════════════════
# MetaTrader 5 - Dockerfile VPS (com VNC pra acesso remoto)
# Usa user padrão do sistema (não fixa em veris)
# ═══════════════════════════════════════════════════════════════════

FROM ubuntu:24.04

LABEL maintainer="MT5 Docker"
LABEL description="MT5 via GE-Proton 10-23 + VNC (VPS-ready)"

# ═══════════════════════════════════════════════════════════════════
# ARG - pode ser sobrescrito no build (--build-arg)
# ═══════════════════════════════════════════════════════════════════

ARG APP_USER=appuser
ARG APP_UID=1000
ARG APP_GID=1000

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

ENV PROTON_VERSION=GE-Proton10-23
ENV PROTON_DIR=/proton
ENV STEAM_COMPAT_CLIENT_INSTALL_PATH=/proton
ENV STEAM_COMPAT_DATA_PATH=/home/${APP_USER}/proton_prefix

# VNC
ENV DISPLAY=:0
ENV VNC_PORT=5900
ENV NOVNC_PORT=6080
ENV VNC_RESOLUTION=1920x1080x24

# Proton settings
ENV PROTON_LOG=1
ENV PROTON_LOG_DIR=/home/${APP_USER}/proton_logs
ENV PROTON_USE_WINED3D=1
ENV PROTON_USE_DXVK=0
ENV PROTON_NO_D3D11=0
ENV WINE_D3D_CONFIG=renderer=gl
ENV WINEDLLOVERRIDES=d3d11=b,dxgi=b,d3d10core=b,d3d9=b

ENV APP_USER=${APP_USER}
ENV APP_HOME=/home/${APP_USER}

# ═══════════════════════════════════════════════════════════════════
# PACOTES
# ═══════════════════════════════════════════════════════════════════

RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        # Básicos
        wget curl ca-certificates gnupg2 \
        apt-transport-https software-properties-common \
        tar xz-utils unzip p7zip-full cabextract \
        sudo \
        # VNC stack
        xvfb x11vnc \
        netcat-openbsd \
        # Wine
        libasound2t64 libpulse0 libpulse0:i386 \
        libjack-jackd2-0 libjack-jackd2-0:i386 \
        # OpenGL/Vulkan
        libgl1 libgl1:i386 libglx0 libglx0:i386 \
        libegl1 libegl1:i386 libgbm1 libgbm1:i386 \
        libdrm-intel1 libdrm-intel1:i386 \
        libdrm2 libdrm2:i386 libdrm-common \
        libva2 libva2:i386 libva-drm2 libva-drm2:i386 \
        libva-x11-2 libva-x11-2:i386 \
        libvulkan1 libvulkan1:i386 \
        mesa-vulkan-drivers mesa-vulkan-drivers:i386 \
        mesa-utils vainfo vulkan-tools \
        # Fontes
        fontconfig fonts-liberation \
        # Bibliotecas Wine
        libfreetype6 libfreetype6:i386 \
        libfontconfig1 libfontconfig1:i386 \
        libgnutls30t64 libgnutls30t64:i386 \
        libgssapi-krb5-2 libgssapi-krb5-2:i386 \
        libk5crypto3 libk5crypto3:i386 \
        libkrb5-3 libkrb5-3:i386 \
        libpng16-16t64 libpng16-16t64:i386 \
        libxml2 libxml2:i386 libxslt1.1 libxslt1.1:i386 \
        libudev1 libudev1:i386 \
        libsdl2-2.0-0 libsdl2-2.0-0:i386 \
        libdbus-1-3 libdbus-1-3:i386 \
        # X11
        libx11-6 libx11-6:i386 libxext6 libxext6:i386 \
        libxrandr2 libxrandr2:i386 libxcursor1 libxcursor1:i386 \
        libxi6 libxi6:i386 libxkbcommon0 libxkbcommon-x11-0 \
        # Userland
        bash coreutils procps nano \
        # noVNC precisa de websockify (Python)
        python3 python3-pip python3-websockify \
        # noVNC web client
        novnc \
    && \
    # Aceita EULA das fontes Microsoft
    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | \
        debconf-set-selections && \
    apt-get install -y --no-install-recommends ttf-mscorefonts-installer && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    fc-cache -f && \
    echo "✓ Pacotes instalados"

# ═══════════════════════════════════════════════════════════════════
# Winetricks
# ═══════════════════════════════════════════════════════════════════

RUN curl -fsSL \
    https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    -o /usr/local/bin/winetricks && \
    chmod +x /usr/local/bin/winetricks && \
    echo "✓ Winetricks instalado"

# ═══════════════════════════════════════════════════════════════════
# GE-PROTON 10-23
# ═══════════════════════════════════════════════════════════════════

RUN mkdir -p /proton && \
    curl -fsSL \
    "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}.tar.gz" \
    -o /tmp/ge-proton.tar.gz && \
    SIZE=$(stat -c %s /tmp/ge-proton.tar.gz 2>/dev/null) && \
    if [ "${SIZE}" -lt 100000000 ]; then \
        echo "❌ Download do GE-Proton muito pequeno (${SIZE} bytes)"; exit 1; \
    fi && \
    HEAD_BYTES=$(head -c 2 /tmp/ge-proton.tar.gz | od -An -tx1 | tr -d ' \n') && \
    if [ "${HEAD_BYTES}" != "1f8b" ]; then \
        echo "❌ Arquivo não é gzip válido"; exit 1; \
    fi && \
    tar -xzf /tmp/ge-proton.tar.gz -C /proton --strip-components=1 --warning=no-all && \
    rm -f /tmp/ge-proton.tar.gz && \
    [ -x /proton/proton ] || (echo "❌ /proton/proton não encontrado"; exit 1) && \
    chmod +x /proton/proton && \
    echo "✓ GE-Proton ${PROTON_VERSION} instalado"

# ═══════════════════════════════════════════════════════════════════
# Usuário e diretórios
# ═══════════════════════════════════════════════════════════════════

RUN set -eux; \
    # Cria grupo se não existir
    if ! getent group ${APP_GID} > /dev/null; then \
        groupadd -g ${APP_GID} ${APP_USER}; \
    fi; \
    # Cria usuário se não existir
    if ! id -u ${APP_USER} > /dev/null 2>&1; then \
        useradd -m \
            -u ${APP_UID} \
            -g ${APP_GID} \
            -s /bin/bash \
            ${APP_USER}; \
    fi; \
    # Adiciona aos grupos necessários
    usermod -aG audio,video,dialout,sudo ${APP_USER} 2>/dev/null || true; \
    # Permite sudo sem senha (pra usar dentro do container)
    echo "${APP_USER} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/${APP_USER}; \
    # Cria diretórios
    mkdir -p \
        ${APP_HOME}/proton_prefix \
        ${APP_HOME}/mt5_installer \
        ${APP_HOME}/proton_logs \
        ${APP_HOME}/config \
        ${APP_HOME}/logs \
        ${APP_HOME}/.vnc; \
    chown -R ${APP_USER}:${APP_USER} ${APP_HOME}; \
    echo "✓ User ${APP_USER} (UID ${APP_UID}) criado"

# ═══════════════════════════════════════════════════════════════════
# Scripts - copia cada um individualmente
# ═══════════════════════════════════════════════════════════════════

# Copia apenas os scripts essenciais
COPY --chown=${APP_USER}:${APP_USER} start_vps.sh /start.sh
COPY --chown=${APP_USER}:${APP_USER} start_mt5.sh /start_mt5.sh

# Torna executáveis
RUN chmod +x /start.sh /start_mt5.sh && \
    echo "✓ Scripts copiados"

# ═══════════════════════════════════════════════════════════════════
# noVNC web files
# ═══════════════════════════════════════════════════════════════════

# Cria link pro noVNC se não tiver
RUN if [ ! -d /usr/share/novnc ]; then \
        echo "⚠  noVNC não encontrado em /usr/share/novnc"; \
        mkdir -p /usr/share/novnc; \
    fi; \
    echo "✓ noVNC disponível"

# ═══════════════════════════════════════════════════════════════════
# Final
# ═══════════════════════════════════════════════════════════════════

USER ${APP_USER}
WORKDIR ${APP_HOME}

# Porta padrão do VNC
EXPOSE ${VNC_PORT} ${NOVNC_PORT}

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD pgrep Xvfb > /dev/null || exit 1

ENTRYPOINT ["/start.sh"]
