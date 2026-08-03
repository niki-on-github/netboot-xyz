FROM alpine:latest

# Pinned to 3.0.2: the 2.x bootloader signing certificates expired on
# 2026-04-30, so all 2.x bootloaders fail imgverify with "No usable
# certificates" (https://ipxe.org/err/0216eb). v3 certs are valid to 2035.
# v3 (iPXE 2.0.0+) still has a "Network unreachable" bug behind proxy DHCP
# (https://github.com/netbootxyz/netboot.xyz/issues/1793) which is worked
# around via /tftpboot/local-vars.ipxe below.
ARG NETBOOT_XYZ_VERSION=3.0.2

RUN mkdir -p /tftpboot/efi64
RUN chmod -R 555 /tftpboot
RUN echo "$NETBOOT_XYZ_VERSION" > /tftpboot/VERSION.txt

RUN apk add --no-cache --update dnsmasq curl

RUN mv /etc/dnsmasq.conf /etc/dnsmasq.conf.bak

# Use the "-legacy" bootloaders: iPXE 2.0.0+ compiles USB NIC drivers in by
# default, which breaks BIOS SMM USB-legacy keyboard emulation (netboot.xyz
# issues #1769/#1780). The -legacy variants exclude USB NIC drivers and are
# matched by the v3 embedded script.
RUN cd /tftpboot \
    && curl -fSL -o netboot.xyz-legacy.kpxe "https://github.com/netbootxyz/netboot.xyz/releases/download/${NETBOOT_XYZ_VERSION}/netboot.xyz-legacy.kpxe"

RUN cd /tftpboot/efi64 \
    && curl -fSL -o netboot.xyz-legacy.efi "https://github.com/netbootxyz/netboot.xyz/releases/download/${NETBOOT_XYZ_VERSION}/netboot.xyz-legacy.efi"

# Ship the release autoexec.ipxe to both TFTP locations so iPXE's optional
# autoexec.ipxe probe does not log "not found".
RUN curl -fSL -o /tmp/autoexec.ipxe "https://github.com/netbootxyz/netboot.xyz/releases/download/${NETBOOT_XYZ_VERSION}/autoexec.ipxe" \
    && cp /tmp/autoexec.ipxe /tftpboot/autoexec.ipxe \
    && cp /tmp/autoexec.ipxe /tftpboot/efi64/autoexec.ipxe

# Work around netboot.xyz #1793: iPXE 2.0.0+ can leave routing unconfigured
# behind a proxy DHCP server ("Network unreachable" / ipxe error 280a6090).
# Re-running DHCP re-establishes the default route; fall back to re-applying
# the DHCP-obtained config manually. This file is chained automatically by
# the embedded script from the proxy DHCP next-server. It ends without exit
# so control returns to the embedded script, which then loads the remote
# HTTPS menu (kept fresh from boot.netboot.xyz).
RUN printf '%s\n' \
    '#!ipxe' \
    '# Workaround for netboot.xyz #1793' \
    'dhcp net0 && goto done ||' \
    'echo DHCP retry failed, attempting manual re-apply...' \
    'set saved-ip ${net0/ip}' \
    'set saved-mask ${net0/netmask}' \
    'set saved-gateway ${net0/gateway}' \
    'ifclose net0' \
    'ifopen net0' \
    'set net0/ip ${saved-ip}' \
    'set net0/netmask ${saved-mask}' \
    'set net0/gateway ${saved-gateway}' \
    'route' \
    ':done' \
    > /tftpboot/local-vars.ipxe

# /etc/dnsmasq.conf
RUN echo "port=0 # Disable DHCP/DNS service" > /etc/dnsmasq.conf
RUN echo "dhcp-range={NETWORK_IP},proxy" >> /etc/dnsmasq.conf
RUN echo "dhcp-boot=pxelinux.0" >> /etc/dnsmasq.conf
RUN echo 'pxe-service=x86PC, "Boot BIOS PXE", netboot.xyz-legacy.kpxe' >> /etc/dnsmasq.conf
RUN echo 'pxe-service=BC_EFI, "Boot UEFI PXE-BC", efi64/netboot.xyz-legacy.efi' >> /etc/dnsmasq.conf
RUN echo 'pxe-service=x86-64_EFI, "Boot UEFI PXE-64", efi64/netboot.xyz-legacy.efi' >> /etc/dnsmasq.conf
RUN echo "enable-tftp" >> /etc/dnsmasq.conf
RUN echo "tftp-root=/tftpboot" >> /etc/dnsmasq.conf
RUN echo "user=root # Solve: operation not permitted" >> /etc/dnsmasq.conf

# /etc/conf.d/dnsmasq
RUN mkdir -p /etc/conf.d
RUN echo "DNSMASQ_EXCEPT=lo" >> /etc/conf.d/dnsmasq

COPY /entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 69/udp

ENTRYPOINT ["/entrypoint.sh"]
