#!/usr/bin/env bash
# Prerequisites:
# - docker-compose and jq (https://stedolan.github.io/jq/download/)
# - export DOCKER_HOST accordingly
# - performance-monitor is under $HOME/projects/performance-monitor
#   (change in conf.sh if needed)
#   performance-monitor must be configured in $PERF_DIR/src/conf how to
#   reach the docker daemon and to watch the "nodered" container.
# - images generated by performance-monitor are under $PERF_DIR/img
# - Output files are under /tmp/data
#   (change in conf.sh if needed)
# - take_results assumes that `ssh $PI_HOST` succeeds; PI_HOST defaults to agilegw
#   (export PI_HOST accordingly and modify ~/.ssh/config if needed)
# - submit_jobsn assumes that the "local" nodered URL is http://resin.local:1880;
#   override with ADDR env var.
set -u
set -e

source conf.sh

if [ $# -lt 2 ]; then
  echo "Usage: $0 <paralleljobs> <totaljobs> [<suffix>]"
  echo "  suffix defaults to 1"
  exit 1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PARALLEL=$1
TOTAL=$2
SUFFIX=${3:-1}
DATA_DIR="$DATA_ROOT_DIR"/$PARALLEL-$TOTAL-$SUFFIX

set -x

cd "$DIR/$ARCH" && docker-compose up -d

docker-compose logs > /tmp/node-red.log 2>&1 &
sleep 10

cd $PERF_DIR
node src/index.js &>/tmp/performance-monitor.log &
PERF_PID=$!

echo "performance-monitor PID=$PERF_PID"

sleep 5

cd $DIR

./submit_jobsn.sh $PARALLEL $TOTAL

sleep 5

kill -SIGINT $PERF_PID

cd "$DIR/$ARCH" && docker-compose down

cd $DIR
./take_results.sh "$DATA_DIR"

set +e          # temporal set -e disable
ps $PERF_PID
while [ $? -eq 0 ]; do
    sleep 1
    ps $PERF_PID
done
set -e

mv $PERF_DIR/img/* "$DATA_DIR"

cd "$DATA_DIR"

"$DIR"/graphs/process.sh monitor.json *parallel*.json

set +x
