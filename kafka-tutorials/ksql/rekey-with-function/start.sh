#!/bin/bash

set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../../scripts/utils.sh
verify_installed "docker-compose"

docker-compose down -v
docker-compose up -d

# notice the "EOF" -> https://unix.stackexchange.com/a/490970
log "Invoke manual steps"
timeout 120 docker exec -i ksqldb-cli bash -c 'echo -e "\n\n⏳ Waiting for ksqlDB to be available before launching CLI\n"; while [ $(curl -s -o /dev/null -w %{http_code} http://ksqldb-server:8088/) -eq 000 ] ; do echo -e $(date) "KSQL Server HTTP state: " $(curl -s -o /dev/null -w %{http_code} http:/ksqldb-server:8088/) " (waiting for 200)" ; sleep 10 ; done; ksql http://ksqldb-server:8088' << "EOF"

SHOW FUNCTIONS;
DESCRIBE FUNCTION REGEXREPLACE;

CREATE STREAM customers (rowkey int key, firstname string, lastname string, phonenumber string)
  WITH (kafka_topic='customers',
        partitions=2,
        value_format = 'avro');

INSERT INTO customers (rowkey, firstname, lastname, phonenumber) VALUES (1, 'Sleve', 'McDichael', '(360) 555-8909');
INSERT INTO customers (rowkey, firstname, lastname, phonenumber) VALUES (2, 'Onson', 'Sweemey', '206-555-1272');
INSERT INTO customers (rowkey, firstname, lastname, phonenumber) VALUES (3, 'Darryl', 'Archideld', '425.555.6940');
INSERT INTO customers (rowkey, firstname, lastname, phonenumber) VALUES (4, 'Anatoli', 'Smorin', '509.555.8033');
INSERT INTO customers (rowkey, firstname, lastname, phonenumber) VALUES (5, 'Rey', 'McSriff', '360 555 6952');
INSERT INTO customers (rowkey, firstname, lastname, phonenumber) VALUES (6, 'Glenallen', 'Mixon', '(253) 555-7050');
INSERT INTO customers (rowkey, firstname, lastname, phonenumber) VALUES (7, 'Mario', 'McRlwain', '360 555 7598');
INSERT INTO customers (rowkey, firstname, lastname, phonenumber) VALUES (8, 'Kevin', 'Nogilny', '206.555.8090');
INSERT INTO customers (rowkey, firstname, lastname, phonenumber) VALUES (9, 'Tony', 'Smehrik', '425-555-7926');
INSERT INTO customers (rowkey, firstname, lastname, phonenumber) VALUES (10, 'Bobson', 'Dugnutt', '509.555.8795');

SET 'auto.offset.reset' = 'earliest';

SELECT ROWKEY, FIRSTNAME, LASTNAME, PHONENUMBER, REGEXREPLACE(phonenumber, '\\(?(\\d{3}).*', '$1') as area_code
FROM CUSTOMERS
EMIT CHANGES
LIMIT 10;

CREATE STREAM customers_with_area_code AS
    SELECT
      customers.rowkey as id,
      firstname,
      lastname,
      phonenumber,
      REGEXREPLACE(phonenumber, '\\(?(\\d{3}).*', '$1') as area_code
    FROM customers;

CREATE STREAM customers_by_area_code
  WITH (KAFKA_TOPIC='customers_by_area_code') AS
    SELECT * from customers_with_area_code
    PARTITION BY area_code
    EMIT CHANGES;

SELECT ROWKEY, FIRSTNAME, LASTNAME, AREA_CODE, PHONENUMBER
FROM CUSTOMERS_BY_AREA_CODE
EMIT CHANGES
LIMIT 10;

EOF
