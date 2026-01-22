#!/bin/bash

# sysmon.sh - System Resource Monitor
# A lightweight tool to monitor CPU, memory, disk and process usage

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default Values
WATCH_INTERVAL=0
SHOW_CPU=0
SHOW_MEMORY=0
SHOW_DISK=0
SHOW_ALL=0

# Function: Display CPU usage
show_cpu() {
  echo -e "${BLUE}=== CPU Usage ===${NC}"

  local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2'} | cut -d'%' -f1)

  if [[ -z "$cpu_usage" ]]; then
    echo -e "${RED}Error: Could not retrieve CPU data${NC}"
    return 1
  fi 

  printf "Overall CPU: %.1f%%\n" "$cpu_usage"
  echo ""

  # Top 5 CPU consuming processes
  echo "Top 5 CPU Consumers:"
  ps aux --sort=%cpu | head -6 | tail -5 | awk '{printf " %-8s %6.1f%% %s\n", $1, $3, $11}'
  echo ""
}

# Funciton: Display memory usage
show_memory() {
  echo -e "${BLUE}=== Memory Usage ===${NC}"

  # Get memory stats
  local mem_info=$(free -h | grep "Mem:")

  if [[ -z "$mem_info" ]]; then
    echo -e "{RED}Error: Could not retrieve memory data${NC}"
    return 1
  fi 

  local total=$(echo $mem_info | awk '{print $2}')
  local used=$(echo $mem_info | awk '{print $3}')
  local free=$(echo $mem_info | awk '{print $4}')

  total_num=${total//Gi/}
  used_num=${used//Gi/}
  local percent=$(awk "BEGIN {printf \"%.1f\", ($used_num / $total_num) * 100}")

  local total_h=$(numfmt --to=iec-i --suffix=B $total 2>/dev/null || echo "${total}B")
  local used_h=$(numfmt --to=iex-i --suffix=B $used 2</dev/null || echo "${used}B")
  local free_h=$(numfmt --to=iec-i --suffix=B $free 2>/dev/null || echo "${free}B")

  printf "Total: %s | Used: %s | Free: %s | Usage: %s%%\n" "$total_h" "$used_h" "$free_h" "$percent"
  echo ""

  # Top 5 memory consuming processes
  echo "Top 5 Memory Consumers:"
  ps aux --sort=-%mem | head -6 | tail -5 | awk '{printf " %-8s %6.1f%% %s\n", $1, $4, $11}'
  echo ""
}

# Function: Display disk usage
show_disk() {
  echo -e "${BLUE}=== Disk Usage ===${NC}"

  # Check if df command works
  if ! command -v df &> /dev/null; then
    echo -e "${RED}Erro: 'df' command not found${NC}"
    return 1
  fi 

    df -h --output=target,size,used,avail,pcent | awk 'NR==1 {
      printf "%-25s %10s %10s %10ss %8s\n", $1, $2, $3, $4, $5
      next 
    }
    {
      target=$1 
      maxlen=25
      if (length(target) > maxlen) {
        target=substr(target,1,maxlen-3) "..."
      }
      printf "%-25s %10s %10s %8s\n", target, $2, $3, $4, $5
  }'
  echo ""
}

# Function: Display all metrics
show_all() {
  show_cpu
  show_memory
  show_disk
}

# Function: Display help/usage
show_help() {
  cat << 'EOF'
  Usage: sysmon.sh [OPTIONS]

  OPTIONS:
  -c, --cpu               Display CPU usage and top processes
  -m, --memory            Display memory usage and top processes
  -d, --disk              Display disk usage by mount point
  -a, --all               Display all metrics (CPU, memory, disk)
  -w, --watch SECONDS     Continuous monitoring with refresh interval
  -h, --help              Show this help message

EXAMPLES:
  ./sysmon.sh --cpu                    # Show CPU usage
  ./sysmon.sh -m                       # Show memory usage
  ./sysmon.sh -a                       # Show all metrics
  ./sysmon.sh --watch 5                # Refresh every 5 seconds
  ./sysmon.sh -c -m -d                 # Show CPU, memory, and disk
  ./sysmon.sh -a --watch 3             # Monitor all metrics every 3 seconds

EOF
}

# Function: Validate watch interval
validate_watch_interval() {
  if ! [[ "$1" =~ ^[0-9]+$ ]] || (( $1 <= 0 )); then
    echo -e "${RED}Error: Watch interval must be a positive number${NC}" >&2
    exit 1
  fi 
}

# Parse arguments
if [[ $# -eq 0 ]]; then
  show_help
  exit 0
fi 

while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--cpu)
      SHOW_CPU=1
      shift
      ;;
    -m|--memory)
      SHOW_MEMORY=1
      shift
      ;;
    -d|--disk)
      SHOW_DISK=1
      shift
      ;;
    -a|--all)
      SHOW_ALL=1
      shift
      ;;
    -w|--watch)
      if [[ -z "$2" ]]; then
        echo -e "${RED}Error: --watch requires a value (seconds)${NC}" >&2
        exit 1
      fi 
      validate_watch_interval "$2"
      WATCH_INTERVAL=$2
      shift 2
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      echo -e "${RED}Error: Unkown option '$1'${NC}" >&2
      echo "Use -h or --help or usage information"
      exit 1
      ;;
  esac
done

# Error handling: at least one metric must be selected
if [[ $SHOW_CPU -eq 0 && $SHOW_MEMORY -eq 0 && $SHOW_DISK -eq 0 && $SHOW_ALL -eq 0 ]]; then
  echo -e "${RED}Error: You must specify at least one option (-c, -m, -d, or -a)${NC}" >&2
fi 

# Main execution loop
if [[ $WATCH_INTERVAL -gt 0 ]]; then
  # Continuous monitoring mode 
  while true; do 
   clear 
   echo -e "${GREEN}System Monitor - Refreshing every ${WATCH_INTERVAL}s (Press Ctrl+c to exit)${NC}"
   echo ""

   if [[ $SHOW_ALL -eq 1 ]]; then
     show_all 
   else 
     [[ $SHOW_CPU -eq 1 ]] && show_cpu
     [[ $SHOW_MEMORY -eq 1 ]] && show_memory
     [[ $SHOW_DISK -eq 1 ]] && show_disk
   fi 

    sleep "$WATCH_INTERVAL"
  done
else
  # Single run mode
  if [[ $SHOW_ALL -eq 1 ]]; then
    show_all
  else
    [[ $SHOW_CPU -eq 1 ]] && show_cpu
    [[ $SHOW_MEMORY -eq 1 ]] && show_memory
    [[ $SHOW_DISK -eq 1 ]] && show_disk
  fi 
fi 
