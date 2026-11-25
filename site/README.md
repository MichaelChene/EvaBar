# EvaBar website

The EvaBar product site is a static Astro project with React islands, Tailwind CSS, and shadcn/ui components.

## Develop

Use Node.js 22.12 or later.

```sh
cd site
npm ci
npm run dev
```

Run `npm run check` to type-check the site and `npm run build` to generate it in `dist/`. Use `npm run preview` to serve the production build locally.

For each processor type, the download menu selects the newest stable GitHub release with a compatible package and falls back to a prerelease when needed. Within a release, a processor-specific package takes priority over a universal one. The menu shows the version of each package and lists a shared universal package once. Rebuild the static site after publishing a release to update the download links. If GitHub is unavailable or no matching asset exists, the download button opens the releases page.

The desktop preview layers cropped AppKit calculator captures over `public/images/macos-27-wallpaper.webp`. Each panel starts at (32, 76) in the 2400 × 816 source capture. The WebP files in `public/images/desktop-preview/` preserve the 2336 × 144 source crop’s aspect ratio. Their filenames combine the appearance and example IDs from `src/components/calculator-preview.tsx`, as in `liquid-glass-split-bill.webp`. The web copy button is positioned over the native copy icon.

## Production deployment

The [GitHub Actions workflow](../.github/workflows/deploy-site.yml) deploys [evabar.michaeljier.cn](https://evabar.michaeljier.cn/) when a stable GitHub Release is published or when a push to `main` changes `site/` or the deploy workflow. Push deployments use GitHub's latest stable release. To deploy with a specific stable release, run the workflow manually and enter its tag. Set the production URL in `astro.config.mjs` to update the canonical URL, `robots.txt`, and sitemap together.

In the GitHub repository’s Actions settings, add `VERCEL_TOKEN` as a secret and `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID` as variables for the `michaeljiers-projects/evabar` Vercel project.

Tag the release on a commit that includes this workflow and the `site` directory. Before publishing the release, upload `EvaBar-<version>-arm64.zip` and `EvaBar-<version>-x86_64.zip`, or an `EvaBar-<version>-universal.zip`. The deploy job requires downloads for both architectures from the selected release.
