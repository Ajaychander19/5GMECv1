docker network create   --driver bridge   --subnet=172.30.0.0/16   --label=project=5g-oai-research-platform   5g-core-net
# Network 2: RAN Network
docker network create   --driver bridge   --subnet=172.31.0.0/16   --label=project=5g-oai-research-platform   5g-ran-net
# Network 3: RIC Network
docker network create   --driver bridge   --subnet=172.33.0.0/16   --label=project=5g-oai-research-platform   5g-ric-net
# Network 4: MEC Network
docker network create   --driver bridge   --subnet=172.32.0.0/16   --label=project=5g-oai-research-platform   5g-mec-net
docker network rm 5g-core-net 5g-ran-net 5g-ric-net 5g-mec-net
# Network 1: Core Network
docker network create   --driver bridge   --subnet=172.30.0.0/16   --label=project=5g-oai-research-platform   5g-core-net
# Network 2: RAN Network
docker network create   --driver bridge   --subnet=172.31.0.0/16   --label=project=5g-oai-research-platform   5g-ran-net
# Network 3: RIC Network
docker network create   --driver bridge   --subnet=172.33.0.0/16   --label=project=5g-oai-research-platform   5g-ric-net
# Network 4: MEC Network
docker network create   --driver bridge   --subnet=172.32.0.0/16   --label=project=5g-oai-research-platform   5g-mec-net
cd ~/5g-oai-research-platform/core
cat > docker-compose-core.yaml << 'EOF'
version: '3.8'

services:

  # =====================================================================
  # MySQL Database - REQUIRED for all core network functions
  # =====================================================================
  mysql:
    container_name: oai-mysql
    image: mysql:8.0
    platform: linux/amd64
    volumes:
      # Mount the database schema we created in Step 2
      - ./database/oai_db.sql:/docker-entrypoint-initdb.d/oai_db.sql
      # Persist database data
      - mysql_data:/var/lib/mysql
    environment:
      # MySQL root password
      MYSQL_ROOT_PASSWORD: linux
      # Create database
      MYSQL_DATABASE: oai_db
      # Create user for OAI
      MYSQL_USER: test
      MYSQL_PASSWORD: test
    healthcheck:
      # Check if MySQL is ready
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.10
    labels:
      project: 5g-oai-research-platform
      component: core
      service: database

  # =====================================================================
  # NRF (Network Function Repository)
  # Purpose: Registers all NFs, provides service discovery
  # =====================================================================
  oai-nrf:
    container_name: oai-nrf
    image: oaisoftwarealliance/oai-nrf:v2.1.0
    platform: linux/amd64
    environment:
      NRF_INTERFACE_NAME_FOR_SBI: eth0
      NRF_INTERFACE_PORT_FOR_SBI: 8080
      NRF_API_VERSION: v1
      INSTANCE: 0
      PID_DIRECTORY: /var/run
    ports:
      - "8080:8080/tcp"
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.20
    depends_on:
      mysql:
        condition: service_healthy
    labels:
      project: 5g-oai-research-platform
      component: core
      service: nrf

  # =====================================================================
  # UDR (Unified Data Repository)
  # Purpose: Stores subscriber data (credentials, profiles)
  # =====================================================================
  oai-udr:
    container_name: oai-udr
    image: oaisoftwarealliance/oai-udr:v2.1.0
    platform: linux/amd64
    environment:
      UDR_INTERFACE_NAME_FOR_NUDR: eth0
      UDR_INTERFACE_PORT_FOR_NUDR: 8080
      MYSQL_IPV4_ADDRESS: 172.30.0.10
      MYSQL_USER: test
      MYSQL_PASS: test
      MYSQL_DB: oai_db
      NRF_IPV4_ADDRESS: 172.30.0.20
      NRF_PORT: 8080
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.30
    depends_on:
      - mysql
      - oai-nrf
    labels:
      project: 5g-oai-research-platform
      component: core
      service: udr

  # =====================================================================
  # UDM (User Data Management)
  # Purpose: Handles subscriber authentication and authorization
  # =====================================================================
  oai-udm:
    container_name: oai-udm
    image: oaisoftwarealliance/oai-udm:v2.1.0
    platform: linux/amd64
    environment:
      UDM_INTERFACE_NAME_FOR_SBI: eth0
      UDM_INTERFACE_PORT_FOR_SBI: 8080
      UDR_IPV4_ADDRESS: 172.30.0.30
      UDR_PORT: 8080
      NRF_IPV4_ADDRESS: 172.30.0.20
      NRF_PORT: 8080
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.40
    depends_on:
      - oai-udr
    labels:
      project: 5g-oai-research-platform
      component: core
      service: udm

  # =====================================================================
  # AUSF (Authentication Server Function)
  # Purpose: Performs UE authentication (EAP-AKA)
  # =====================================================================
  oai-ausf:
    container_name: oai-ausf
    image: oaisoftwarealliance/oai-ausf:v2.1.0
    platform: linux/amd64
    environment:
      AUSF_INTERFACE_NAME_FOR_SBI: eth0
      AUSF_INTERFACE_PORT_FOR_SBI: 8080
      UDM_IPV4_ADDRESS: 172.30.0.40
      UDM_PORT: 8080
      NRF_IPV4_ADDRESS: 172.30.0.20
      NRF_PORT: 8080
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.50
    depends_on:
      - oai-udm
    labels:
      project: 5g-oai-research-platform
      component: core
      service: ausf

  # =====================================================================
  # AMF (Access and Mobility Management Function)
  # Purpose: UE attachment, registration, mobility management
  # =====================================================================
  oai-amf:
    container_name: oai-amf
    image: oaisoftwarealliance/oai-amf:v2.1.0
    platform: linux/amd64
    environment:
      # Network Configuration
      MCC: '208'
      MNC: '95'
      REGION_ID: '128'
      AMF_SET_ID: '1'
      # GUAMI (Globally Unique AMF Identifier)
      SERVED_GUAMI_MCC_0: '208'
      SERVED_GUAMI_MNC_0: '95'
      SERVED_GUAMI_REGION_ID_0: '128'
      SERVED_GUAMI_AMF_SET_ID_0: '1'
      # PLMN Support
      PLMN_SUPPORT_MCC: '208'
      PLMN_SUPPORT_MNC: '95'
      PLMN_SUPPORT_TAC: '0x0001'
      # Slices
      SST_0: '1'
      SD_0: '0xffffff'
      # Interfaces
      AMF_INTERFACE_NAME_FOR_NGAP: eth0
      AMF_INTERFACE_NAME_FOR_N11: eth0
      # SMF Address (N11 interface)
      SMF_IPV4_ADDR_0: 172.30.0.60
      SMF_FQDN_0: oai-smf
      # AUSF Address
      AUSF_IPV4_ADDRESS: 172.30.0.50
      AUSF_PORT: 8080
      # NRF Address
      NRF_IPV4_ADDRESS: 172.30.0.20
      NRF_PORT: 8080
      # NF Registration
      NF_REGISTRATION: 'yes'
      USE_FQDN_DNS: 'no'
    ports:
      - "38412:38412/sctp"
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.100
    depends_on:
      - oai-ausf
    labels:
      project: 5g-oai-research-platform
      component: core
      service: amf

  # =====================================================================
  # SMF (Session Management Function)
  # Purpose: PDU session establishment, QoS management
  # =====================================================================
  oai-smf:
    container_name: oai-smf
    image: oaisoftwarealliance/oai-smf:v2.1.0
    platform: linux/amd64
    environment:
      # Interfaces
      SMF_INTERFACE_NAME_FOR_N4: eth0
      SMF_INTERFACE_NAME_FOR_SBI: eth0
      SMF_INTERFACE_PORT_FOR_SBI: 8080
      SMF_INTERFACE_HTTP2_PORT_FOR_SBI: 9090
      # DNS
      DEFAULT_DNS_IPV4_ADDRESS: 8.8.8.8
      DEFAULT_DNS_SEC_IPV4_ADDRESS: 8.8.4.4
      # AMF Address (N11)
      AMF_IPV4_ADDRESS: 172.30.0.100
      AMF_PORT: 8080
      # UDM Address
      UDM_IPV4_ADDRESS: 172.30.0.40
      UDM_PORT: 8080
      # NRF Address
      NRF_IPV4_ADDRESS: 172.30.0.20
      NRF_PORT: 8080
      # UPF Address (N4)
      UPF_IPV4_ADDRESS: 172.30.0.70
      UPF_FQDN_0: oai-upf
      # NF Registration
      NF_REGISTRATION: 'yes'
      USE_FQDN_DNS: 'no'
      # DNN Configuration (Slice 1: eMBB)
      DNN_NI0: 'oai'
      TYPE0: 'IPv4'
      DNN_RANGE0: '12.1.1.0/24'
      NSSAI_SST0: '1'
      NSSAI_SD0: '0xffffff'
      SESSION_AMBR_UL0: '200Mbps'
      SESSION_AMBR_DL0: '400Mbps'
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.60
    depends_on:
      - oai-amf
    labels:
      project: 5g-oai-research-platform
      component: core
      service: smf

  # =====================================================================
  # UPF (User Plane Function) - CENTRAL
  # Purpose: Packet forwarding, traffic steering
  # =====================================================================
  oai-upf:
    container_name: oai-upf
    image: oaisoftwarealliance/oai-upf:v2.1.0
    platform: linux/amd64
    privileged: true
    environment:
      # UPF Instance
      NWINSTANCE: '1'
      GW_ID: '1'
      MNC03: '95'
      MCC: '208'
      REALM: '3gpp.org'
      PID_DIRECTORY: /var/run
      # Interface Setup
      INTERFACES_SETUP: 'yes'
      INTERFACE_NAME: eth0
      INTERFACE_N3_IP_ADDR: 172.30.0.70
      INTERFACE_N6_IP_ADDR: 172.30.0.71
      # NF Registration
      NF_REGISTRATION: 'yes'
      NRF_IPV4_ADDRESS: 172.30.0.20
      NRF_PORT: 8080
      # Slices
      NSSAI_SST_0: '1'
      NSSAI_SD_0: '0xffffff'
      DNN_0: 'oai'
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.70
    depends_on:
      - oai-nrf
    labels:
      project: 5g-oai-research-platform
      component: core
      service: upf

