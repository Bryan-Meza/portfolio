# Deploy Project Skill

## Command
```
/deploy
```

### Description
Automated deployment workflow for the portfolio project. Creates a pull request from `staging` → `main`, verifies all checks pass (green build), then merges to main for production deployment.

### Pre-Deployment Checks:
1. ✅ Confirms you're on the `staging` branch
2. ✅ Verifies this is a git repository
3. ✅ Checks for uncommitted changes (stages & commits if needed)
4. ✅ Verifies build artifacts exist in `dist/` folder
5. ✅ Pushes staging branch to remote
6. ✅ Creates/updates PR from staging → main
7. ✅ Waits for CI/build checks to complete
8. ✅ Verifies build status is GREEN before merging

### What it does:
1. Pushes your staging branch to GitHub
2. Creates a pull request (or uses existing) from `staging` to `main`
3. Waits for GitHub Actions/CI checks to pass (up to 2 minutes)
4. Verifies build is GREEN and ready for production
5. Merges the PR using squash commit
6. Deletes the remote staging branch (optional)
7. Updates your local main branch

### Usage
Run the deploy skill whenever you're ready to deploy from staging:

```bash
/deploy
```

The skill will:
- Guide you through confirmations at each step
- Monitor build checks automatically
- Abort if build fails (green build required)
- Merge and deploy only when everything passes
- You can cancel at any point before merge

### Requirements
- On the `staging` branch
- Git repository with `origin` remote (GitHub)
- GitHub CLI (`gh`) installed: https://cli.github.com
- GitHub authentication configured (`gh auth login`)
- Build artifacts in `dist/` folder
- All changes committed (no uncommitted files)

### Example Workflow
1. Make changes and commit to `staging`
2. Push changes to remote staging
3. When ready to deploy: `/deploy`
4. Script creates PR and monitors build
5. Once build passes: confirm deployment
6. PR merges to main automatically
7. Portfolio deployed to production! 🚀

### Troubleshooting

**"GitHub CLI (gh) is not installed"**
- Install from: https://cli.github.com
- Then authenticate: `gh auth login`

**"Build failed"**
- Fix the failing checks in the PR
- Run `/deploy` again once fixes are committed

**"Build checks still pending"**
- Script waits up to 2 minutes
- Can continue anyway if needed (at your risk)
