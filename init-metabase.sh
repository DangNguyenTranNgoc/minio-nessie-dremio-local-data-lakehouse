#!/bin/bash
source .env

TOKEN=""
NESSIE_SOURCE_CONFIG=""
ERROR_MESSAGE=""

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

# Create user
echo "[INFO]  Setup Dremio"
response=$(curl -s -X POST http://localhost:3000/api/setup \
        -H "Content-type: application/json" \
        -d '{
        "token": "'${MB_SETUP_TOKEN}'",
        "user": {
            "email": "'${METABASE_EMAIL}'",
            "password": "'${METABASE_PASSWORD}'"
        },
        "prefs": {
            "allow_tracking": '${METABASE_ALLOW_TRACKING}',
            "site_name": "'${METABASE_SITE_NAME}'"
        },
        "database": {
            "connection_source": "admin",
            "auto_run_queries": false,
            "name": "dremio",
            "details": {
                "host": "dremio",
                "port": 31010,
                "schema-filters-type": "all",
                "user": "admin",
                "password": "Rootme123",
                "ssl": false
              },
            "schedules": {
                "cache_field_values": {
                    "schedule_type": "hourly",
                    "schedule_day": "sun",
                    "schedule_frame": "first",
                    "schedule_hour": 0,
                    "schedule_minute": 0
                },
                "metadata_sync": {
                    "schedule_type": "hourly",
                    "schedule_day": "sun",
                    "schedule_frame": "first",
                    "schedule_hour": 0,
                    "schedule_minute": null
                }
            },
            "engine": "dremio"
        }
    }')

if [ $? -ne 0 ]; then
    echo "[ERROR] Something went wrong when try to setup Dremio"
    return 1
fi

echo $response