# =====================================================================
# Networks
# =====================================================================
networks:
  5g_core_net:
    external: true
    name: 5g-core-net

# =====================================================================
# Volumes
# =====================================================================
volumes:
  mysql_data:
    driver: local
EOF

cat > docker-compose-core.yaml << 'EOF'
version: '3.8'

services:

  # =====================================================================
  # MySQL Database - REQUIRED for all core network functions
  # =====================================================================
  mysql:
    container_name: oai-mysql
    image: mysql:8.0
    platform: linux/amd64
    volumes:
      # Mount the database schema we created in Step 2
      - ./database/oai_db.sql:/docker-entrypoint-initdb.d/oai_db.sql
      # Persist database data
      - mysql_data:/var/lib/mysql
    environment:
      # MySQL root password
      MYSQL_ROOT_PASSWORD: linux
      # Create database
      MYSQL_DATABASE: oai_db
      # Create user for OAI
      MYSQL_USER: test
      MYSQL_PASSWORD: test
    healthcheck:
      # Check if MySQL is ready
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.10
    labels:
      project: 5g-oai-research-platform
      component: core
      service: database

  # =====================================================================
  # NRF (Network Function Repository)
  # Purpose: Registers all NFs, provides service discovery
  # =====================================================================
  oai-nrf:
    container_name: oai-nrf
    image: oaisoftwarealliance/oai-nrf:v2.1.0
    platform: linux/amd64
    environment:
      NRF_INTERFACE_NAME_FOR_SBI: eth0
      NRF_INTERFACE_PORT_FOR_SBI: 8080
      NRF_API_VERSION: v1
      INSTANCE: 0
      PID_DIRECTORY: /var/run
    ports:
      - "8080:8080/tcp"
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.20
    depends_on:
      mysql:
        condition: service_healthy
    labels:
      project: 5g-oai-research-platform
      component: core
      service: nrf

  # =====================================================================
  # UDR (Unified Data Repository)
  # Purpose: Stores subscriber data (credentials, profiles)
  # =====================================================================
  oai-udr:
    container_name: oai-udr
    image: oaisoftwarealliance/oai-udr:v2.1.0
    platform: linux/amd64
    environment:
      UDR_INTERFACE_NAME_FOR_NUDR: eth0
      UDR_INTERFACE_PORT_FOR_NUDR: 8080
      MYSQL_IPV4_ADDRESS: 172.30.0.10
      MYSQL_USER: test
      MYSQL_PASS: test
      MYSQL_DB: oai_db
      NRF_IPV4_ADDRESS: 172.30.0.20
      NRF_PORT: 8080
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.30
    depends_on:
      - mysql
      - oai-nrf
    labels:
      project: 5g-oai-research-platform
      component: core
      service: udr

  # =====================================================================
  # UDM (User Data Management)
  # Purpose: Handles subscriber authentication and authorization
  # =====================================================================
  oai-udm:
    container_name: oai-udm
    image: oaisoftwarealliance/oai-udm:v2.1.0
    platform: linux/amd64
    environment:
      UDM_INTERFACE_NAME_FOR_SBI: eth0
      UDM_INTERFACE_PORT_FOR_SBI: 8080
      UDR_IPV4_ADDRESS: 172.30.0.30
      UDR_PORT: 8080
      NRF_IPV4_ADDRESS: 172.30.0.20
      NRF_PORT: 8080
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.40
    depends_on:
      - oai-udr
    labels:
      project: 5g-oai-research-platform
      component: core
      service: udm

  # =====================================================================
  # AUSF (Authentication Server Function)
  # Purpose: Performs UE authentication (EAP-AKA)
  # =====================================================================
  oai-ausf:
    container_name: oai-ausf
    image: oaisoftwarealliance/oai-ausf:v2.1.0
    platform: linux/amd64
    environment:
      AUSF_INTERFACE_NAME_FOR_SBI: eth0
      AUSF_INTERFACE_PORT_FOR_SBI: 8080
      UDM_IPV4_ADDRESS: 172.30.0.40
      UDM_PORT: 8080
      NRF_IPV4_ADDRESS: 172.30.0.20
      NRF_PORT: 8080
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.50
    depends_on:
      - oai-udm
    labels:
      project: 5g-oai-research-platform
      component: core
      service: ausf

  # =====================================================================
  # AMF (Access and Mobility Management Function)
  # Purpose: UE attachment, registration, mobility management
  # =====================================================================
  oai-amf:
    container_name: oai-amf
    image: oaisoftwarealliance/oai-amf:v2.1.0
    platform: linux/amd64
    environment:
      # Network Configuration
      MCC: '208'
      MNC: '95'
      REGION_ID: '128'
      AMF_SET_ID: '1'
      # GUAMI (Globally Unique AMF Identifier)
      SERVED_GUAMI_MCC_0: '208'
      SERVED_GUAMI_MNC_0: '95'
      SERVED_GUAMI_REGION_ID_0: '128'
      SERVED_GUAMI_AMF_SET_ID_0: '1'
      # PLMN Support
      PLMN_SUPPORT_MCC: '208'
      PLMN_SUPPORT_MNC: '95'
      PLMN_SUPPORT_TAC: '0x0001'
      # Slices
      SST_0: '1'
      SD_0: '0xffffff'
      # Interfaces
      AMF_INTERFACE_NAME_FOR_NGAP: eth0
      AMF_INTERFACE_NAME_FOR_N11: eth0
      # SMF Address (N11 interface)
      SMF_IPV4_ADDR_0: 172.30.0.60
      SMF_FQDN_0: oai-smf
      # AUSF Address
      AUSF_IPV4_ADDRESS: 172.30.0.50
      AUSF_PORT: 8080
      # NRF Address
      NRF_IPV4_ADDRESS: 172.30.0.20
      NRF_PORT: 8080
      # NF Registration
      NF_REGISTRATION: 'yes'
      USE_FQDN_DNS: 'no'
    ports:
      - "38412:38412/sctp"
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.100
    depends_on:
      - oai-ausf
    labels:
      project: 5g-oai-research-platform
      component: core
      service: amf

  # =====================================================================
  # SMF (Session Management Function)
  # Purpose: PDU session establishment, QoS management
  # =====================================================================
  oai-smf:
    container_name: oai-smf
    image: oaisoftwarealliance/oai-smf:v2.1.0
    platform: linux/amd64
    environment:
      # Interfaces
      SMF_INTERFACE_NAME_FOR_N4: eth0
      SMF_INTERFACE_NAME_FOR_SBI: eth0
      SMF_INTERFACE_PORT_FOR_SBI: 8080
      SMF_INTERFACE_HTTP2_PORT_FOR_SBI: 9090
      # DNS
      DEFAULT_DNS_IPV4_ADDRESS: 8.8.8.8
      DEFAULT_DNS_SEC_IPV4_ADDRESS: 8.8.4.4
      # AMF Address (N11)
      AMF_IPV4_ADDRESS: 172.30.0.100
      AMF_PORT: 8080
      # UDM Address
      UDM_IPV4_ADDRESS: 172.30.0.40
      UDM_PORT: 8080
      # NRF Address
      NRF_IPV4_ADDRESS: 172.30.0.20
      NRF_PORT: 8080
      # UPF Address (N4)
      UPF_IPV4_ADDRESS: 172.30.0.70
      UPF_FQDN_0: oai-upf
      # NF Registration
      NF_REGISTRATION: 'yes'
      USE_FQDN_DNS: 'no'
      # DNN Configuration (Slice 1: eMBB)
      DNN_NI0: 'oai'
      TYPE0: 'IPv4'
      DNN_RANGE0: '12.1.1.0/24'
      NSSAI_SST0: '1'
      NSSAI_SD0: '0xffffff'
      SESSION_AMBR_UL0: '200Mbps'
      SESSION_AMBR_DL0: '400Mbps'
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.60
    depends_on:
      - oai-amf
    labels:
      project: 5g-oai-research-platform
      component: core
      service: smf

  # =====================================================================
  # UPF (User Plane Function) - CENTRAL
  # Purpose: Packet forwarding, traffic steering
  # =====================================================================
  oai-upf:
    container_name: oai-upf
    image: oaisoftwarealliance/oai-upf:v2.1.0
    platform: linux/amd64
    privileged: true
    environment:
      # UPF Instance
      NWINSTANCE: '1'
      GW_ID: '1'
      MNC03: '95'
      MCC: '208'
      REALM: '3gpp.org'
      PID_DIRECTORY: /var/run
      # Interface Setup
      INTERFACES_SETUP: 'yes'
      INTERFACE_NAME: eth0
      INTERFACE_N3_IP_ADDR: 172.30.0.70
      INTERFACE_N6_IP_ADDR: 172.30.0.71
      # NF Registration
      NF_REGISTRATION: 'yes'
      NRF_IPV4_ADDRESS: 172.30.0.20
      NRF_PORT: 8080
      # Slices
      NSSAI_SST_0: '1'
      NSSAI_SD_0: '0xffffff'
      DNN_0: 'oai'
    networks:
      5g_core_net:
        ipv4_address: 172.30.0.70
    depends_on:
      - oai-nrf
    labels:
      project: 5g-oai-research-platform
      component: core
      service: upf

