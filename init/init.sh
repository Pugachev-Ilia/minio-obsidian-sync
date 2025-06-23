#!/usr/bin/env bash
set -e

echo "🔗 Connecting mc to MinIO…"
mc alias set local http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"

echo "🪣 Creating bucket '$MINIO_BUCKET'…"
mc mb --ignore-existing local/"$MINIO_BUCKET"

echo "📜 Creating policy 'readonly-obsidian'…"
cat > /tmp/policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["s3:GetBucketLocation", "s3:ListBucket"],
      "Resource": "arn:aws:s3:::${MINIO_BUCKET}"
    },
    {
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::${MINIO_BUCKET}/*"
    }
  ]
}
EOF

mc admin policy create local readonly-obsidian /tmp/policy.json || true

echo "🔐 Creating service account for Obsidian"
mc admin user svcacct add local "$MINIO_ROOT_USER" \
  --access-key "$MINIO_ACCESS_KEY" \
  --secret-key "$MINIO_SECRET_KEY" \
  --policy "$POLICY_NAME"
