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

The desktop preview uses the default wallpaper from macOS 27 and EvaBar’s existing app artwork.

## Production deployment

The [GitHub Actions workflow](../.github/workflows/deploy-site.yml) publishes the site to [evabar.vercel.app](https://evabar.vercel.app/) when a stable GitHub Release is published.

In the GitHub repository’s Actions settings, add `VERCEL_TOKEN` as a secret and `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID` as variables for the `michaeljiers-projects/evabar` Vercel project.

Tag the release on a commit that includes this workflow and the `site` directory. Upload `EvaBar-<version>-arm64.zip` and `EvaBar-<version>-x86_64.zip` before publishing the release. The deploy job verifies that the menu links to a download from that release before uploading the site to Vercel.
