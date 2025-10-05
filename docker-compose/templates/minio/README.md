# MinIO Docker Compose teamplte

This is the minimal Docker Compose template for MinIO (Open-source self-hosted S3 alternative).

It exposes following endpoints:
- Port *9000* - S3 endpoint.
- Port *9001* - Admin UI.

Environment variables:
- `MINIO_ROOT_USER` - used as login for Admin UI and as `AWS_ACCESS_KEY_ID`.
- `MINIO_ROOT_PASSWORD` - used as password for Admin UI and as `AWS_SECRET_ACCESS_KEY`
