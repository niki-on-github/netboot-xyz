# netbooz.xyz Container

netboot.xyz enables you to PXE boot many Operating System installers and utilities over network.

## Troubleshoot

The libvirt `default` network block by default the port `67` with an `dnsmasq` instance and this container ends in `CrashLoopBackOff`.

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

The `NETWORK_IP` for an `192.168.1.0/24` Network is `192.168.1.0`.

## helm-release

Using the `app-template` from [ bjw-s Helm charts](https://github.com/bjw-s/helm-charts) for the deployment:

```yaml
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: &app netboot
  namespace: apps
spec:
  interval: 15m
  chart:
    spec:
      chart: app-template
      version: 1.2.1
      interval: 1h
      sourceRef:
        kind: HelmRepository
        name: bjw-s-charts
        namespace: flux-system

  install:
    remediation:
      retries: -1

  upgrade:
    remediation:
      retries: 5

  values:
    global:
      nameOverride: *app

    image:
      repository: ghcr.io/niki-on-github/netboot-xyz
      tag: v1.0.2

    service:
      main:
        enabled: false

    hostNetwork: true
    dnsPolicy: ClusterFirstWithHostNet
    securityContext:
      capabilities:
        add: ["NET_ADMIN"]
      privileged: true

    env:
      NETWORK_IP: "${NETWORK_IP}"

    affinity:
      nodeAffinity:
        requiredDuringSchedulingIgnoredDuringExecution:
          nodeSelectorTerms:
            - matchExpressions:
                - key: kubernetes.io/hostname
                  operator: In
                  values:
                    - "${NETBOOT_SERVER_AFFINITY_HOSTNAME}"
```
