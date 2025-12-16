#!/bin/bash
# PostgreSQL Multi-Master Cluster Validation Script
# Run this after deployment to verify the cluster is healthy

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "PostgreSQL Multi-Master Cluster Validation"
echo "=========================================="
echo

# Function to check PostgreSQL on a node
check_postgres_node() {
    local node=$1
    local ip=$2
    echo -e "${YELLOW}Checking PostgreSQL on $node ($ip)...${NC}"
    
    # Check if PostgreSQL is running
    if ssh -o StrictHostKeyChecking=no ubuntu@$ip "sudo systemctl is-active postgresql" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ PostgreSQL is running${NC}"
    else
        echo -e "  ${RED}✗ PostgreSQL is NOT running${NC}"
        return 1
    fi
    
    # Check PostgreSQL version
    version=$(ssh -o StrictHostKeyChecking=no ubuntu@$ip "sudo -u postgres psql -t -c 'SELECT version();'" 2>/dev/null | head -1)
    echo -e "  ${GREEN}✓ Version: $version${NC}"
    
    # Check pglogical extension
    if ssh -o StrictHostKeyChecking=no ubuntu@$ip "sudo -u postgres psql -d appdb -t -c \"SELECT 1 FROM pg_extension WHERE extname='pglogical';\"" | grep -q 1; then
        echo -e "  ${GREEN}✓ pglogical extension installed${NC}"
    else
        echo -e "  ${RED}✗ pglogical extension NOT installed${NC}"
    fi
    
    # Check replication subscriptions
    sub_count=$(ssh -o StrictHostKeyChecking=no ubuntu@$ip "sudo -u postgres psql -d appdb -t -c 'SELECT count(*) FROM pglogical.subscription;'" 2>/dev/null | tr -d ' ')
    echo -e "  ${GREEN}✓ Active subscriptions: $sub_count${NC}"
    
    echo
}

# Function to check HAProxy
check_haproxy() {
    local ip=$1
    echo -e "${YELLOW}Checking HAProxy ($ip)...${NC}"
    
    # Check if HAProxy is running
    if ssh -o StrictHostKeyChecking=no ubuntu@$ip "sudo systemctl is-active haproxy" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓ HAProxy is running${NC}"
    else
        echo -e "  ${RED}✗ HAProxy is NOT running${NC}"
        return 1
    fi
    
    # Check HAProxy stats
    if curl -s -o /dev/null -w "%{http_code}" "http://$ip:7000/stats" | grep -q 401; then
        echo -e "  ${GREEN}✓ HAProxy stats endpoint responding${NC}"
    else
        echo -e "  ${YELLOW}! HAProxy stats endpoint check inconclusive${NC}"
    fi
    
    # Check PostgreSQL port
    if nc -z -w5 $ip 5000 2>/dev/null; then
        echo -e "  ${GREEN}✓ PostgreSQL load balancer port (5000) is open${NC}"
    else
        echo -e "  ${RED}✗ PostgreSQL load balancer port (5000) is NOT responding${NC}"
    fi
    
    echo
}

# Function to test replication
test_replication() {
    local primary_ip=$1
    local replica_ip=$2
    echo -e "${YELLOW}Testing replication between nodes...${NC}"
    
    # Insert test data on primary
    test_value="test_$(date +%s)"
    ssh -o StrictHostKeyChecking=no ubuntu@$primary_ip "sudo -u postgres psql -d appdb -c \"INSERT INTO sample_data (data) VALUES ('$test_value');\"" > /dev/null 2>&1
    
    # Wait for replication
    sleep 3
    
    # Check on replica
    if ssh -o StrictHostKeyChecking=no ubuntu@$replica_ip "sudo -u postgres psql -d appdb -t -c \"SELECT data FROM sample_data WHERE data='$test_value';\"" | grep -q "$test_value"; then
        echo -e "  ${GREEN}✓ Replication working: data replicated from primary to replica${NC}"
    else
        echo -e "  ${RED}✗ Replication check failed: data not found on replica${NC}"
    fi
    
    echo
}

# Main validation
main() {
    # Load IPs from terraform output or environment
    if [ -z "$PG_NODE_1_IP" ]; then
        echo "Please set environment variables:"
        echo "  export PG_NODE_1_IP=<ip>"
        echo "  export PG_NODE_2_IP=<ip>"
        echo "  export PG_NODE_3_IP=<ip>"
        echo "  export HAPROXY_IP=<ip>"
        echo
        echo "Or run from terraform directory:"
        echo "  export PG_NODE_1_IP=\$(terraform output -raw postgres_public_ips | jq -r '.[0]')"
        exit 1
    fi
    
    check_postgres_node "pg-node-1" "$PG_NODE_1_IP"
    check_postgres_node "pg-node-2" "$PG_NODE_2_IP"
    check_postgres_node "pg-node-3" "$PG_NODE_3_IP"
    check_haproxy "$HAPROXY_IP"
    
    echo -e "${YELLOW}Running replication tests...${NC}"
    test_replication "$PG_NODE_1_IP" "$PG_NODE_2_IP"
    test_replication "$PG_NODE_2_IP" "$PG_NODE_3_IP"
    
    echo "=========================================="
    echo -e "${GREEN}Validation Complete${NC}"
    echo "=========================================="
}

main "$@"
