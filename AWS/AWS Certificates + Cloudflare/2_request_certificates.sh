# This script will read the txt file 
# created by the list_certificates.sh, 
# will request all the certificates under new AWS account,
# and will store the Domain Name, SANs, CNAME names
# and CNAME values to be created ina  csv file

#!/bin/bash

region="your-region"
profile="your-profile"
input_file="certificates.txt"
output_file="certificate_details.csv"

# Redirect output to a file
echo "Domain Name,SANs,CNAME Name,CNAME Value" > $output_file

# Read the input file line by line, skipping the first line
tail -n +2 $input_file | while IFS=, read -r arn domain1 domain2 sans; do
  # Remove leading/trailing whitespaces
  arn=$(echo $arn | tr -d '[:space:]')
  domain1=$(echo $domain1 | tr -d '[:space:]')
  domain2=$(echo $domain2 | tr -d '[:space:]')
  sans=$(echo $sans | tr -d '[:space:]') # No need to modify SANs

  # Request a certificate
  cert_arn=$(aws acm request-certificate \
              --region $region \
              --profile $profile \
              --domain-name $domain1 \
              --subject-alternative-names $sans \
              --validation-method DNS \
              --query 'CertificateArn' \
              --output text)

  # Check if certificate request was successful
  if [ $? -eq 0 ]; then
    # Wait for the certificate to become available
    sleep 30

    # Get the DNS validation CNAME record
    cname_name=$(aws acm describe-certificate \
                    --certificate-arn $cert_arn \
                    --region $region \
                    --profile $profile \
                    --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Name' \
                    --output text)
    cname_value=$(aws acm describe-certificate \
                    --certificate-arn $cert_arn \
                    --region $region \
                    --profile $profile \
                    --query 'Certificate.DomainValidationOptions[0].ResourceRecord.Value' \
                    --output text)

    # Append to the output file
    echo "$domain1,$sans,$cname_name,$cname_value" >> $output_file
  fi

done

echo "Certificate requests details saved to $output_file"
