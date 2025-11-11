# GitHub Actions Workflows

## Deploy to GKE

Automatically deploys the application to Google Kubernetes Engine (GKE).

### Required Secrets

Configure these in your GitHub repository settings (Settings → Secrets and variables → Actions → Secrets):

| Secret Name | Description | Example |
|------------|-------------|---------|
| `GCP_PROJECT_ID` | Google Cloud project ID | `your-project-id` |
| `WIF_PROVIDER` | Workload Identity Provider resource name | `projects/123456789/locations/global/workloadIdentityPools/github/providers/github` |
| `WIF_SERVICE_ACCOUNT` | Service account email for Workload Identity | `github-actions@your-project-id.iam.gserviceaccount.com` |
| `GKE_CLUSTER_NAME` | GKE cluster name | `your-gke-cluster` |
| `GKE_REGION` | GKE cluster region | `us-south1` |
| `PROJECT_NAME` | Application name | `your-application-name` |
| `DB_PASSWORD` | Production database password | `<secure-password>` |
| `REDIS_PASSWORD` | Production Redis password | `<secure-password>` |

### Optional Variables

Configure these in your GitHub repository settings (Settings → Secrets and variables → Actions → Variables):

| Variable Name | Description | Default |
|--------------|-------------|---------|
| `NODE_ENV` | Node environment | `production` |
| `FRONTEND_PORT` | Frontend port | `3000` |
| `API_PORT` | API port | `8080` |

### Setting up GCP Infrastructure

#### 1. Create Artifact Registry repository

```bash
gcloud artifacts repositories create wander-app \
  --repository-format=docker \
  --location=us-south1 \
  --description="Wander app container images" \
  --project=your-project-id
```

#### 2. Set up Workload Identity Federation (Recommended - No Long-Lived Keys!)

This uses OIDC tokens instead of service account keys for enhanced security.

```bash
# Set variables
export PROJECT_ID="your-project-id"
export PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
export REPO="your-github-username/your-repo-name"  # e.g., "octocat/wander-app"

# Create Workload Identity Pool
gcloud iam workload-identity-pools create github \
  --location=global \
  --display-name="GitHub Actions Pool" \
  --project=$PROJECT_ID

# Create Workload Identity Provider (connects to GitHub)
gcloud iam workload-identity-pools providers create-oidc github \
  --location=global \
  --workload-identity-pool=github \
  --display-name="GitHub Provider" \
  --attribute-mapping="google.subject=assertion.sub,attribute.actor=assertion.actor,attribute.repository=assertion.repository,attribute.repository_owner=assertion.repository_owner" \
  --attribute-condition="assertion.repository_owner == '$(echo $REPO | cut -d'/' -f1)'" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --project=$PROJECT_ID

# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Deployer" \
  --project=$PROJECT_ID

# Grant GKE permissions
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/container.developer"

# Grant Artifact Registry permissions
gcloud artifacts repositories add-iam-policy-binding wander-app \
  --location=us-south1 \
  --member="serviceAccount:github-actions@$PROJECT_ID.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer" \
  --project=$PROJECT_ID

# Allow GitHub to impersonate the service account
gcloud iam service-accounts add-iam-policy-binding \
  github-actions@$PROJECT_ID.iam.gserviceaccount.com \
  --role="roles/iam.workloadIdentityUser" \
  --member="principalSet://iam.googleapis.com/projects/$PROJECT_NUMBER/locations/global/workloadIdentityPools/github/attribute.repository/$REPO" \
  --project=$PROJECT_ID

# Get the Workload Identity Provider resource name (for GitHub secret)
echo "WIF_PROVIDER:"
gcloud iam workload-identity-pools providers describe github \
  --location=global \
  --workload-identity-pool=github \
  --format='value(name)' \
  --project=$PROJECT_ID

echo ""
echo "WIF_SERVICE_ACCOUNT:"
echo "github-actions@$PROJECT_ID.iam.gserviceaccount.com"
```

**Add these to GitHub Secrets:**
- `WIF_PROVIDER`: Output from command above (e.g., `projects/123456789/locations/global/workloadIdentityPools/github/providers/github`)
- `WIF_SERVICE_ACCOUNT`: `github-actions@your-project-id.iam.gserviceaccount.com`

#### 3. Alternative: Service Account Key (Less Secure - Not Recommended)

<details>
<summary>Only use if you cannot use Workload Identity Federation</summary>

