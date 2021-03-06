#!/bin/bash

if [ -z "$ES_USER" ] || [ -z "$ES_PASSWORD" ]
then
    curl -sS "http://$ES_HOST:$ES_PORT/_cluster/health?wait_for_status=yellow"
else
    curl -u "$ES_USER:$ES_PASSWORD" -sS "http://$ES_HOST:$ES_PORT/_cluster/health?wait_for_status=yellow"
fi

if [ $? -ne 0 ]; then
    echo
    echo "${ES_HOST}:${ES_PORT} is unavaliable\n"
    exit -1
fi
echo
echo "Connect ElasticSearch(http://$ES_HOST:$ES_PORT) successfully!"

# prepare environment variables
sed -i -- 's/not-set/no/g' /data/moloch/bin/Configure
if [ -z "$ES_USER" ] || [ -z "$ES_PASSWORD" ]
then
    export MOLOCH_ELASTICSEARCH="http://$ES_HOST:$ES_PORT"
else
    echo "Using a ACL enabled elasticsearch!"
    export MOLOCH_ELASTICSEARCH="http://$ES_USER:$ES_PASSWORD@$ES_HOST:$ES_PORT"
    echo "$MOLOCH_ELASTICSEARCH"
fi


# Configure Moloch to Run
if [ ! -f /data/configured ]; then
    touch /data/configured
    /data/moloch/bin/Configure
fi

# Give option to init ElasticSearch
if [ "$INITALIZEDB" = "true" ] ; then
    echo INIT | /data/moloch/db/db.pl http://$ES_HOST:$ES_PORT init
    /data/moloch/bin/moloch_add_user.sh admin "Admin User" $MOLOCH_PASSWORD --admin
fi

# Give option to wipe ElasticSearch
if [ "$WIPEDB" = "true" ]; then
    /data/wipemoloch.sh
fi

echo "Look at log files for errors"
echo "  /data/moloch/logs/viewer.log"
echo "  /data/moloch/logs/capture.log"
echo "Visit http://127.0.0.1:8005 with your favorite browser."
echo "  user: admin"
echo "  password: $MOLOCH_PASSWORD"

if [ "$CAPTURE" = "on" ]; then
    echo "Launch capture..."
    # Turn some network interface options off, otherwise capture program would not function
    /bin/bash /data/moloch/bin/moloch_config_interfaces.sh
    /data/moloch/bin/moloch-capture |tee -a /data/moloch/logs/capture.log 2>&1
elif [ "$VIEWER" = "on" ]; then
    echo "Launch viewer..."
    /bin/sh -c 'cd /data/moloch/viewer; /data/moloch/bin/node viewer.js -c /data/moloch/etc/config.ini | tee -a /data/moloch/logs/viewer.log 2>&1' 
fi 
