#!/bin/bash
set -e

echo "🔍 Pre-Deployment Build Check"
echo "=============================="
echo ""

# Check 1: Verify we're in the portfolio directory
if [ ! -f "package.json" ]; then
    echo "❌ Error: package.json not found. Make sure you're in the portfolio directory."
    exit 1
fi

# Check 2: vercel.json must be valid JSON
OUTPUT_DIR="."
if [ -f "vercel.json" ]; then
    echo "📋 Validating vercel.json syntax..."
    if ! node -e "JSON.parse(require('fs').readFileSync('vercel.json', 'utf8'))" 2>/dev/null; then
        echo "❌ Error: vercel.json contains invalid JSON."
        node -e "JSON.parse(require('fs').readFileSync('vercel.json', 'utf8'))"
        exit 1
    fi
    echo "✅ vercel.json is valid JSON"

    # Check 2b: reject top-level keys not recognized by Vercel's project
    # config schema. This is the exact class of error that broke deploy
    # earlier ("should NOT have additional property `public`").
    echo "📋 Checking vercel.json for unknown top-level keys..."
    UNKNOWN_KEYS=$(node -e "
        const known = new Set([
            'version','name','alias','regions','builds','routes','cleanUrls',
            'headers','redirects','rewrites','trailingSlash','functions',
            'buildCommand','devCommand','ignoreCommand','installCommand',
            'outputDirectory','github','framework','crons','env','build',
            '\$schema'
        ]);
        const cfg = JSON.parse(require('fs').readFileSync('vercel.json', 'utf8'));
        const unknown = Object.keys(cfg).filter(k => !known.has(k));
        console.log(unknown.join(','));
    ")
    if [ -n "$UNKNOWN_KEYS" ]; then
        echo "❌ Error: vercel.json has unrecognized top-level key(s): $UNKNOWN_KEYS"
        echo "   These will fail Vercel's schema validation at deploy time."
        echo "   Check https://vercel.com/docs/project-configuration for valid keys."
        exit 1
    fi
    echo "✅ No unknown vercel.json keys"

    # Extract outputDirectory (defaults to project root if unset)
    CONFIGURED_DIR=$(node -e "
        const cfg = JSON.parse(require('fs').readFileSync('vercel.json', 'utf8'));
        console.log(cfg.outputDirectory || '.');
    ")
    OUTPUT_DIR="$CONFIGURED_DIR"
else
    echo "⚠️  No vercel.json found (Vercel will auto-detect settings)"
fi
echo ""

# Check 3: Run the local Tailwind build
echo "🏗️  Running local build (npm run build)..."
if ! npm run build; then
    echo "❌ Error: Local build failed."
    exit 1
fi
echo "✅ Local build succeeded"
echo ""

# Check 4: Verify the configured output directory actually contains
# index.html. This is exactly the check that Vercel does in production
# and is what caught us out with "No Output Directory named public found".
echo "📦 Checking build output..."
if [ ! -f "dist/output.css" ]; then
    echo "❌ Error: dist/output.css not found after build."
    exit 1
fi

if [ ! -f "$OUTPUT_DIR/index.html" ]; then
    echo "❌ Error: No index.html found in configured output directory '$OUTPUT_DIR'."
    echo "   Vercel will fail with 'No Output Directory' at deploy time."
    echo "   Either set vercel.json's outputDirectory to the folder containing"
    echo "   index.html, or copy index.html into '$OUTPUT_DIR' as part of the build."
    exit 1
fi
echo "✅ index.html found in output directory ('$OUTPUT_DIR')"
echo ""

# Check 5 (best-effort): if the Vercel CLI is available AND already
# authenticated, run the real production build for full-fidelity
# validation. This is skipped (not failed) when not logged in, since
# login is a one-time manual step outside this script's scope.
echo "☁️  Checking for authenticated Vercel CLI (optional deep check)..."
if npx --yes vercel@latest whoami >/dev/null 2>&1; then
    echo "   Authenticated. Running real 'vercel build' simulation..."
    if ! npx --yes vercel@latest build --yes 2>&1 | tee /tmp/vercel-build-check.log; then
        echo ""
        echo "❌ Vercel build simulation FAILED (this is the real production build)."
        echo "   Review the output above (also saved to /tmp/vercel-build-check.log)."
        exit 1
    fi
    echo "✅ Vercel production build simulation passed"
else
    echo "⚠️  Skipped: Vercel CLI not authenticated (run 'npx vercel login' for full simulation)."
    echo "   Continuing with local checks only — these already caught both prior incidents."
fi

echo ""
echo "=============================="
echo "✅ GREEN BUILD — ready to deploy!"
echo "=============================="