# =====================================================================
# Networks
# =====================================================================
networks:
  5g_core_net:
    external: true
    name: 5g-core-net

# =====================================================================
# Volumes
# =====================================================================
volumes:
  mysql_data:
    driver: local
EOF

nano 
ls
nano docker-compose-core.yaml 
cd ~/5g-oai-research-platform/core
# Check file exists
ls -lh docker-compose-core.yaml
# Show first 30 lines
head -30 docker-compose-core.yaml
# Count total lines
wc -l docker-compose-core.yaml
docker pull mysql:8.0
# NRF (Network Function Repository)
docker pull oaisoftwarealliance/oai-nrf:v2.1.0
# UDR (Unified Data Repository)
docker pull oaisoftwarealliance/oai-udr:v2.1.0
# UDM (User Data Management)
docker pull oaisoftwarealliance/oai-udm:v2.1.0
# AUSF (Authentication Server Function)
docker pull oaisoftwarealliance/oai-ausf:v2.1.0
# AMF (Access and Mobility Management Function)
docker pull oaisoftwarealliance/oai-amf:v2.1.0
# SMF (Session Management Function)
docker pull oaisoftwarealliance/oai-smf:v2.1.0
# UPF (User Plane Function)
docker pull oaisoftwarealliance/oai-upf:v2.1.0
# gNB (5G Base Station)
docker pull oaisoftwarealliance/oai-gnb:2024.w40
# NR-UE (5G User Equipment - simulated)
docker pull oaisoftwarealliance/oai-nr-ue:2024.w40
# FlexRIC RIC (O-RAN compliant controller)
docker pull oaisoftwarealliance/oai-flexric-ric:latest
# KPM xApp (monitoring)
docker pull oaisoftwarealliance/oai-flexric-xapp-kpm:latest
# RC xApp (RAN control)
docker pull oaisoftwarealliance/oai-flexric-xapp-rc:latest
# MEP Platform (ETSI MEC compliant)
docker pull oaisoftwarealliance/oai-mep:latest
# RNIS Service (Radio Network Information Service)
docker pull oaisoftwarealliance/oai-rnis:latest
# Nginx (for edge caching app)
docker pull nginx:alpine
# Redis (for edge data store)
docker pull redis:alpine
# InfluxDB (for metrics storage)
docker pull influxdb:latest
docker images | grep -E "oai|mysql|nginx|redis|influxdb"
git clone https://gitlab.eurecom.fr/oai/osm-packages/ric-packages.git
cd ric-packages
docker build -t flexric-ric .
# FlexRIC RIC (from mosaic5g - official repository)
docker pull mosaic5g/flexric:latest
cd ~/5g-oai-research-platform/ran
cat > docker-compose-ran.yaml << 'EOF'
version: '3.8'

services:

  # =====================================================================
  # OAI gNB (5G Base Station)
  # Purpose: Radio access network, handles UE connections
  # =====================================================================
  oai-gnb:
    container_name: oai-gnb
    image: oaisoftwarealliance/oai-gnb:2024.w40
    platform: linux/amd64
    privileged: true
    # Mount configuration files (we'll create these next)
    volumes:
      # Log directory for gNB output
      - ./logs:/opt/oai-gnb/logs
    environment:
      # ===== NETWORK CONFIGURATION =====
      # Use Standalone (SA) mode with TDD (Time Division Duplex)
      USE_SA_TDD_MONO: 'yes'
      
      # gNB name
      GNBNAME: 'oai-gnb'
      
      # Number of cores to use
      NBCORES: '4'
      
      # Number of simulated UEs to support
      NB_UE: '4'
      
      # Time synchronization
      SYNC_REF: 'internal'
      
      # ===== PLMN (Network Identification) =====
      # MCC = Mobile Country Code (208 = France for testing)
      MCC: '208'
      # MNC = Mobile Network Code (95 = test)
      MNC: '95'
      # Tracking Area Code
      TAC: '1'
      
      # ===== NETWORK SLICING (S-NSSAI) =====
      # Slice 1: eMBB (Enhanced Mobile Broadband)
      NSSAI_SST_0: '1'
      NSSAI_SD_0: '0xffffff'
      # Slice 2: URLLC (Ultra Reliable Low Latency)
      NSSAI_SST_1: '2'
      NSSAI_SD_1: '0x112233'
      
      # ===== E2 AGENT CONFIGURATION =====
      # Enable E2 agent (for future RIC connection)
      ENABLE_E2: 'no'  # Set to 'yes' if you add FlexRIC later
      E2_AGENT_IPADDR: 'oai-gnb'
      E2_AGENT_PORT: '36422'
      
      # RIC connection (for when E2 is enabled)
      # RIC_IP_ADDRESS: '172.33.0.10'  # Uncomment if using RIC
      # RIC_PORT: '36422'
      
      # ===== INTERFACES =====
      # Interface names and IP addresses
      NGA_IF_NAME: 'eth0'
      NGA_IP_ADDRESS: '172.31.0.10'
      NGU_IF_NAME: 'eth0'
      NGU_IP_ADDRESS: '172.31.0.10'
      
      # ===== CORE NETWORK CONNECTIVITY =====
      # AMF (Access and Mobility Management Function) address
      AMF_IP_ADDRESS: '172.30.0.100'
      
      # ===== NFAPI PARAMETERS =====
      # VNF = Virtual Network Function (containerized)
      NFAPI_MODE: 'VNF'
      
      # RAN operating mode (FR1 = Frequency Range 1, 0-6 GHz)
      RAN_FRAME_TYPE: 'FDD'
      
    ports:
      # NGAP port (gNB to AMF communication - SCTP)
      - "38412:38412/sctp"
      # Optional: Debug/management ports
      - "9091:9091/tcp"
    
    networks:
      # Connect to RAN network
      5g_ran_net:
        ipv4_address: 172.31.0.10
      # Also connect to core network for N2 interface (NGAP)
      5g_core_net:
    
    depends_on:
      # Wait for core network to be ready
      - oai-amf-wait
    
    labels:
      project: 5g-oai-research-platform
      component: ran
      service: gnb
    
    # gNB startup can be slow (60+ seconds)
    healthcheck:
      test: ["CMD", "ps", "aux"]
      interval: 30s
      timeout: 10s
      retries: 3

  # =====================================================================
  # Dummy service to ensure core network is up before starting gNB
  # =====================================================================
  oai-amf-wait:
    container_name: oai-amf-check
    image: busybox:latest
    networks:
      5g_core_net:
    command: sh -c "echo 'Waiting for core network...' && sleep 5"
    labels:
      project: 5g-oai-research-platform
      component: ran
      service: helper

