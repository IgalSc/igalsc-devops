#!/bin/bash
certificate_name="certificate.pem or certificate.crt"
openssl verify -untrusted <( { openssl x509 >/dev/null; cat; } < $certificate_name ) $certificate_name