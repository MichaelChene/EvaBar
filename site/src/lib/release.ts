const repository = "MichaelChene/EvaBar";
export const repositoryUrl = `https://github.com/${repository}`;
export const releasesUrl = `${repositoryUrl}/releases`;

type GitHubRelease = {
  tag_name: string;
  html_url: string;
  draft: boolean;
  prerelease: boolean;
  published_at: string | null;
  assets: { name: string; state: string; browser_download_url: string }[];
};

export async function getLatestRelease() {
  try {
    const response = await fetch(`https://api.github.com/repos/${repository}/releases?per_page=100`, {
      headers: { Accept: "application/vnd.github+json" },
      signal: AbortSignal.timeout(5000),
    });
    if (!response.ok) throw new Error(`GitHub returned HTTP ${response.status}`);

    const releases: GitHubRelease[] = await response.json();
    releases.sort((left, right) => {
      if (left.prerelease !== right.prerelease) return left.prerelease ? 1 : -1;
      return (right.published_at ?? "").localeCompare(left.published_at ?? "");
    });

    for (const release of releases) {
      if (release.draft || !release.published_at) continue;
      const asset = release.assets.find(
        ({ name, state }) => state === "uploaded" && /^EvaBar(?:-.+)?-arm64\.(zip|dmg)$/i.test(name),
      );
      if (asset) {
        return { version: release.tag_name, releaseUrl: release.html_url, downloadUrl: asset.browser_download_url };
      }
    }
  } catch (error) {
    console.warn("Could not fetch EvaBar releases. Linking to the releases page.", error);
  }

  return null;
}
