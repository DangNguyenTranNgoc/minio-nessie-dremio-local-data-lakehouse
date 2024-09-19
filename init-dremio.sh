#!/bin/bash
source .env

TOKEN=""
NESSIE_SOURCE_CONFIG=""
ERROR_MESSAGE=""

login() {
    local username=$1
    local password=$2
    local authen=$(curl -s -X POST 'http://localhost:9047/apiv2/login' \
                        --header 'Content-Type: application/json' \
                        --data-raw "{
                            \"userName\": \"${DREMIO_ADMIN_USER}\",
                            \"password\": \"${DREMIO_ADMIN_PASSWORD}\"
                        }")
    if [ $? -ne 0 ]; then
        echo "[ERROR] Something went wrong when try to login"
        return 1
    fi
    if [[ ! -z $(extract_value_from_json "errorMessage" "${authen}") ]]; then
        echo "[ERROR] Something went wrong when try to login: ${authen}"
        return 1
    else
        echo "[INFO]  Login successfully: ${authen}"
        TOKEN=_dremio$(grep -oP '(?<="token":")[^"]*' <<< "${authen}")
    fi
}

extract_value_from_json() {
    local key=$1
    local json=$2
    value=$(grep -oP "(?<=\"${key}\":\")[^\"]*" <<< "${json}")
    if [[ ! -z "${value}" ]]; then
        echo "${value}"
    else
        echo ""
    fi
}

check_nessie_catalog_config() {
    local config=$1
    # Check respone
    # "entityType":"source"
    if [[ ! $(extract_value_from_json "entityType" "${config}") == "source" ]]; then
        echo "[ERROR] Config is wrong or not Nessie source"
        return 1
    fi
    # "awsAccessKey":"minio" => AWS_ACCESS_KEY
    if [[ ! $(extract_value_from_json "awsAccessKey" "${config}") == "${AWS_ACCESS_KEY}" ]]; then
        echo "[ERROR] Config [awsAccessKey] is wrong or not Nessie source"
        return 1
    fi
    # "awsRootPath":"warehouse" => WAREHOUSE#*s3a://
    if [[ ! $(extract_value_from_json "awsRootPath" "${config}") == "${WAREHOUSE#*s3a://}" ]]; then
        echo "[ERROR] Config [awsRootPath] is wrong or not Nessie source"
        return 1
    fi
    # "name":"fs.s3a.path.style.access","value":"true"},{"name":"fs.s3a.endpoint","value":"minio:9000"},{"name":"dremio.s3.compat","value":"true"
    # nessieEndpoint":"http://nessie:19120/api/v2 => NESSIE_URI
    if [[ ! $(extract_value_from_json "nessieEndpoint" "${config}") == "${NESSIE_URI}" ]]; then
        echo "[ERROR] Config [nessieEndpoint] is wrong or not Nessie source"
        return 1
    fi
    # "status":"good"
    if [[ ! $(extract_value_from_json "status" "${config}") == "good" ]]; then
        echo "[ERROR] State is wrong"
        return 1
    fi
    # "type":"NESSIE"
    if [[ ! $(extract_value_from_json "type" "${config}") == "NESSIE" ]]; then
        echo "[ERROR] Type is wrong"
        return 1
    fi
    return 0
}

# check_error_response() {
#     local error=$(grep -oP '(?<="errorMessage":")[^"]*' <<< "$1")
#     if [[ -z "${error}" ]];then
#         echo ${error}
#     fi
#     echo
# }

# Create admin user
echo "[INFO]  Try to login with admin user"
login
if [[ -z "${TOKEN}" ]]; then
    response=$(curl -s -X PUT 'http://localhost:9047/apiv2/bootstrap/firstuser' \
        --header 'Authorization: _dremionull' \
        --header 'Content-Type: application/json' \
        --data-raw "{
            \"userName\": \"${DREMIO_ADMIN_USER}\",
            \"firstName\": \"${DREMIO_ADMIN_FIRSTNAME}\",
            \"lastName\": \"${DREMIO_ADMIN_LASTNAME}\",
            \"email\": \"${DREMIO_ADMIN_EMAIL}\",
            \"password\": \"${DREMIO_ADMIN_PASSWORD}\",
            \"createdAt\": $(date +%s%N | cut -b1-13)
        }")
    if [ $? -ne 0 ]; then
        echo "[ERROR] Something went wrong when try to create admin user"
        exit 1
    fi
    if [[ $(extract_value_from_json "resourcePath" "${response}") == "/user/admin" ]]; then
        # Then login to get token
        login
    else
        echo "[ERROR] Something went wrong when try create admin user: ${response}"
        exit 1
    fi
fi

# Add token to header
AUTH_HEADER="Authorization: ${TOKEN}"
# Add Nessie source
# Check if Nessie created
response=$(curl -s -X GET 'http://localhost:9047/api/v3/catalog/by-path/nessie' \
                --header "${AUTH_HEADER}" \
                --header 'Content-Type: application/json')
#{"errorMessage":"Could not find entity with path [[nessie]]","moreInfo":""}
if [[ ! -z "${response}" && $(extract_value_from_json "errorMessage" "${response}") == "" ]]; then
    check_nessie_catalog_config "${response}"
    if [ $? -ne 0 ]; then
        echo "[ERROR] Something went wrong with Nessie catalog config"
        exit 1
    fi
    echo "[INFO]  Nessie catalog is created"
    exit 0
fi

if [[ ! -z "${TOKEN}" ]]; then
    echo "[INFO]  Create Nessie catalog"
    response=$(curl -s -X POST 'http://localhost:9047/api/v3/catalog' \
        --header "${AUTH_HEADER}" \
        --header 'Content-Type: application/json' \
        --data-raw '{
            "entityType":"source",
            "config":{
                "awsAccessKey": "minio",
                "awsAccessSecret": "minio123",
                "awsRootPath": "warehouse",
                "propertyList":[
                    {"name": "fs.s3a.path.style.access", "value": "true"},
                    {"name": "fs.s3a.endpoint", "value": "minio:9000"},
                    {"name": "dremio.s3.compat", "value": "true"}
                ],
                "asyncEnabled": true,
                "isCachingEnabled": true,
                "maxCacheSpacePct": 100,
                "defaultCtasFormat": "ICEBERG",
                "nessieEndpoint": "http://nessie:19120/api/v2",
                "credentialType": "ACCESS_KEY",
                "nessieAuthType": "NONE",
                "secure": false
            },
            "type": "NESSIE",
            "name": "nessie"
        }')
    if [ $? -ne 0 ]; then
        echo "[ERROR] Something went wrong when try to create Nessie source"
        exit 1
    fi
    if [[ $(extract_value_from_json "entityType" "${response}") == "source" ]]; then
        echo "[INFO]  Nessie source created"
    else
        echo "[ERROR] Something went wrong when try create Nessie source: ${response}"
        exit 1
    fi
    check_nessie_catalog_config "${response}"
    if [ $? -ne 0 ]; then
        echo "[ERROR] Something went wrong with Nessie catalog config"
        exit 1
    fi
    echo "[INFO]  Nessie catalog is created"
    exit 0
fi