# =====================================================================
# Networks
# =====================================================================
networks:
  5g_ran_net:
    external: true
    name: 5g-ran-net
  
  5g_core_net:
    external: true
    name: 5g-core-net

EOF

cd ~/5g-oai-research-platform/ran
# Check file exists
ls -lh docker-compose-ran.yaml
# Show first 50 lines
head -50 docker-compose-ran.yaml
# Count total lines
wc -l docker-compose-ran.yaml
mkdir -p ~/5g-oai-research-platform/ran/logs
chmod 777 ~/5g-oai-research-platform/ran/logs
cd ~/5g-oai-research-platform/ran
cat > docker-compose-ueransim.yaml << 'EOF'
version: '3.8'

services:

  # =====================================================================
  # OAI NR-UE (5G User Equipment Simulator)
  # Purpose: Simulates a 5G phone/device connecting to gNB
  # =====================================================================
  oai-nr-ue:
    container_name: oai-nr-ue
    image: oaisoftwarealliance/oai-nr-ue:2024.w40
    platform: linux/amd64
    privileged: true
    # Mount configuration and logs
    volumes:
      # Log directory for UE output
      - ./logs/ue:/opt/oai-nr-ue/logs
    environment:
      # ===== UE IDENTIFICATION =====
      # IMSI = International Mobile Subscriber Identity
      # Format: MCC (208) + MNC (95) + Subscription ID (000000001)
      # This must match a subscriber in the database (core/database/oai_db.sql)
      IMSI: '208950000000001'
      
      # ===== AUTHENTICATION CREDENTIALS =====
      # These match the test subscriber in oai_db.sql
      # Permanent Key (Ki)
      KEY: '0C0A34601D4F07677303652C0624'
      
      # Operator's Secret Key (OPc)
      OPC: '63BFA50EE6523365FF14C1F45F88737D'
      
      # ===== UE CAPABILITIES =====
      # Enable Standalone (SA) mode
      USE_SA_TDD_MONO: 'yes'
      
      # UE ID (for internal tracking when multiple UEs)
      UEID: '1'
      
      # ===== NETWORK SLICE SELECTION =====
      # SST = Slice/Service Type (1 = eMBB, 2 = URLLC, etc.)
      NSSAI_SST: '1'
      # SD = Slice Differentiator (0xffffff = default for SST=1)
      NSSAI_SD: '0xffffff'
      
      # ===== DNN CONFIGURATION =====
      # DNN = Data Network Name (which network slice to connect to)
      # This matches the DNN in core network SMF configuration
      DNN: 'oai'
      
      # Registered DNN (for initial registration)
      REGISTERED_DNN: 'oai'
      
      # ===== CORE NETWORK CONNECTION =====
      # Optional: NRF IP (if you want direct NRF discovery)
      # Leave empty to use gNB-provided configuration
      # NRF_IPADDR: '172.30.0.20'
      
      # ===== LOGGING =====
      # Log level: DEBUG, INFO, WARNING, ERROR
      LOG_LEVEL: 'INFO'
      
      # ===== PDU SESSION CONFIGURATION =====
      # PDU Session Type (IPv4, IPv6, IPv4v6)
      PDU_SESSION_TYPE: 'IPv4'
      
      # SSC Mode (0 = SSC mode 0, 1 = SSC mode 1, 2 = SSC mode 2, 3 = SSC mode 3)
      SSC_MODE: '1'
      
      # ===== OPTIONAL: UE BEHAVIOR =====
      # Enable registration (default: yes)
      REGISTRATION: 'yes'
      
      # Enable PDU session establishment (default: yes)
      ESTABLISH_PDU_SESSION: 'yes'
      
      # Time to wait before attempting registration (milliseconds)
      REGISTRATION_DELAY: '1000'
    
    # Map logs directory from host
    stdin_open: true
    tty: true
    
    networks:
      # Connect to RAN network
      5g_ran_net:
        ipv4_address: 172.31.0.200
    
    depends_on:
      # Wait for gNB to be ready
      - oai-gnb
    
    labels:
      project: 5g-oai-research-platform
      component: ran
      service: ue
    
    # UE startup is fast (10-20 seconds)
    healthcheck:
      test: ["CMD", "ps", "aux"]
      interval: 10s
      timeout: 5s
      retries: 3

# =====================================================================
# Networks
# =====================================================================
networks:
  5g_ran_net:
    external: true
    name: 5g-ran-net

EOF

cd ~/5g-oai-research-platform/ran
# Check file exists
ls -lh docker-compose-ueransim.yaml
# Show first 50 lines
head -50 docker-compose-ueransim.yaml
# Count total lines
wc -l docker-compose-ueransim.yaml
cat ~/5g-oai-research-platform/core/database/oai_db.sql | grep "208950000000001" -A 2
mkdir -p ~/5g-oai-research-platform/ran/logs/ue
chmod 777 ~/5g-oai-research-platform/ran/logs/ue
cd ~/5g-oai-research-platform/mec
cat > docker-compose-mep.yaml << 'EOF'
version: '3.8'

