# Wander App Helm Chart

Production-ready Helm chart for deploying the Wander full-stack application to Kubernetes.

## Overview

This chart deploys:
- **API**: Node.js + Express + TypeScript backend
- **Frontend**: React + Vite + Tailwind CSS
- **PostgreSQL**: 18-alpine database with persistent storage
- **Redis**: 8-alpine cache

## Prerequisites

- Kubernetes 1.19+
- Helm 3.0+
- Container images built and pushed to a registry

## Quick Start

### Install to Staging

```bash
helm install wander-app ./helm/wander-app \
  --namespace staging \
  --create-namespace \
  --values ./helm/wander-app/values-staging.yaml \
  --set api.image.tag=abc123 \
  --set frontend.image.tag=abc123
```

### Upgrade Existing Release

```bash
helm upgrade wander-app ./helm/wander-app \
  --namespace staging \
  --values ./helm/wander-app/values-staging.yaml \
  --set api.image.tag=def456 \
  --set frontend.image.tag=def456 \
  --atomic
```

## Configuration

### Values Files

- `values.yaml` - Default configuration
- `values-staging.yaml` - Staging environment (lower resources)
- `values-production.yaml` - Production environment (higher resources, replicas)

### Key Configuration Options

| Parameter | Description | Default |
|-----------|-------------|---------|
| `environment` | Environment name (staging/production) | `staging` |
| `api.image.repository` | API container image repository | `us-south1-docker.pkg.dev/PROJECT_ID/wander-app/api` |
| `api.image.tag` | API container image tag | `""` (must be set) |
| `frontend.image.repository` | Frontend container image repository | `us-south1-docker.pkg.dev/PROJECT_ID/wander-app/frontend` |
| `frontend.image.tag` | Frontend container image tag | `""` (must be set) |
| `frontend.service.type` | Frontend service type | `LoadBalancer` |
| `postgres.auth.password` | PostgreSQL password | `postgres` (change for production!) |
| `postgres.persistence.size` | PostgreSQL PVC size | `10Gi` |

### Overriding Values

#### Via Command Line

```bash
helm install wander-app ./helm/wander-app \
  --set api.image.tag=abc123 \
  --set frontend.image.tag=abc123 \
  --set postgres.auth.password=supersecret
```

#### Via Values File

```bash
helm install wander-app ./helm/wander-app \
  --values custom-values.yaml
```

## Deployment Workflow

### CI/CD (GitHub Actions)

The `.github/workflows/deploy-gke.yml` workflow automatically:

1. Builds Docker images tagged with commit SHA
2. Pushes to Google Artifact Registry
3. Deploys using this Helm chart with `--set` overrides
4. Waits for LoadBalancer IP

### Manual Deployment

```bash
# 1. Build images
docker build -t us-south1-docker.pkg.dev/PROJECT_ID/wander-app/api:v1.0.0 ./src/api
docker build -t us-south1-docker.pkg.dev/PROJECT_ID/wander-app/frontend:v1.0.0 ./src/frontend

# 2. Push images
docker push us-south1-docker.pkg.dev/PROJECT_ID/wander-app/api:v1.0.0
docker push us-south1-docker.pkg.dev/PROJECT_ID/wander-app/frontend:v1.0.0

# 3. Deploy with Helm
helm upgrade --install wander-app ./helm/wander-app \
  --namespace production \
  --create-namespace \
  --values ./helm/wander-app/values-production.yaml \
  --set api.image.tag=v1.0.0 \
  --set frontend.image.tag=v1.0.0 \
  --set postgres.auth.password=$DB_PASSWORD \
  --atomic
```

## Accessing the Application

### Get Frontend URL

```bash
kubectl get service frontend -n staging

# Wait for LoadBalancer IP
FRONTEND_IP=$(kubectl get service frontend -n staging -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "Frontend: http://${FRONTEND_IP}:3000"
```

### Internal Services

Services use simple names matching local development (Docker Compose):

- API: `api.staging.svc.cluster.local:8080` (or just `api` within namespace)
- PostgreSQL: `db.staging.svc.cluster.local:5432` (or just `db` within namespace)
- Redis: `redis.staging.svc.cluster.local:6379` (or just `redis` within namespace)
- Frontend: `frontend.staging.svc.cluster.local:3000` (or just `frontend` within namespace)

**Dev/Prod Parity:** These service names match exactly with `compose.yaml` for local development, ensuring your app behaves identically in both environments.

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n staging
kubectl describe pod wander-app-api-xxx -n staging
kubectl logs wander-app-api-xxx -n staging
```

### Check Services

```bash
kubectl get services -n staging
kubectl describe service wander-app-frontend -n staging
```

### Rollback

```bash
helm rollback wander-app -n staging
```

### Uninstall

```bash
helm uninstall wander-app -n staging
```

## Production Considerations

### Secrets

For production, use external secret management:

```bash
# Option 1: Google Secret Manager
kubectl create secret generic app-secrets \
  --from-literal=db-password=$(gcloud secrets versions access latest --secret=db-password)

# Option 2: Helm --set
helm upgrade wander-app ./helm/wander-app \
  --set postgres.auth.password=$SECURE_PASSWORD
```

### Resource Limits

Production values file includes:
- 3 replicas for API and Frontend
- Higher CPU/Memory limits
- Larger PostgreSQL PVC (20Gi)

### Monitoring

Add Prometheus annotations:

```yaml
spec:
  template:
    metadata:
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
```

## Chart Structure

```
helm/wander-app/
├── Chart.yaml                    # Chart metadata
├── values.yaml                   # Default values
├── values-staging.yaml           # Staging overrides
├── values-production.yaml        # Production overrides
├── README.md                     # This file
└── templates/
    ├── _helpers.tpl              # Template helpers
    ├── api/
    │   ├── deployment.yaml       # API deployment
    │   └── service.yaml          # API service
    ├── frontend/
    │   ├── deployment.yaml       # Frontend deployment
    │   └── service.yaml          # Frontend service (LoadBalancer)
    ├── postgres/
    │   ├── statefulset.yaml      # PostgreSQL statefulset
    │   └── service.yaml          # PostgreSQL service
    └── redis/
        ├── deployment.yaml       # Redis deployment
        └── service.yaml          # Redis service
```

## License

MIT
