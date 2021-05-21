IP=$(aws lightsail get-instances  | grep publicIpAddress | cut -d \: -f2 | cut -d\" -f2)

ssh ubuntu@$IP -p 22
