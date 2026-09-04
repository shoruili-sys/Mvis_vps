# ═══════════════════════════════════════════════════════════════════
# MetaTrader 5 - Dockerfile VPS (com VNC pra acesso remoto)
#
# Diferenças do Dockerfile normal:
#   - Inclui Xvfb (display virtual) + x11vnc + websockify
#   - Expõe porta 5900 (VNC) e 6080 (noVNC web)
#   - Auto-inicia VNC server
#   - Headless (sem Wayland nativo, usa Xvfb)
# ═══════════════════════════════════════════════════════════════════

FROM ubuntu:24.04

LABEL maintainer="MT5 Docker"
LABEL description="MT5 via GE-Proton 10-23 + VNC (VPS-ready)"

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

ENV USER_NAME=veris
ENV PROTON_VERSION=GE-Proton10-23
ENV PROTON_DIR=/proton
ENV STEAM_COMPAT_DATA_PATH=/home/${USER_NAME}/proton_prefix

# VNC settings
ENV DISPLAY=:0
ENV VNC_PORT=5900
ENV NOVNC_PORT=6080
ENV VNC_PASSWORD=mt5vps

# Proton settings
ENV PROTON_LOG=1
ENV PROTON_LOG_DIR=/home/${USER_NAME}/proton_logs
ENV PROTON_USE_WINED3D=1
ENV PROTON_USE_DXVK=0

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
        # VNC stack
        xvfb x11vnc \
        novac python3-websockify \
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
        fontconfig ttf-mscorefonts-installer fonts-liberation \
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
        # X11 (necessário pro Xvfb)
        libx11-6 libx11-6:i386 libxext6 libxext6:i386 \
        libxrandr2 libxrandr2:i386 libxcursor1 libxcursor1:i386 \
        libxi6 libxi6:i386 libxkbcommon0 libxkbcommon-x11-0 \
        # Userland
        bash coreutils procps nano \
    && \
    echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" | \
        debconf-set-selections && \
    apt-get install -y --no-install-recommends ttf-mscorefonts-installer && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    fc-cache -f

# ═══════════════════════════════════════════════════════════════════
# Winetricks
# ═══════════════════════════════════════════════════════════════════

RUN curl -fsSL \
    https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    -o /usr/local/bin/winetricks && \
    chmod +x /usr/local/bin/winetricks

# ═══════════════════════════════════════════════════════════════════
# GE-PROTON 10-23
# ═══════════════════════════════════════════════════════════════════

RUN mkdir -p /proton && \
    curl -fsSL \
    "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}.tar.gz" \
    -o /tmp/ge-proton.tar.gz && \
    SIZE=$(stat -c %s /tmp/ge-proton.tar.gz 2>/dev/null) && \
    if [ "${SIZE}" -lt 100000000 ]; then \
        echo "❌ Download do GE-Proton muito pequeno"; exit 1; \
    fi && \
    HEAD_BYTES=$(head -c 2 /tmp/ge-proton.tar.gz | od -An -tx1 | tr -d ' \n') && \
    if [ "${HEAD_BYTES}" != "1f8b" ]; then \
        echo "❌ Arquivo não é gzip válido"; exit 1; \
    fi && \
    tar -xzf /tmp/ge-proton.tar.gz -C /proton --strip-components=1 --warning=no-all && \
    rm -f /tmp/ge-proton.tar.gz && \
    [ -x /proton/proton ] && \
    chmod +x /proton/proton && \
    echo "✓ GE-Proton ${PROTON_VERSION} instalado"

# ═══════════════════════════════════════════════════════════════════
# Usuário e diretórios
# ═══════════════════════════════════════════════════════════════════

RUN groupadd -g 1000 ${USER_NAME} && \
    useradd -m -u 1000 -g ${USER_NAME} -s /bin/bash ${USER_NAME} && \
    usermod -aG audio,video,dialout ${USER_NAME} 2>/dev/null || true && \
    mkdir -p \
        /home/${USER_NAME}/proton_prefix \
        /home/${USER_NAME}/mt5_installer \
        /home/${USER_NAME}/proton_logs \
        /home/${USER_NAME}/config \
        /home/${USER_NAME}/logs \
        /home/${USER_NAME}/.vnc && \
    chown -R ${USER_NAME}:${USER_NAME} /home/${USER_NAME}

# ═══════════════════════════════════════════════════════════════════
# Scripts
# ═══════════════════════════════════════════════════════════════════

COPY --chown=${USER_NAME}:${USER_NAME} start.sh /start.sh
COPY --chown=${USER_NAME}:${USER_NAME} start_mt5.sh /start_mt5.sh
COPY --chown=${USER_NAME}:${USER_NAME} install_fonts.sh /home/${USER_NAME}/install_fonts.sh
COPY --chown=${USER_NAME}:${USER_NAME} install_webview2.sh /home/${USER_NAME}/install_webview2.sh
COPY --chown=${USER_NAME}:${USER_NAME} enable_webview_simple.sh /home/${USER_NAME}/enable_webview_simple.sh
COPY --chown=${USER_NAME}:${USER_NAME} force_wined3d_webview.sh /home/${USER_NAME}/force_wined3d_webview.sh
COPY --chown=${USER_NAME}:${USER_NAME} fix_dpi_resolution.sh /home/${USER_NAME}/fix_dpi_resolution.sh
COPY --chown=${USER_NAME}:${USER_NAME} force_wayland.sh /home/${USER_NAME}/force_wayland.sh
COPY --chown=${USER_NAME}:${USER_NAME} reset_all.sh /home/${USER_NAME}/reset_all.sh
COPY --chown=${USER_NAME}:${USER_NAME} redock_windows.sh /home/${USER_NAME}/redock_windows.sh
COPY --chown=${USER_NAME}:${USER_NAME} fix_swapchain.sh /home/${USER_NAME}/fix_swapchain.sh
COPY --chown=${USER_NAME}:${USER_NAME} check_webview2.sh /home/${USER_NAME}/check_webview2.sh
COPY --chown=${USER_NAME}:${USER_NAME} install_dlls_proton.sh /home/${USER_NAME}/install_dlls_proton.sh

RUN chmod +x /start.sh /home/${USER_NAME}/*.sh

# Cria link retrocompatível (caso algum script referencie o path antigo)
RUN ln -sf /home/${USER_NAME} /home/mt5user

# ═══════════════════════════════════════════════════════════════════
# VNC password
# ═══════════════════════════════════════════════════════════════════

USER ${USER_NAME}
WORKDIR /home/${USER_NAME}

# Cria senha do VNC (formato x11vnc)
RUN mkdir -p /home/${USER_NAME}/.vnc && \
    x11vnc -storepasswd "${VNC_PASSWORD}" /home/${USER_NAME}/.vnc/passwd 2>/dev/null || \
    echo "${VNC_PASSWORD}" > /home/${USER_NAME}/.vnc/passwd

# Expõe portas
EXPOSE ${VNC_PORT} ${NOVNC_PORT}

# Health check (checa se o Xvfb tá rodando)
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD pgrep Xvfb > /dev/null || exit 1

ENTRYPOINT ["/start.sh"]
