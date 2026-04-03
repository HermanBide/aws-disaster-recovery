#!/usr/bin/bash
yum update -y
yum install -y httpd
systemctl start httpd
systemctl enable httpd

# Get instance metadata
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
PRIVATE_IP=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)

# Create web page
cat > /var/www/html/index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Route 53 Failover Demo</title>
    <meta http-equiv="refresh" content="5">
    <style>
        body {
            font-family: Arial, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, ${role_color} 0%, ${role_color}dd 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 40px;
            background: rgba(0,0,0,0.3);
            border-radius: 20px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
            max-width: 500px;
        }
        h1 { font-size: 2.5rem; margin-bottom: 10px; }
        .region { font-size: 1.8rem; color: ${text_color}; margin: 20px 0; }
        .badge {
            display: inline-block;
            padding: 10px 30px;
            background: ${badge_color};
            color: #000;
            border-radius: 30px;
            font-weight: bold;
            font-size: 1.2rem;
            margin: 20px 0;
        }
        .info { 
            font-size: 0.9rem; 
            opacity: 0.9; 
            margin-top: 30px;
            background: rgba(0,0,0,0.2);
            padding: 15px;
            border-radius: 10px;
            text-align: left;
        }
        .info p { margin: 8px 0; }
        .label { color: ${text_color}; }
        .refresh { font-size: 0.8rem; opacity: 0.7; margin-top: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🌐 Route 53 Failover</h1>
        <div class="region">${region} (${region_name})</div>
        <div class="badge">✅ ${role} SERVER</div>
        <p>This is the <strong>${role}</strong> region.</p>
        <div class="info">
            <p><span class="label">Instance ID:</span> INSTANCE_ID_PLACEHOLDER</p>
            <p><span class="label">Availability Zone:</span> AZ_PLACEHOLDER</p>
            <p><span class="label">Private IP:</span> PRIVATE_IP_PLACEHOLDER</p>
            <p><span class="label">Timestamp:</span> TIMESTAMP_PLACEHOLDER</p>
        </div>
        <p class="refresh">Auto-refresh every 5 seconds</p>
    </div>
</body>
</html>
EOF

# Replace placeholders with actual values
sed -i "s/INSTANCE_ID_PLACEHOLDER/$INSTANCE_ID/g" /var/www/html/index.html
sed -i "s/AZ_PLACEHOLDER/$AZ/g" /var/www/html/index.html
sed -i "s/PRIVATE_IP_PLACEHOLDER/$PRIVATE_IP/g" /var/www/html/index.html
sed -i "s/TIMESTAMP_PLACEHOLDER/$(date)/g" /var/www/html/index.html

# Create health check endpoint
echo "OK" > /var/www/html/health