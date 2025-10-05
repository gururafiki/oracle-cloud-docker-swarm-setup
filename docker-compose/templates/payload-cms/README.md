# Payload CMS Docker Compose teamplte

**WARNING**: This template is experimental, wasn't tested yet.

This is the minimal Docker Compose template for deploying [Payload CMS](https://payloadcms.com/).
This template requires providing `image` for Payload CMS with connection to S3. It requires few changes to the codebase.

## Changes required Payload CMS codebase:
### 1. Update code of *next.config.js*:
#### 1. [BUG in Payload CMS codebase] Set `const NEXT_PUBLIC_SERVER_URL = process.env.NEXT_PUBLIC_SERVER_URL || process.env.__NEXT_PRIVATE_ORIGIN || 'http://localhost:3000'`
#### 2. Set `nextConfig.output = 'standalone'`


### 2. Install `@payloadcms/storage-s3` package

Official documentation - [Payload CMS - Storage Adapters](https://payloadcms.com/docs/upload/storage-adapters)

#### 1. If you use **pnpm** - `pnpm install @payloadcms/storage-s3`
#### 2. Don't forget to re-generate import map, if you are using **pnpm** - run `pnpm generate:importmap`.

### 3. Update `environment.d.ts`:
#### 1. Add following variables to `environment.d.ts`:
```
S3_BUCKET: string
S3_ACCESS_KEY_ID: string
S3_ENDPOINT: string
S3_SECRET_ACCESS_KEY: string
S3_REGION: string
```

### 4. Update *payload.config.ts*:

#### 1. Add import:
```
import { s3Storage } from '@payloadcms/storage-s3'
```
#### 2. Add plugin to `default > plugins`:
```
  plugins: [
    ...plugins,
    s3Storage({
        collections: {
            media: true
        },
        bucket: process.env.S3_BUCKET,
        config: {
        credentials: {
            accessKeyId: process.env.S3_ACCESS_KEY_ID,
            secretAccessKey: process.env.S3_SECRET_ACCESS_KEY,
        },
        region: process.env.S3_REGION,
            // ... Other S3 configuration
        },
    })
  ]
```

## Deployment
1. Build Payload CMS docker image and push it to Docker registry.
2. Point to image you have deployed within *docker-compose.yaml* (`services > payload-cms > image`)
3. Rename *.env.example* to *.env* and fill environment variables.
4. Run `docker compose up`

Once deployed you can access endpoint *http://<public_ip>:3000* via HTTP.
