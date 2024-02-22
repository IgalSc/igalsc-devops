aws s3api list-objects-v2 \
  --profile {profile_name} \
  --region us-east-1 \
  --bucket {bucket_name} \
  --prefix "files/media/" \
  --delimiter "/" \
  --query 'CommonPrefixes[].Prefix' --output text | tr '\t' '\n' | grep -Eo '^files/media/[0-9]+/$' \
  >> {output_file.csv}
