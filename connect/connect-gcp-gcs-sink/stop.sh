#!/bin/bash


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"
source ${DIR}/../../scripts/utils.sh

${DIR}/../../environment/plaintext/stop.sh "${PWD}/docker-compose.plaintext.yml"
${DIR}/../../environment/sasl-ssl/stop.sh "${PWD}/docker-compose.sasl-ssl.yml"
${DIR}/../../environment/2way-ssl/stop.sh "${PWD}/docker-compose.2way-ssl.yml"
${DIR}/../../environment/kerberos/stop.sh "${PWD}/docker-compose.kerberos.yml"
${DIR}/../../environment/ldap_authorizer_sasl_plain/stop.sh "${PWD}/docker-compose.ldap-authorizer-sasl-plain.yml"
${DIR}/../../environment/rbac-sasl-plain/stop.sh "${PWD}/docker-compose.rbac-sasl-plain.yml"