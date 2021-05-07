uuid="$1"
key="$2"
base_url="$3"
verify_ssl="$4"
monitored_interfaces="$5"

# $1 is baseurl
url="$base_url/api/v1/monitoring/device/$uuid/?key=$key"
data=$(/usr/sbin/netjson-monitoring "$monitored_interfaces")
if [ "$verify_ssl" = 0 ]; then
    curl_command='curl -k'
else
    curl_command='curl'
fi
# send data via POST
$($curl_command -H "Content-Type: application/json" \
                -X POST \
                -d "$data" \
                -v $url)
