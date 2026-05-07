5. **Connect Railway service to GitHub repo** (in Railway dashboard):

   - Service → Settings → Source → Connect GitHub repo
   - Build: Dockerfile, root: `/`

6. **Trigger first deploy** by pushing any commit to `main`. Railway builds and deploys.

7. **Run Pulumi:**

   ```bash
   cd infra/pulumi
   npm install
   pulumi stack init prod  # if not already done
   export RAILWAY_PROJECT_ID=<from step 3>
   ```

```

export RAILWAY_ENVIRONMENT_ID=&lt;from step 3&gt; export RAILWAY_TOKEN= export CLOUDFLARE_API_TOKEN= export CLOUDFLARE_ACCOUNT_ID= export DOPPLER_TOKEN= export GITHUB_TOKEN= pulumi up --stack prod
```

On first run, the R2 bucket is created with placeholder access-key values in Pulumi config. The next step replaces them.

8. **Bootstrap Cloudflare manuals** (lifecycle rules + access keys — not yet supported by `@pulumi/cloudflare`):

```bash
./infra/scripts/bootstrap-cloudflare.sh
```

The script walks you through creating the three lifecycle rules and an S3-compatible API token in the Cloudflare dashboard, then writes the access key + secret back into Pulumi config.

 9. **Re-run Pulumi** to propagate the new R2 credentials to Railway env vars:

    ```bash
    cd infra/pulumi
    pulumi up --stack prod
    ```

10. **Add GitHub Actions secrets** so CI can deploy:

```bash
gh secret set PULUMI_ACCESS_TOKEN --body "<from pulumi config>"
gh secret set RAILWAY_TOKEN --body "<...>"
gh secret set RAILWAY_PROJECT_ID --body "<from step 3>"
gh secret set RAILWAY_ENVIRONMENT_ID --body "<from step 3>"
gh secret set CLOUDFLARE_API_TOKEN --body "<...>"
gh secret set CLOUDFLARE_ACCOUNT_ID --body "<...>"
gh secret set DOPPLER_TOKEN --body "&lt;...&gt;" gh secret set GH_PROVIDER_TOKEN --body "&lt;...&gt;" # PAT with repo + admin:org

```

11. **Verify:** open `https://atlas.skafld.com` — should hit Cloudflare Access auth, then Atlas itself.

## Day-to-day
```
