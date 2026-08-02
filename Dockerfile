FROM alpine:latest

# Pinned to 2.0.89 (iPXE 1.20.x): netboot.xyz v3 bootloaders use iPXE 2.0.0+,
# which fails with "Network unreachable" behind a proxy DHCP server
# (see https://github.com/netbootxyz/netboot.xyz/issues/1793).
ARG NETBOOT_XYZ_VERSION=2.0.89

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