services:

  # =====================================================================
  # InfluxDB - Time Series Database for Metrics
  # Purpose: Store and query RAN/network metrics collected from experiments
  # =====================================================================
  influxdb:
    container_name: influxdb-metrics
    image: influxdb:latest
    platform: linux/amd64
    environment:
      # InfluxDB v2.x configuration
      INFLUXDB_DB: metrics
      INFLUXDB_ADMIN_USER: admin
      INFLUXDB_ADMIN_PASSWORD: admin123
      INFLUXDB_HTTP_AUTH_ENABLED: 'true'
      INFLUXDB_REPORTING_DISABLED: 'false'
    ports:
      # InfluxDB HTTP API port
      - "8086:8086/tcp"
    volumes:
      # Persist database data
      - influxdb_data:/var/lib/influxdb2
    networks:
      5g_mec_net:
        ipv4_address: 172.32.0.30
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8086/ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    labels:
      project: 5g-oai-research-platform
      component: mec
      service: metrics-db

  # =====================================================================
  # Redis - In-Memory Data Store
  # Purpose: Cache, session storage, metrics queuing for MEC apps
  # =====================================================================
  redis-edge:
    container_name: redis-edge
    image: redis:alpine
    platform: linux/amd64
    ports:
      # Redis default port
      - "6379:6379/tcp"
    volumes:
      # Persist Redis data
      - redis_data:/data
    networks:
      5g_mec_net:
        ipv4_address: 172.32.0.40
    command: redis-server --appendonly yes
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
    labels:
      project: 5g-oai-research-platform
      component: mec
      service: cache

  # =====================================================================
  # Edge UPF (User Plane Function) - Traffic Breakout
  # Purpose: Local data offloading for edge applications
  # =====================================================================
  oai-upf-edge:
    container_name: oai-upf-edge
    image: oaisoftwarealliance/oai-upf:v2.1.0
    platform: linux/amd64
    privileged: true
    environment:
      # ===== UPF INSTANCE CONFIGURATION =====
      # This is a second UPF instance (first one in core network)
      NWINSTANCE: '2'
      GW_ID: '2'
      MNC03: '95'
      MCC: '208'
      REALM: '3gpp.org'
      PID_DIRECTORY: /var/run
      
      # ===== INTERFACE SETUP =====
      INTERFACES_SETUP: 'yes'
      INTERFACE_NAME: eth0
      # N3 interface (from gNB/RAN side)
      INTERFACE_N3_IP_ADDR: 172.32.0.11
      # N6 interface (to edge applications/internet)
      INTERFACE_N6_IP_ADDR: 172.32.0.12
      
      # ===== NF REGISTRATION =====
      # Register with NRF so SMF can discover this UPF
      NF_REGISTRATION: 'yes'
      NRF_IPV4_ADDRESS: 172.30.0.20
      NRF_PORT: 8080
      
      # ===== NETWORK SLICING =====
      # This edge UPF handles Slice 2 (URLLC - low latency)
      NSSAI_SST_0: '2'
      NSSAI_SD_0: '0x112233'
      # DNN for edge slice
      DNN_0: 'edge'
    
    networks:
      # Connect to MEC network
      5g_mec_net:
        ipv4_address: 172.32.0.11
      # Also connect to core network for UPF communication
      5g_core_net:
    
    labels:
      project: 5g-oai-research-platform
      component: mec
      service: upf-edge
    
    healthcheck:
      test: ["CMD", "ps", "aux"]
      interval: 30s
      timeout: 10s
      retries: 3

  # =====================================================================
  # Nginx - Edge Caching Service
  # Purpose: Cache web content locally at the edge
  # =====================================================================
  mec-app-cache:
    container_name: mec-app-cache
    image: nginx:alpine
    platform: linux/amd64
    ports:
      # Nginx HTTP port (accessible to edge users)
      - "8000:80/tcp"
    volumes:
      # Serve cached content from here
      - ./data/cache:/usr/share/nginx/html:ro
    networks:
      5g_mec_net:
        ipv4_address: 172.32.0.50
    environment:
      # App metadata
      MEC_APP_ID: app-cache-001
      MEC_APP_DNN: edge
      MEC_APP_SNSSAI_SST: '2'
      MEC_APP_SNSSAI_SD: 0x112233
    labels:
      project: 5g-oai-research-platform
      component: mec
      service: app-cache
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost/"]
      interval: 10s
      timeout: 5s
      retries: 3

  # =====================================================================
  # PostgreSQL - Research Data Storage
  # Purpose: Store experiment results, network events, analysis data
  # =====================================================================
  postgres-research:
    container_name: postgres-research
    image: postgres:15-alpine
    platform: linux/amd64
    environment:
      # PostgreSQL superuser credentials
      POSTGRES_USER: researcher
      POSTGRES_PASSWORD: research123
      # Initial database
      POSTGRES_DB: 5g_research
      # Timezone for timestamps
      TZ: UTC
    ports:
      # PostgreSQL port
      - "5432:5432/tcp"
    volumes:
      # Persist database
      - postgres_data:/var/lib/postgresql/data
      # Optional: initialization scripts
      - ./init-db:/docker-entrypoint-initdb.d:ro
    networks:
      5g_mec_net:
        ipv4_address: 172.32.0.60
    environment:
      PGDATA: /var/lib/postgresql/data/pgdata
    labels:
      project: 5g-oai-research-platform
      component: mec
      service: research-db
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U researcher"]
      interval: 10s
      timeout: 5s
      retries: 5

  # =====================================================================
  # Prometheus - Metrics Collection & Monitoring (Optional)
  # Purpose: Scrape and store metrics from exporters
  # =====================================================================
  prometheus:
    container_name: prometheus-monitor
    image: prometheus:latest
    platform: linux/amd64
    ports:
      # Prometheus web UI and API
      - "9090:9090/tcp"
    volumes:
      # Prometheus configuration
      - ./config/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      # Store metrics data
      - prometheus_data:/prometheus
    networks:
      5g_mec_net:
        ipv4_address: 172.32.0.70
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
    labels:
      project: 5g-oai-research-platform
      component: mec
      service: monitoring
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9090"]
      interval: 10s
      timeout: 5s
      retries: 3

# =====================================================================
# Networks
# =====================================================================
networks:
  5g_mec_net:
    external: true
    name: 5g-mec-net
  
  5g_core_net:
    external: true
    name: 5g-core-net

# =====================================================================
# Volumes (Persistent Storage)
# =====================================================================
volumes:
  influxdb_data:
    driver: local
  
  redis_data:
    driver: local
  
  postgres_data:
    driver: local
  
  prometheus_data:
    driver: local

EOF

cd ~/5g-oai-research-platform/mec
# Check file exists
ls -lh docker-compose-mep.yaml
# Show first 50 lines
head -50 docker-compose-mep.yaml
# Count total lines
wc -l docker-compose-mep.yaml
mkdir -p ~/5g-oai-research-platform/mec/data/cache
mkdir -p ~/5g-oai-research-platform/mec/config
mkdir -p ~/5g-oai-research-platform/mec/init-db
cat > ~/5g-oai-research-platform/mec/config/prometheus.yml << 'EOF'
# Prometheus Configuration for 5G Research Platform

global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    project: '5g-oai-research-platform'

# Alerting rules (optional)
alerting:
  alertmanagers: []

# Scrape configs
scrape_configs:
  # Self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Add metrics sources here as you expand
  # Example (later):
  # - job_name: 'oai-gnb'
  #   static_configs:
  #     - targets: ['172.31.0.10:9091']

EOF

cat > ~/5g-oai-research-platform/mec/data/cache/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>5G Edge Cache Test</title>
</head>
<body>
    <h1>5G Research Platform - Edge Cache Service</h1>
    <p>This content is served from the edge (MEC) cache.</p>
    <p>Cached at: 172.32.0.50:8000</p>
    <p>MEC App: app-cache-001</p>
    <p>DNN: edge (Slice 2 - URLLC)</p>
</body>
</html>
EOF

cd ~/5g-oai-research-platform/core
# Start all core network services
docker-compose -f docker-compose-core.yaml up -d
# Monitor startup progress
docker-compose -f docker-compose-core.yaml logs -f
docker ps | grep oai-
docker logs oai-mysql | grep "ready for connections"
docker logs oai-amf | tail -20
# From AMF, can we reach SMF?
docker exec oai-amf ping -c 3 172.30.0.60
# From SMF, can we reach UPF?
docker exec oai-smf ping -c 3 172.30.0.70
# From NRF, can we reach MySQL?
docker exec oai-nrf ping -c 3 172.30.0.10
# Connect to MySQL and verify tables
docker exec -it oai-mysql mysql -utest -ptest oai_db -e "SHOW TABLES;"
docker logs oai-mysql | tail -50
docker exec -it oai-mysql mysql -utest -ptest oai_db -e "SELECT ueid FROM AuthenticationSubscription;"
# Stop and remove MySQL container (data will be lost, but we need to reinit)
cd ~/5g-oai-research-platform/core
docker-compose -f docker-compose-core.yaml down
# Remove the MySQL volume to force fresh initialization
docker volume rm core_mysql_data
# Start again
docker-compose -f docker-compose-core.yaml up -d
# Wait 60 seconds for MySQL to initialize with the schema
sleep 60
# Verify tables exist
docker exec -it oai-mysql mysql -utest -ptest oai_db -e "SHOW TABLES;"
docker ps
docker ps -a
docker logs oai-mysql
nano ~/5g-oai-research-platform/core/oai_db.sql
# Check if MySQL is ready
docker exec oai-mysql mysql -utest -ptest -e "SELECT 1;"
# Check if database exists
docker exec oai-mysql mysql -utest -ptest -e "SHOW DATABASES;"
# Check if tables exist
docker exec oai-mysql mysql -utest -ptest oai_db -e "SHOW TABLES;"
# Check if test subscriber exists
docker exec oai-mysql mysql -utest -ptest oai_db -e "SELECT ueid FROM AuthenticationSubscription;"
# Stop all containers
docker-compose -f docker-compose-core.yaml down -v
# Wait 5 seconds
sleep 5
# Remove all related volumes
docker volume rm $(docker volume ls | grep core | awk '{print $2}') 2>/dev/null || true
# Remove MySQL image and re-pull
docker rmi mysql:8.0 2>/dev/null || true
docker pull mysql:8.0
# Start fresh
docker-compose -f docker-compose-core.yaml up -d
# Wait 90 seconds for MySQL to fully initialize
echo "Waiting for MySQL initialization..."
sleep 90
# Check status
docker ps | grep oai-mysql
# Check if MySQL is ready
docker exec oai-mysql mysql -utest -ptest -e "SELECT 1;"
# Check if database exists
docker exec oai-mysql mysql -utest -ptest -e "SHOW DATABASES;"
# Check if tables exist
docker exec oai-mysql mysql -utest -ptest oai_db -e "SHOW TABLES;"
# Check if test subscriber exists
docker exec oai-mysql mysql -utest -ptest oai_db -e "SELECT ueid FROM AuthenticationSubscription;"
cd ~/5g-oai-research-platform/core/database
# Backup the old file
cp oai_db.sql oai_db.sql.backup
# Create a new, simplified but complete schema
cat > oai_db.sql << 'EOF'
-- =====================================================================
-- OAI 5G Core Network Database Schema (MySQL 8.0 Compatible)
-- Simplified for research platform - no problematic JSON indexes
-- =====================================================================

