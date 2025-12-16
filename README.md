# Running No-Overlay Mode in OpenShift (Development)

> **Note:** This guide is for the development phase before the code is merged.

## Prerequisites

- Borrow a machine from https://beaker.engineering.redhat.com/ and install RHEL 9 on it.
- Clone https://github.com/openshift-metal3/dev-scripts to the home directory of the remote machine and follow the `Preparation` steps in the README file.
- Get a CI token from https://console-openshift-console.apps.ci.l2s4.p1.openshiftapps.com/

## Configuration Files

The `resources/` folder contains all necessary files:

```$ tree resources/
resources/
├── config_rr.sh
├── extra_manifests_no_overlay_eBGP
│   ├── 99-frrconfig.yaml
│   ├── 99-operator_config.yaml
│   └── 99-ra.yaml
└── run.sh

2 directories, 5 files
```
`config_rr.sh` should be renamed `config_$USERNAME` where $USERNAME is the username chosen on the beaker machine.

## Setup

### Step 1: Create an OCP image
On clusterbot:
```
build 4.22,openshift/api#2537,openshift/cluster-network-operator#2844,openshift/ovn-kubernetes#2878,openshift/client-go#349
```
An image I've successfully tested recently is `registry.build11.ci.openshift.org/ci-ln-2gs0dzb/release:latest`

### Step 2: Spin up an FRR container

Set up a BGP Route Reflector on the hypervisor to enable pod-to-pod communication across nodes by exchanging pod subnet routes via BGP.

**1. Create configuration directory and FRR config:**

```bash
mkdir -p ~/frr-rr
```

Create `~/frr-rr/frr.conf`:
```conf
frr defaults traditional
hostname rr-container
log stdout informational

router bgp 64512
 bgp router-id 192.168.111.1
 bgp cluster-id 192.168.111.1
 no bgp ebgp-requires-policy
 no bgp default ipv4-unicast
 bgp graceful-restart preserve-fw-state

 neighbor NODES peer-group
 neighbor NODES remote-as 64512
 bgp listen range 192.168.111.0/24 peer-group NODES

 address-family ipv4 unicast
  neighbor NODES activate
  neighbor NODES route-reflector-client
 exit-address-family
exit

line vty
```

**2. Open firewall port:**

```bash
sudo firewall-cmd --zone=libvirt --add-port=179/tcp --permanent
sudo firewall-cmd --zone=libvirt --add-port=179/tcp
```

**3. Run the FRR container:**

```bash
sudo podman run -d --name frr-rr \
  --network host \
  --cap-add NET_ADMIN \
  --cap-add NET_RAW \
  --cap-add SYS_ADMIN \
  -v ~/frr-rr/frr.conf:/etc/frr/frr.conf:ro,Z \
  quay.io/frrouting/frr:10.2.1 \
  /usr/lib/frr/bgpd -n -Z -S -f /etc/frr/frr.conf
```

> **Important:** The `-n` flag prevents BGP routes from being installed into the hypervisor's kernel routing table. Without it, the hypervisor would intercept pod traffic and send TCP RST packets.

**4. Verify BGP status (after cluster is running):**

```bash
sudo podman exec frr-rr vtysh -c 'show bgp summary'
sudo podman exec frr-rr vtysh -c 'show bgp ipv4 unicast'
```

### Step 3: Launch the installation
Copy all the files in the `resources` folder to the home directory of the beaker machine. In your `config_$USERNAME.sh` file, set `CI_TOKEN` to your personal token that you retrieved as described in the prerequisite section.

You can finally launch the installation for the desired OCP image. For instance:
```
./run.sh registry.build11.ci.openshift.org/ci-ln-2gs0dzb/release:latest
```
