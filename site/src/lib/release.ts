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

type MacDownload = { url: string; version: string; releaseUrl: string };

export async function getMacDownloads() {
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

    let arm64: MacDownload | undefined;
    let intel: MacDownload | undefined;
    for (const release of releases) {
      if (release.draft || !release.published_at) continue;
      const uploaded = release.assets.filter(({ state }) => state === "uploaded");
      const universal = uploaded.find(({ name }) => /^EvaBar(?:-.+)?-universal\.(zip|dmg)$/i.test(name));
      const arm64Asset = uploaded.find(({ name }) => /^EvaBar(?:-.+)?-arm64\.(zip|dmg)$/i.test(name)) ?? universal;
      const intelAsset = uploaded.find(({ name }) => /^EvaBar(?:-.+)?-(x86_64|intel)\.(zip|dmg)$/i.test(name)) ?? universal;
      const releaseDetails = { version: release.tag_name, releaseUrl: release.html_url };
      if (!arm64 && arm64Asset) {
        arm64 = { url: arm64Asset.browser_download_url, ...releaseDetails };
      }
      if (!intel && intelAsset) {
        intel = { url: intelAsset.browser_download_url, ...releaseDetails };
      }
      if (arm64 && intel) break;
    }
    if (arm64 || intel) return { arm64, intel };
  } catch (error) {
    console.warn("Could not fetch EvaBar releases. Linking to the releases page.", error);
  }

  return null;
}