CREATE DATABASE IF NOT EXISTS `oai_db`;
USE `oai_db`;

-- =====================================================================
-- Table: AuthenticationSubscription
-- =====================================================================
CREATE TABLE IF NOT EXISTS `AuthenticationSubscription` (
  `ueid` varchar(15) NOT NULL,
  `authenticationMethod` varchar(10) NOT NULL,
  `encPermanentKey` varchar(32) NOT NULL,
  `protectionParameterId` varchar(32) DEFAULT NULL,
  `sequenceNumber` varchar(10) DEFAULT NULL,
  `authenticationManagementField` varchar(4) DEFAULT NULL,
  `algorithmIdentifier` varchar(10) DEFAULT NULL,
  `confidentialityKey` varchar(32) DEFAULT NULL,
  `integrityKey` varchar(32) DEFAULT NULL,
  PRIMARY KEY (`ueid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- Table: AccessAndMobilitySubscriptionData
-- =====================================================================
CREATE TABLE IF NOT EXISTS `AccessAndMobilitySubscriptionData` (
  `ueid` varchar(15) NOT NULL,
  `gpsi` varchar(15) DEFAULT NULL,
  `subscribedUeAmbr` varchar(50) DEFAULT NULL,
  `nssai` json DEFAULT NULL,
  `rfspIndex` int DEFAULT NULL,
  PRIMARY KEY (`ueid`),
  CONSTRAINT `fk_auth_sub` FOREIGN KEY (`ueid`) REFERENCES `AuthenticationSubscription` (`ueid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- Table: SessionManagementSubscriptionData
-- (Using varchar for singleNssai instead of JSON to avoid indexing issues)
-- =====================================================================
CREATE TABLE IF NOT EXISTS `SessionManagementSubscriptionData` (
  `ueid` varchar(15) NOT NULL,
  `singleNssai` varchar(100) NOT NULL,
  `dnnConfigurations` longtext DEFAULT NULL,
  PRIMARY KEY (`ueid`, `singleNssai`),
  CONSTRAINT `fk_access_mobility_sub` FOREIGN KEY (`ueid`) REFERENCES `AccessAndMobilitySubscriptionData` (`ueid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- Table: SmfSelectionSubscriptionData
-- =====================================================================
CREATE TABLE IF NOT EXISTS `SmfSelectionSubscriptionData` (
  `ueid` varchar(15) NOT NULL,
  `singleNssai` varchar(100) NOT NULL,
  `smfInfo` longtext DEFAULT NULL,
  PRIMARY KEY (`ueid`, `singleNssai`),
  CONSTRAINT `fk_smf_selection` FOREIGN KEY (`ueid`) REFERENCES `AccessAndMobilitySubscriptionData` (`ueid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- TEST SUBSCRIBER DATA (IMSI: 208950000000001)
-- =====================================================================

-- Authentication Data
INSERT INTO `AuthenticationSubscription` VALUES 
(
  '208950000000001',
  'EAP-AKA',
  '0C0A34601D4F07677303652C0624',
  '0C0A34601D4F07677303652C0624',
  '000000000001',
  '8004',
  '70',
  '63BFA50EE6523365FF14C1F45F88737D',
  '2A145DFF952E63D49F0F1F0771D51179'
);

-- Access & Mobility Data
INSERT INTO `AccessAndMobilitySubscriptionData` VALUES 
(
  '208950000000001',
  '111111111111',
  '{"uplink":"1000000000","downlink":"2000000000"}',
  JSON_ARRAY(JSON_OBJECT('sst',1,'sd',0xffffff), JSON_OBJECT('sst',2,'sd',0x112233)),
  1
);

-- Session Management - Slice 1 (eMBB)
INSERT INTO `SessionManagementSubscriptionData` VALUES 
(
  '208950000000001',
  '{"sst":1,"sd":"0xffffff"}',
  '{"oai":{"pduSessionTypes":"IPV4","sscModes":"0,1","5gQosProfile":{"5qi":5,"arp":{"priorityLevel":9,"preemptCap":"NOT_PREEMPT","preemptVuln":"PREEMPTIBLE"},"priorityLevel":9},"sessionAmbr":{"uplink":"1000000000","downlink":"2000000000"}}}'
);

-- Session Management - Slice 2 (URLLC)
INSERT INTO `SessionManagementSubscriptionData` VALUES 
(
  '208950000000001',
  '{"sst":2,"sd":"0x112233"}',
  '{"edge":{"pduSessionTypes":"IPV4","sscModes":"0,1","5gQosProfile":{"5qi":1,"arp":{"priorityLevel":1,"preemptCap":"PREEMPT","preemptVuln":"NOT_PREEMPTIBLE"},"priorityLevel":1},"sessionAmbr":{"uplink":"200000000","downlink":"500000000"}}}'
);

-- SMF Selection Data
INSERT INTO `SmfSelectionSubscriptionData` VALUES 
(
  '208950000000001',
  '{"sst":1,"sd":"0xffffff"}',
  '{"smfInfo":[{"plmnId":{"mcc":"208","mnc":"95"}}]}'
),
(
  '208950000000001',
  '{"sst":2,"sd":"0x112233"}',
  '{"smfInfo":[{"plmnId":{"mcc":"208","mnc":"95"}}]}'
);

-- =====================================================================
-- END OF DATABASE SCHEMA
-- =====================================================================
EOF

wc -l ~/5g-oai-research-platform/core/database/oai_db.sql
head -30 ~/5g-oai-research-platform/core/database/oai_db.sql
cd ~/5g-oai-research-platform/core
# Stop all containers
docker-compose -f docker-compose-core.yaml down -v
# Wait
sleep 5
# Remove MySQL volume to force fresh init
docker volume rm core_mysql_data 2>/dev/null || true
# Start fresh
docker-compose -f docker-compose-core.yaml up -d
# Wait 90 seconds for MySQL to initialize
echo "Initializing MySQL... (waiting 90 seconds)"
sleep 90
# Check MySQL is running
docker ps | grep oai-mysql
# Check tables exist
docker exec oai-mysql mysql -utest -ptest oai_db -e "SHOW TABLES;"
# Check test subscriber
docker exec oai-mysql mysql -utest -ptest oai_db -e "SELECT ueid FROM AuthenticationSubscription;"
# Check slices
docker exec oai-mysql mysql -utest -ptest oai_db -e "SELECT * FROM SessionManagementSubscriptionData;"
docker ps | grep oai- | grep -E "healthy|up"
docker logs oai-mysql
cd ~/5g-oai-research-platform/core/database
# Backup
cp oai_db.sql oai_db.sql.backup2
# Fix the schema - increase column sizes
cat > oai_db.sql << 'EOF'
-- =====================================================================
-- OAI 5G Core Network Database Schema (MySQL 8.0 Compatible)
-- Simplified for research platform
-- =====================================================================

CREATE DATABASE IF NOT EXISTS `oai_db`;
USE `oai_db`;

-- =====================================================================
-- Table: AuthenticationSubscription
-- =====================================================================
CREATE TABLE IF NOT EXISTS `AuthenticationSubscription` (
  `ueid` varchar(15) NOT NULL,
  `authenticationMethod` varchar(10) NOT NULL,
  `encPermanentKey` varchar(64) NOT NULL,
  `protectionParameterId` varchar(64) DEFAULT NULL,
  `sequenceNumber` varchar(32) DEFAULT NULL,
  `authenticationManagementField` varchar(10) DEFAULT NULL,
  `algorithmIdentifier` varchar(10) DEFAULT NULL,
  `confidentialityKey` varchar(64) DEFAULT NULL,
  `integrityKey` varchar(64) DEFAULT NULL,
  PRIMARY KEY (`ueid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- Table: AccessAndMobilitySubscriptionData
-- =====================================================================
CREATE TABLE IF NOT EXISTS `AccessAndMobilitySubscriptionData` (
  `ueid` varchar(15) NOT NULL,
  `gpsi` varchar(15) DEFAULT NULL,
  `subscribedUeAmbr` varchar(50) DEFAULT NULL,
  `nssai` json DEFAULT NULL,
  `rfspIndex` int DEFAULT NULL,
  PRIMARY KEY (`ueid`),
  CONSTRAINT `fk_auth_sub` FOREIGN KEY (`ueid`) REFERENCES `AuthenticationSubscription` (`ueid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- Table: SessionManagementSubscriptionData
-- =====================================================================
CREATE TABLE IF NOT EXISTS `SessionManagementSubscriptionData` (
  `ueid` varchar(15) NOT NULL,
  `singleNssai` varchar(100) NOT NULL,
  `dnnConfigurations` longtext DEFAULT NULL,
  PRIMARY KEY (`ueid`, `singleNssai`),
  CONSTRAINT `fk_access_mobility_sub` FOREIGN KEY (`ueid`) REFERENCES `AccessAndMobilitySubscriptionData` (`ueid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- Table: SmfSelectionSubscriptionData
-- =====================================================================
CREATE TABLE IF NOT EXISTS `SmfSelectionSubscriptionData` (
  `ueid` varchar(15) NOT NULL,
  `singleNssai` varchar(100) NOT NULL,
  `smfInfo` longtext DEFAULT NULL,
  PRIMARY KEY (`ueid`, `singleNssai`),
  CONSTRAINT `fk_smf_selection` FOREIGN KEY (`ueid`) REFERENCES `AccessAndMobilitySubscriptionData` (`ueid`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- =====================================================================
-- TEST SUBSCRIBER DATA
-- =====================================================================

INSERT INTO `AuthenticationSubscription` VALUES 
(
  '208950000000001',
  'EAP-AKA',
  '0C0A34601D4F07677303652C0624',
  '0C0A34601D4F07677303652C0624',
  '000000000001',
  '8004',
  '70',
  '63BFA50EE6523365FF14C1F45F88737D',
  '2A145DFF952E63D49F0F1F0771D51179'
);

INSERT INTO `AccessAndMobilitySubscriptionData` VALUES 
(
  '208950000000001',
  '111111111111',
  '{"uplink":"1000000000","downlink":"2000000000"}',
  JSON_ARRAY(JSON_OBJECT('sst',1,'sd','0xffffff'), JSON_OBJECT('sst',2,'sd','0x112233')),
  1
);

INSERT INTO `SessionManagementSubscriptionData` VALUES 
(
  '208950000000001',
  '{"sst":1,"sd":"0xffffff"}',
  '{"oai":{"pduSessionTypes":"IPV4","sscModes":"0,1","5gQosProfile":{"5qi":5,"arp":{"priorityLevel":9,"preemptCap":"NOT_PREEMPT","preemptVuln":"PREEMPTIBLE"},"priorityLevel":9},"sessionAmbr":{"uplink":"1000000000","downlink":"2000000000"}}}'
),
(
  '208950000000001',
  '{"sst":2,"sd":"0x112233"}',
  '{"edge":{"pduSessionTypes":"IPV4","sscModes":"0,1","5gQosProfile":{"5qi":1,"arp":{"priorityLevel":1,"preemptCap":"PREEMPT","preemptVuln":"NOT_PREEMPTIBLE"},"priorityLevel":1},"sessionAmbr":{"uplink":"200000000","downlink":"500000000"}}}'
);

INSERT INTO `SmfSelectionSubscriptionData` VALUES 
(
  '208950000000001',
  '{"sst":1,"sd":"0xffffff"}',
  '{"smfInfo":[{"plmnId":{"mcc":"208","mnc":"95"}}]}'
),
(
  '208950000000001',
  '{"sst":2,"sd":"0x112233"}',
  '{"smfInfo":[{"plmnId":{"mcc":"208","mnc":"95"}}]}'
);

EOF

cd ~/5g-oai-research-platform/core
# Stop containers
docker-compose -f docker-compose-core.yaml down -v
# Wait
sleep 5
# Remove MySQL volume
docker volume rm core_mysql_data 2>/dev/null || true
# Start fresh
docker-compose -f docker-compose-core.yaml up -d
# Wait 90 seconds
echo "Waiting for MySQL initialization..."
sleep 55
# Check if tables exist
docker exec oai-mysql mysql -utest -ptest oai_db -e "SHOW TABLES;"
# Check subscriber
docker exec oai-mysql mysql -utest -ptest oai_db -e "SELECT ueid FROM AuthenticationSubscription;"
# Check slices
docker exec oai-mysql mysql -utest -ptest oai_db -e "SELECT COUNT(*) FROM SessionManagementSubscriptionData;"
# Check all containers healthy
docker ps | grep oai- | grep healthy | wc -l
docker ps | grep oai- | grep -E "healthy|up"
cd ~/5g-oai-research-platform/ran
# Start gNB
docker-compose -f docker-compose-ran.yaml up -d
# Check status
docker ps | grep oai-gnb
# Find what's using port 38412
lsof -i :38412
# OR find via docker
docker ps -a | grep 38412
docker port $(docker ps -a -q) | grep 38412
cd ~/5g-oai-research-platform/ran
# Backup
cp docker-compose-ran.yaml docker-compose-ran.yaml.backup
# Edit to use different port
sed -i 's/38412:38412/38413:38412/' docker-compose-ran.yaml
# Verify change
grep "38412\|38413" docker-compose-ran.yaml
docker-compose -f docker-compose-ran.yaml up -d
cd ~/5g-oai-research-platform/ran
# Restore original compose file
cp docker-compose-ran.yaml.backup docker-compose-ran.yaml
# Stop and remove all RAN containers
docker-compose -f docker-compose-ran.yaml down -v
# Wait
sleep 5
# Remove the problematic container completely
docker rm -f oai-gnb oai-amf-check 2>/dev/null || true
# Clean up
docker system prune -f
# Now start fresh
docker-compose -f docker-compose-ran.yaml up -d
# Recreate all 4 networks
docker network create --driver bridge --subnet=172.30.0.0/16 --label=project=5g-oai-research-platform 5g-core-net
docker network create --driver bridge --subnet=172.31.0.0/16 --label=project=5g-oai-research-platform 5g-ran-net
docker network create --driver bridge --subnet=172.32.0.0/16 --label=project=5g-oai-research-platform 5g-mec-net
docker network create --driver bridge --subnet=172.33.0.0/16 --label=project=5g-oai-research-platform 5g-ric-net
# Verify
docker network ls | grep 5g-
# Now try RAN again
cd ~/5g-oai-research-platform/ran
docker-compose -f docker-compose-ran.yaml up -d
# Wait 90 seconds
sleep 30
# Check
docker ps | grep oai-gnb
cd ~/5g-oai-research-platform/ran
# Edit docker-compose-ran.yaml
nano docker-compose-ran.yaml
cd ~/5g-oai-research-platform/ran
# Stop if running
docker-compose -f docker-compose-ran.yaml down 2>/dev/null || true
# Wait
sleep 3
# Start
docker-compose -f docker-compose-ran.yaml up -d
# Wait 90 seconds
sleep 30
# Check
docker ps | grep oai-gnb
docker logs oai-gnb | tail -20
cd ~/5g-oai-research-platform/ran
# Create configs directory if it doesn't exist
mkdir -p configs
# Create minimal gNB configuration
cat > configs/gnb.yaml << 'EOF'
gNBs:
  - gnb_id: 1
    gnb_name: 'oai-gnb'
    cell_type: 'nr_macro_indoor'
    nr_operating_mode: 'sa'
    
    mcc: 208
    mnc: 95
    mnc_length: 2
    tac: 1
    
    nssai_sst0: 1
    nssai_sd0: 0xffffff
    
    amf:
      amf_ip_address: '172.30.0.100'
      amf_port: 38412
    
    nr_cell_list:
      - cell_type: 'nr_macro'
        cell_id: 1
        band: 78
        dl_absoluteFrequencyPointA: 641280
        dl_frequencyBand: 78
        dl_gridOpeningOffsetSSB: 0
        dl_initialDownlinkBWP_common_scs_SpecificCarrierList:
          - offsetToCarrier: 0
            subcarrierSpacing: 30
            carrierBandwidth: 106
        ul_initialUplinkBWP_common_scs_SpecificCarrierList:
          - offsetToCarrier: 0
            subcarrierSpacing: 30
            carrierBandwidth: 106

EOF

# Edit the compose file
cat > docker-compose-ran.yaml << 'EOF'
version: '3.8'

services:

  oai-gnb:
    container_name: oai-gnb
    image: oaisoftwarealliance/oai-gnb:2024.w40
    platform: linux/amd64
    privileged: true
    volumes:
      # Mount configuration file
      - ./configs/gnb.yaml:/opt/oai-gnb/etc/gnb.yaml:ro
      # Mount logs directory
      - ./logs:/opt/oai-gnb/logs
    environment:
      USE_SA_TDD_MONO: 'yes'
      GNBNAME: 'oai-gnb'
      NBCORES: '4'
      NB_UE: '4'
      SYNC_REF: 'internal'
      MCC: '208'
      MNC: '95'
      TAC: '1'
      NSSAI_SST_0: '1'
      NSSAI_SD_0: '0xffffff'
      NSSAI_SST_1: '2'
      NSSAI_SD_1: '0x112233'
      ENABLE_E2: 'no'
      E2_AGENT_IPADDR: 'oai-gnb'
      E2_AGENT_PORT: '36422'
      NGA_IF_NAME: 'eth0'
      NGA_IP_ADDRESS: '172.31.0.10'
      NGU_IF_NAME: 'eth0'
      NGU_IP_ADDRESS: '172.31.0.10'
      AMF_IP_ADDRESS: '172.30.0.100'
      NFAPI_MODE: 'VNF'
    ports:
      - "9091:9091/tcp"
    networks:
      5g_ran_net:
        ipv4_address: 172.31.0.10
      5g_core_net:
    depends_on:
      - oai-amf-wait
    labels:
      project: 5g-oai-research-platform
      component: ran
      service: gnb
    healthcheck:
      test: ["CMD", "ps", "aux"]
      interval: 30s
      timeout: 10s
      retries: 3

  oai-amf-wait:
    container_name: oai-amf-check
    image: busybox:latest
    networks:
      5g_core_net:
    command: sh -c "echo 'Waiting for core network...' && sleep 5"
    labels:
      project: 5g-oai-research-platform
      component: ran
      service: helper

networks:
  5g_ran_net:
    external: true
    name: 5g-ran-net
  5g_core_net:
    external: true
    name: 5g-core-net

EOF

cd ~/5g-oai-research-platform/ran
# Stop
docker-compose -f docker-compose-ran.yaml down 2>/dev/null || true
# Wait
sleep 3
# Start
docker-compose -f docker-compose-ran.yaml up -d
# Wait 60 seconds
sleep 30
# Check logs
docker logs oai-gnb | tail -30
cd ~/5g-oai-research-platform/ran
# Create proper gNB configuration
cat > configs/gnb.yaml << 'EOF'
gNBs:
  - gnb_id: 1
    gnb_name: "oai-gnb"
    cell_type: "nr_macro_indoor"
    nr_operating_mode: "sa"
    
    # PLMN
    mcc: 208
    mnc: 95
    mnc_length: 2
    tac: 1
    nssai_sst0: 1
    nssai_sd0: "0xffffff"
    
    # AMF Connection
    amf:
      amf_ip_address: "172.30.0.100"
      amf_port: 38412
    
    # NR Cell Configuration
    nr_cell_list:
      - cell_type: "nr_macro"
        cell_id: 1
        band: 78
        dl_absoluteFrequencyPointA: 641280
        dl_frequencyBand: 78
        dl_gridOpeningOffsetSSB: 0
        
        # DL Initial Downlink BWP
        dl_initialDownlinkBWP_common_cp_AdditionalPDCP_Parameters: null
        dl_initialDownlinkBWP_common_pdcch_ConfigCommon: null
        dl_initialDownlinkBWP_common_pdsch_ConfigCommon: null
        dl_initialDownlinkBWP_common_rach_ConfigCommon: null
        
        dl_initialDownlinkBWP_common_scs_SpecificCarrierList:
          - offsetToCarrier: 0
            subcarrierSpacing: 30
            carrierBandwidth: 106
        
        # UL Initial Uplink BWP
        ul_initialUplinkBWP_common_pusch_ConfigCommon: null
        ul_initialUplinkBWP_common_rach_ConfigCommon: null
        
        ul_initialUplinkBWP_common_scs_SpecificCarrierList:
          - offsetToCarrier: 0
            subcarrierSpacing: 30
            carrierBandwidth: 106
        
        # PDCCH and PDSCH
        pdcch_ConfigCommon: null
        pdsch_TimeDomainAllocationList: null
        pusch_TimeDomainAllocationList: null
        pucch_ConfigCommon: null
        
        # UL Power Control
        uplinkPowerControl: null

EOF

cd ~/5g-oai-research-platform/ran
# Stop
docker-compose -f docker-compose-ran.yaml down
# Wait
sleep 5
# Start
docker-compose -f docker-compose-ran.yaml up -d
# Wait 90 seconds for startup
sleep 30
# Check if running
docker ps | grep oai-gnb
# Check logs
docker logs oai-gnb 2>&1 | tail -50 | grep -E "gNB|started|connected|error|assert"
exit
cd
ls
tree
cd ~/5g-oai-research-platform
find . -type d
ls core/database/oai_db.sql
ls ran/docker-compose-ran.yaml
ls ran/configs/gnb.yaml
ls core/docker-compose-core.yaml
docker network create --driver bridge --subnet=172.30.0.0/16 --label=project=5g-oai-research-platform 5g-core-net
docker network create --driver bridge --subnet=172.31.0.0/16 --label=project=5g-oai-research-platform 5g-ran-net
docker network create --driver bridge --subnet=172.32.0.0/16 --label=project=5g-oai-research-platform 5g-mec-net
docker network create --driver bridge --subnet=172.33.0.0/16 --label=project=5g-oai-research-platform 5g-ric-net
docker network ls | grep 5g-
docker images | grep oai
docker images | grep mysql
cd ~/5g-oai-research-platform/core
docker-compose -f docker-compose-core.yaml up -d
# Wait for core to initialize
sleep 60
docker ps | grep oai-
cd ~/5g-oai-research-platform/ran
docker-compose -f docker-compose-ran.yaml up -d
# Wait for gNB to initialize
sleep 90
docker ps | grep oai-gnb
docker logs oai-gnb | tail -50
cd ~/5g-oai-research-platform/ran
ls -l
ls
cd ..
ls
cd ran
cd ..
cd core
ls
cd database
ls
cd ..
cd ran
ls
cd ..
ms
ls
cd ..
ls
cd 5g-mec-research-platform/
ls
cd ran
ls
cd ..
cd core
ls
cd ..
cd 5g-oai-research-platform/
cd ran
cat > gnb_config.yaml << 'EOF'
gNBs:
  - gnb_id: 1
    gnb_name: "oai-gnb"
    mcc: 208
    mnc: 95
    mnc_length: 2
    tac: 1
    amf_ip_address: "172.30.0.100"
    amf_port: 38412
    nssai_sst0: 1
    nssai_sd0: "0xffffff"
    nssai_sst1: 2
    nssai_sd1: "0x112233"
    nr_cell_list:
      - cell_type: "nr_macro"
        cell_id: 1
        band: 78
        dl_absoluteFrequencyPointA: 641280
        dl_frequencyBand: 78
        dl_gridOpeningOffsetSSB: 0
        dl_initialDownlinkBWP_common_scs_SpecificCarrierList:
          - offsetToCarrier: 0
            subcarrierSpacing: 30
            carrierBandwidth: 106
        ul_initialUplinkBWP_common_scs_SpecificCarrierList:
          - offsetToCarrier: 0
            subcarrierSpacing: 30
            carrierBandwidth: 106
EOF

nano docker-compose-ran.yaml
docker-compose -f docker-compose-ran.yaml down
sleep 3
docker-compose -f docker-compose-ran.yaml up -d
sleep 50
docker logs oai-gnb | tail -40
ls
cd configs
ls
cd ..
nano docker-compose-ran.yaml
cd
cd /5g-oai-research-platform/ran
cd 5g-oai-research-platform/ran
ls
cd logs
ls
cd ue/
ls
cd ..
docker exec -it oai-gnb cat /opt/oai-gnb/etc/gnb.yaml
ls -lh configs/gnb.yaml
cat configs/gnb.yaml
grep "volumes:" -A 4 docker-compose-ran.yaml
docker exec -it oai-gnb cat /opt/oai-gnb/etc/gnb.yaml
docker-compose -f docker-compose-ran.yaml down
sleep 2
docker-compose -f docker-compose-ran.yaml up -d
sleep 30
docker logs oai-gnb | tail -40
docker exec -it oai-gnb cat /opt/oai-gnb/etc/gnb.yaml
ls
nano docker-compose-ran.yaml
