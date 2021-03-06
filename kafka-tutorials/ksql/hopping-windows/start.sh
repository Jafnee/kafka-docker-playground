#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../../scripts/utils.sh
verify_installed "docker-compose"

docker-compose down -v
docker-compose up -d

log "Invoke manual steps"
timeout 120 docker exec -i ksqldb-cli bash -c 'echo -e "\n\n⏳ Waiting for ksqlDB to be available before launching CLI\n"; while [ $(curl -s -o /dev/null -w %{http_code} http://ksqldb-server:8088/) -eq 000 ] ; do echo -e $(date) "KSQL Server HTTP state: " $(curl -s -o /dev/null -w %{http_code} http:/ksqldb-server:8088/) " (waiting for 200)" ; sleep 10 ; done; ksql http://ksqldb-server:8088' << EOF

CREATE STREAM TEMPERATURE_READINGS (ID VARCHAR, TIMESTAMP VARCHAR, READING BIGINT)
    WITH (KAFKA_TOPIC = 'TEMPERATURE_READINGS',
          VALUE_FORMAT = 'JSON',
          TIMESTAMP = 'TIMESTAMP',
          TIMESTAMP_FORMAT = 'yyyy-MM-dd HH:mm:ss',
          PARTITIONS = 1, REPLICAS = 1);

INSERT INTO TEMPERATURE_READINGS (ID, TIMESTAMP, READING) VALUES ('1', '2020-01-15 02:15:30', 55);
INSERT INTO TEMPERATURE_READINGS (ID, TIMESTAMP, READING) VALUES ('1', '2020-01-15 02:20:30', 50);
INSERT INTO TEMPERATURE_READINGS (ID, TIMESTAMP, READING) VALUES ('1', '2020-01-15 02:25:30', 45);
INSERT INTO TEMPERATURE_READINGS (ID, TIMESTAMP, READING) VALUES ('1', '2020-01-15 02:30:30', 40);
INSERT INTO TEMPERATURE_READINGS (ID, TIMESTAMP, READING) VALUES ('1', '2020-01-15 02:35:30', 45);
INSERT INTO TEMPERATURE_READINGS (ID, TIMESTAMP, READING) VALUES ('1', '2020-01-15 02:40:30', 50);
INSERT INTO TEMPERATURE_READINGS (ID, TIMESTAMP, READING) VALUES ('1', '2020-01-15 02:45:30', 55);
INSERT INTO TEMPERATURE_READINGS (ID, TIMESTAMP, READING) VALUES ('1', '2020-01-15 02:50:30', 60);

SET 'auto.offset.reset' = 'earliest';

SELECT
    ID,
    TIMESTAMPTOSTRING(WINDOWSTART, 'HH:mm:ss') AS START_PERIOD,
    TIMESTAMPTOSTRING(WINDOWEND, 'HH:mm:ss') AS END_PERIOD,
    SUM(READING)/COUNT(READING) AS AVG_READING
FROM TEMPERATURE_READINGS
WINDOW HOPPING (SIZE 10 MINUTES, ADVANCE BY 5 MINUTES)
GROUP BY ID HAVING SUM(READING)/COUNT(READING) < 45 EMIT CHANGES LIMIT 3;

CREATE TABLE TRIGGERED_ALERTS AS
    SELECT
        ID,
        TIMESTAMPTOSTRING(WINDOWSTART, 'HH:mm:ss') AS START_PERIOD,
        TIMESTAMPTOSTRING(WINDOWEND, 'HH:mm:ss') AS END_PERIOD,
        SUM(READING)/COUNT(READING) AS AVG_READING
    FROM TEMPERATURE_READINGS
    WINDOW HOPPING (SIZE 10 MINUTES, ADVANCE BY 5 MINUTES)
    GROUP BY ID HAVING SUM(READING)/COUNT(READING) < 45;

CREATE STREAM RAW_ALERTS (ID VARCHAR, START_PERIOD VARCHAR, END_PERIOD VARCHAR, AVG_READING BIGINT)
    WITH (KAFKA_TOPIC = 'TRIGGERED_ALERTS',
          VALUE_FORMAT = 'JSON');

CREATE STREAM ALERTS AS
    SELECT
        ID,
        START_PERIOD,
        END_PERIOD,
        AVG_READING
    FROM RAW_ALERTS
    PARTITION BY ID;

SELECT
    ID,
    START_PERIOD,
    END_PERIOD,
    AVG_READING
FROM ALERTS
EMIT CHANGES
LIMIT 3;

PRINT 'ALERTS' FROM BEGINNING LIMIT 3;

EOF


log "Invoke the tests"
docker exec ksqldb-cli ksql-test-runner -i /opt/app/test/input.json -s opt/app/src/statements.sql -o /opt/app/test/output.json | grep "Test passed!"
