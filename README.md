# netbooz.xyz Container

netboot.xyz enables you to PXE boot many Operating System installers and utilities over network.

## Deployment Example

### docker-compose

```yaml
version: "3.7"

services:
  pxe_server:
    image: ghcr.io/niki-on-github/netboot-xyz:latest
    container_name: pxe-server
    restart: unless-stopped
    network_mode: "host"
    cap_add:
      - NET_ADMIN
    environment:
      NETWORK_IP: "{{ network_ip }}"
```
