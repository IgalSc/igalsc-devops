aws s3 ls s3://$SOURCE_BUCKET/ --recursive --profile $PROFILE \
| awk '{print $4}' \
| xargs -I{} -P8 aws s3 mv s3://$SOURCE_BUCKET/{} s3://$DESTINATION_BUCKET/{} --profile $PROFILE