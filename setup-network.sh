#!/bin/bash

# This script sets up proper networking for OAI gNB to communicate with Dockerized core

echo "Setting up OAI 5G Network Configuration..."

# 1. Create a bridge interface that Docker containers can use
sudo ip link add name oai-br0 type bridge 2>/dev/null || echo "Bridge already exists"
sudo ip addr add 172.30.0.1/24 dev oai-br0 2>/dev/null || echo "IP already assigned"
sudo ip link set oai-br0 up

# 2. Connect Docker network to this bridge
docker network inspect 5g-core-net &>/dev/null && echo "Core network exists" || {
  echo "Creating 5g-core-net with proper gateway"
  docker network create --driver=bridge --subnet=172.30.0.0/24 --gateway=172.30.0.1 5g-core-net
}

# 3. Add routing so host can reach Docker containers
sudo ip route add 172.30.0.0/24 dev oai-br0 2>/dev/null || echo "Route exists"

# 4. Add AMF hostname to /etc/hosts
grep -q "172.30.0.100.*oai-amf" /etc/hosts || {
  echo "172.30.0.100 oai-amf amf" | sudo tee -a /etc/hosts
}

# 5. Verify connectivity
echo "Testing connectivity to AMF..."
ping -c 2 172.30.0.100 && echo "✓ AMF reachable" || echo "✗ AMF not reachable"

echo "Network setup complete!"
