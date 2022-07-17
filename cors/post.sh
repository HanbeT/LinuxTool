#!/bin/sh

HTTP_METHOD=POST

origin_url=$1
post_url=$2
json_data=`cat $3`

curl -X ${HTTP_METHOD} \
      -H "Content-Type: application/json" \
      -d "${json_data}" \
      -v ${post_url}
