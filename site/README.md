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

Each build selects the newest stable GitHub release with an Apple silicon download, falling back to the newest prerelease with a matching download. Rebuild the static site after publishing a release to update the displayed version and download link. If GitHub is unavailable or no matching asset exists, the download button opens the releases page.

The desktop preview uses the default wallpaper from macOS 27 and EvaBar’s existing app artwork.

## Production deployment

The [GitHub Actions workflow](../.github/workflows/deploy-site.yml) publishes the site to [evabar.vercel.app](https://evabar.vercel.app/) when a stable GitHub Release is published.

In the GitHub repository’s Actions settings, add `VERCEL_TOKEN` as a secret and `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID` as variables for the `michaeljiers-projects/evabar` Vercel project.

Tag the release on a commit that includes this workflow and the `site` directory. Upload the Apple silicon ZIP or DMG before publishing the release. The deploy job verifies that the built website points to that release’s download before uploading it to Vercel.
