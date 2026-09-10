# Check Deploy Skill

## Command
```
/check-deploy
```

### Description
Pre-deployment validation that catches build and configuration errors **before** they hit Vercel's production build. Runs the exact same build Vercel runs (`vercel build`), so schema errors in `vercel.json`, missing output directories, and build failures show up locally instead of after a merge to `main`.

This exists because of two real incidents on this project:
1. `vercel.json` pointed at a `dist` folder that only contained CSS (no `index.html`) → "No Output Directory named public" error.
2. `vercel.json` had an invalid `public` property → schema validation failure on deploy.

Both would have been caught locally by this check.

### What it checks, in order:
1. ✅ You're in the project root (`package.json` exists)
2. ✅ `vercel.json` is syntactically valid JSON (if present)
3. ✅ `npm run build` succeeds (Tailwind compiles cleanly)
4. ✅ Expected build artifacts exist (`dist/output.css`, `index.html`)
5. ✅ `npx vercel build` succeeds — this is the **real** Vercel build, so it validates the `vercel.json` schema and confirms Vercel can actually locate your output directory
6. ✅ `.vercel/output/` was generated with the expected structure

If any step fails, the script exits immediately with a clear error and non-zero exit code — nothing gets pushed.

### Usage
Run before every deploy:
```bash
/check-deploy
```

Or as part of the full flow:
```bash
/check-deploy   # validate first
/deploy         # then ship
```

### Integration with /deploy
`deploy.sh` runs this check automatically as its first step. If the build isn't green, deployment is aborted before any PR is created or pushed.

### Requirements
- Node.js / npm installed
- No global Vercel CLI install needed — `npx vercel build` fetches it on demand
- `.vercel/` is gitignored (this is a local simulation only, not a real deployment)

### Troubleshooting

**"vercel.json contains invalid JSON"**
- Check for trailing commas, unquoted keys, or typos
- Run `node -e "JSON.parse(require('fs').readFileSync('vercel.json'))"` directly to see the parse error

**"Vercel build simulation FAILED"**
- This is the exact error Vercel would show in production — read it carefully
- Common causes: unknown property in `vercel.json` (check against https://vercel.com/docs/project-configuration), wrong `outputDirectory`

**"Local build failed"**
- Run `npm run build` directly to see the full Tailwind error output
