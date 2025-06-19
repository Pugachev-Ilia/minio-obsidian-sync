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
      "Action": ["s3:GetBucketLocation", "s3:ListBucket"],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${MINIO_BUCKET}"
    },
    {
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Effect": "Allow",
      "Resource": "arn:aws:s3:::${MINIO_BUCKET}/*"
    }
  ]
}
EOF

mc admin policy create local readonly-obsidian /tmp/policy.json || true

echo "👤 Creating user '$MINIO_USER'…"
mc admin user add local "$MINIO_USER" "$MINIO_PASSWORD" || true

echo "🔒 Attaching policy to user…"
mc admin policy attach local readonly-obsidian --user "$MINIO_USER" || true

echo "🔍 Verifying access for new user…"
mc alias set obsidian http://localhost:9000 "$MINIO_USER" "$MINIO_PASSWORD"

# Testing read/write/delete bucket
echo "TestFile" > /tmp/testfile.txt
mc cp /tmp/testfile.txt obsidian/"$MINIO_BUCKET"/testfile.txt
mc cat obsidian/"$MINIO_BUCKET"/testfile.txt >/dev/null
mc rm obsidian/"$MINIO_BUCKET"/testfile.txt

rm -f /tmp/testfile.txt

echo "✅ User access verified (upload/read/delete)."
