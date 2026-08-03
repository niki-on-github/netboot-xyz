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

# download bootloader from the pinned github release, boot.netboot.xyz always
# serves the latest (now v3) which is broken with proxy DHCP
RUN cd /tftpboot \
    && curl -fSL -o netboot.xyz.kpxe "https://github.com/netbootxyz/netboot.xyz/releases/download/${NETBOOT_XYZ_VERSION}/netboot.xyz.kpxe"

RUN cd /tftpboot/efi64 \
    && curl -fSL -o netboot.xyz.efi "https://github.com/netbootxyz/netboot.xyz/releases/download/${NETBOOT_XYZ_VERSION}/netboot.xyz.efi"

# Work around netboot.xyz #1793: iPXE 2.0.0+ leaves the NIC closed after
# proxy DHCP, so re-apply the DHCP-obtained config before the menu fetch.
# This file is chained automatically by the embedded script from the
# proxy DHCP next-server. The script ends without exit so control returns
# to the embedded script.
RUN printf '%s\n' \
    '#!ipxe' \
    'set saved-ip ${net0/ip}' \
    'set saved-mask ${net0/netmask}' \
    'set saved-gateway ${net0/gateway}' \
    'set saved-dns ${net0/dns}' \
    'ifclose net0' \
    'ifopen net0' \
    'set net0/ip ${saved-ip}' \
    'set net0/netmask ${saved-mask}' \
    'set net0/gateway ${saved-gateway}' \
    'set net0/dns ${saved-dns}' \
    > /tftpboot/local-vars.ipxe

# /etc/dnsmasq.conf
RUN echo "port=0 # Disable DHCP/DNS service" > /etc/dnsmasq.conf
RUN echo "dhcp-range={NETWORK_IP},proxy" >> /etc/dnsmasq.conf
RUN echo "dhcp-boot=pxelinux.0" >> /etc/dnsmasq.conf
RUN echo 'pxe-service=x86PC, "Boot BIOS PXE", netboot.xyz.kpxe' >> /etc/dnsmasq.conf
RUN echo 'pxe-service=BC_EFI, "Boot UEFI PXE-BC", efi64/netboot.xyz.efi' >> /etc/dnsmasq.conf
RUN echo 'pxe-service=x86-64_EFI, "Boot UEFI PXE-64", efi64/netboot.xyz.efi' >> /etc/dnsmasq.conf
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
