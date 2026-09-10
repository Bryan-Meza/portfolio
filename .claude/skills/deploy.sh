#!/bin/bash
set -e

echo "🚀 Portfolio Deployment to Main"
echo "==============================="
echo ""

# Check 1: Verify we're in the portfolio directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: package.json not found. Make sure you're in the portfolio directory."
    exit 1
fi

# Check 1.5: Run pre-deployment build check (validates vercel.json + simulates
# the real Vercel build so config/schema errors are caught before pushing)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/check-deploy.sh" ]; then
    echo "🔍 Running pre-deployment build check..."
    echo ""
    if ! bash "$SCRIPT_DIR/check-deploy.sh"; then
        echo ""
        echo "❌ Pre-deployment check failed. Fix the issues above before deploying."
        exit 1
    fi
    echo ""
else
    echo "⚠️  check-deploy.sh not found, skipping pre-deployment build check."
    echo ""
fi

# Check 2: Verify git repository
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a git repository."
    exit 1
fi

# Check 3: Verify we're on staging branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "staging" ]; then
    echo "❌ Error: Not on staging branch (currently on: $current_branch)"
    echo "   Please switch to staging branch first: git checkout staging"
    exit 1
fi

echo "✅ On staging branch"
echo ""

# Check 4: Verify no uncommitted changes
echo "📋 Checking for uncommitted changes..."
if ! git diff-index --quiet HEAD --; then
    echo "⚠️  There are uncommitted changes:"
    echo ""
    git status --short
    echo ""
    read -p "Do you want to stage and commit these changes? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Deployment cancelled."
        exit 1
    fi

    echo ""
    echo "📝 Staging and committing changes..."
    git add -A
    git commit -m "chore: prepare for deployment"
    echo "✅ Changes committed"
else
    echo "✅ Working tree is clean"
fi

# Check 5: Verify dist folder exists
echo ""
echo "📦 Checking build artifacts..."
if [ ! -d "dist" ]; then
    echo "❌ Error: dist folder not found. Build is required before deployment."
    exit 1
fi
echo "✅ Build artifacts found"

# Check 6: Push staging to remote
echo ""
echo "🔄 Pushing staging branch to remote..."
git push origin staging

# Check 7: Verify gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "❌ Error: GitHub CLI (gh) is not installed."
    echo "   Install it from: https://cli.github.com"
    exit 1
fi

# Check 8: Get repository info
echo ""
echo "📡 Getting repository information..."
repo=$(git rev-parse --abbrev-ref HEAD --symbolic-full-name | cut -d'/' -f1 2>/dev/null || echo "origin")
repo_url=$(git config --get remote.origin.url)
repo_name=$(basename "$repo_url" .git)
repo_owner=$(git remote get-url origin | sed 's/.*[\/:]\([^\/]*\)\/[^\/]*\.git$/\1/')

echo "   Repository: $repo_owner/$repo_name"
echo "   Source: staging"
echo "   Target: main"
echo ""

# Check 9: Check if PR already exists
echo "🔍 Checking for existing pull requests..."
existing_pr=$(gh pr list --head staging --base main --json number --jq '.[0].number' 2>/dev/null || echo "")

if [ -n "$existing_pr" ]; then
    echo "⚠️  PR #$existing_pr already exists for staging → main"
    read -p "Use existing PR? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Deployment cancelled."
        exit 1
    fi
    pr_number=$existing_pr
else
    # Create new PR
    echo ""
    echo "📝 Creating pull request..."
    pr_number=$(gh pr create \
        --base main \
        --head staging \
        --title "Deploy: Merge staging to main" \
        --body "Automated deployment from staging branch.

## Checklist
- [ ] Code review complete
- [ ] All checks passed
- [ ] Ready for production" \
        --json number \
        --jq '.number')

    echo "✅ PR #$pr_number created"
fi

# Check 10: Wait for checks and verify build status
echo ""
echo "⏳ Checking PR status and build checks..."
sleep 2

pr_status=$(gh pr view "$pr_number" --json statusCheckRollup --jq '.statusCheckRollup' 2>/dev/null || echo "PENDING")

if [ "$pr_status" = "PENDING" ] || [ "$pr_status" = "null" ]; then
    echo "⏳ Build checks are still running. Waiting..."
    max_wait=120
    elapsed=0

    while [ $elapsed -lt $max_wait ]; do
        sleep 5
        elapsed=$((elapsed + 5))
        pr_status=$(gh pr view "$pr_number" --json statusCheckRollup --jq '.statusCheckRollup' 2>/dev/null || echo "PENDING")

        if [ "$pr_status" != "PENDING" ] && [ "$pr_status" != "null" ]; then
            break
        fi

        echo "   Waiting... (${elapsed}s/${max_wait}s)"
    done
fi

# Check 11: Verify build passed
echo ""
echo "🔍 Build status: $pr_status"

if [ "$pr_status" = "FAILURE" ]; then
    echo "❌ Build failed! Deployment cannot proceed."
    echo "   PR #$pr_number: https://github.com/$repo_owner/$repo_name/pull/$pr_number"
    echo ""
    echo "   Please fix the failing checks and try again."
    exit 1
fi

if [ "$pr_status" != "SUCCESS" ]; then
    echo "⚠️  Build checks status is unknown or still pending"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Deployment cancelled."
        exit 1
    fi
fi

echo "✅ Build checks passed!"

# Final confirmation
echo ""
echo "📋 Deployment Summary:"
echo "   PR #$pr_number: Deploy staging → main"
echo "   Build Status: $pr_status"
echo "   Action: Merge PR and close"
echo ""

read -p "Ready to merge PR and deploy to main? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled."
    exit 1
fi

# Merge PR
echo ""
echo "🔀 Merging PR #$pr_number..."
gh pr merge "$pr_number" \
    --squash \
    --delete-branch \
    --auto \
    2>/dev/null || \
gh pr merge "$pr_number" \
    --squash \
    --delete-branch

echo "✅ PR merged successfully!"

# Update local main branch
echo ""
echo "📥 Updating local main branch..."
git fetch origin main
git checkout main
git pull origin main

echo ""
echo "✅ Deployment complete!"
echo "   PR #$pr_number has been merged to main"
echo "   Your portfolio is now deployed!"
echo ""