```bash
# Create service account
gcloud iam service-accounts create github-actions \
  --display-name="GitHub Actions Deployer" \
  --project=your-project-id

# Grant permissions
gcloud projects add-iam-policy-binding your-project-id \
  --member="serviceAccount:github-actions@your-project-id.iam.gserviceaccount.com" \
  --role="roles/container.developer"

gcloud artifacts repositories add-iam-policy-binding wander-app \
  --location=us-south1 \
  --member="serviceAccount:github-actions@your-project-id.iam.gserviceaccount.com" \
  --role="roles/artifactregistry.writer" \
  --project=your-project-id

# Create key (WARNING: Long-lived credentials - rotate regularly!)
gcloud iam service-accounts keys create /tmp/gcp-key.json \
  --iam-account=github-actions@your-project-id.iam.gserviceaccount.com

# Add to GitHub as GCP_SA_KEY secret (raw JSON, not base64)
cat /tmp/gcp-key.json

# Clean up local key
rm /tmp/gcp-key.json
```

**Note:** Update workflow to use `credentials_json: ${{ secrets.GCP_SA_KEY }}` instead of Workload Identity.

</details>

### Deployment Flow

**Automatic Progressive Deployment:**

```
Push to master
    ↓
┌─────────────────────┐
│  Build & Scan       │  (Automatic)
│  - Build images     │
│  - Push to registry │
│  - Trivy scan       │
└──────────┬──────────┘
           ↓
┌─────────────────────┐
│  Deploy to Staging  │  (Automatic)
│  - Helm upgrade     │
│  - Run smoke tests  │
└──────────┬──────────┘
           ↓
    🛑 APPROVAL GATE
           ↓
┌─────────────────────┐
│ Deploy to Production│  (Manual approval required)
│  - Helm upgrade     │
│  - Verify rollout   │
└─────────────────────┘
```

**Workflow Stages:**

1. **Build & Scan** → Builds Docker images, scans for vulnerabilities
2. **Deploy to Staging** → Automatically deploys to staging environment
3. **Manual Approval Gate** → Waits for approval to deploy to production
4. **Deploy to Production** → Deploys to production after approval

**Setting Up Manual Approval for Production:**

1. Go to your GitHub repository → Settings → Environments
2. Click "New environment" → Name it `production`
3. Check "Required reviewers" → Add team members who can approve
4. (Optional) Add a wait timer (e.g., 30 minutes before deployment can be approved)
5. (Optional) Restrict deployment branches to `master` only

Now when code is pushed to `master`:
- Staging deploys automatically
- Production deployment **waits for manual approval**
- Approvers receive notification to review and approve

**Approving Production Deployments:**

1. After staging deployment succeeds, GitHub will pause the workflow
2. Approvers receive a notification (email + GitHub notification)
3. Go to Actions tab → Select the running workflow
4. Click "Review deployments" button
5. Check the staging environment, then click "Approve and deploy"
6. Production deployment proceeds automatically after approval

**Rejecting a Deployment:**

- Click "Reject" instead of "Approve" to cancel the production deployment
- The workflow will stop and not deploy to production
- Fix the issue and push a new commit to try again

### Accessing the Deployed Application

After deployment completes, the workflow will output the frontend URL:

```
🎉 Application deployed successfully!

Frontend URL: http://34.174.12.217:3000
```

Or get it manually:
```bash
kubectl get service frontend -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Service Architecture

```
Internet
    ↓
LoadBalancer (Frontend)  ← External IP
    ↓
Frontend Pod
    ↓
API Service (ClusterIP)  ← Internal only
    ↓
API Pod
    ↓
DB + Redis (ClusterIP)   ← Internal only
```

### Monitoring Deployments

View deployment status:
- GitHub Actions tab shows workflow progress
- Check pods: `kubectl get pods`
- Check services: `kubectl get services`
- View logs: `kubectl logs -f deployment/frontend`
- View API logs: `kubectl logs -f deployment/api`

### Troubleshooting

**LoadBalancer IP pending:**
```bash
# Check status
kubectl get service frontend

# GKE LoadBalancer provisioning can take 1-3 minutes
kubectl describe service frontend
```

**Pod not starting:**
```bash
# Check pod status
kubectl get pods

# View pod logs
kubectl logs <pod-name>

# Describe pod for events
kubectl describe pod <pod-name>
```

**Image pull errors:**
```bash
# Verify images exist in Artifact Registry
gcloud artifacts docker images list us-south1-docker.pkg.dev/your-project-id/wander-app

# Check GKE has pull permissions
kubectl get serviceaccount default -o yaml
```

### Clean Up

Delete deployment:
```bash
helm uninstall wander-app
```

Delete GKE cluster:
```bash
gcloud container clusters delete wander-demo --region=us-south1
```
