export interface Release {
  tagName: string;
  installationVersion: string;
  publishedAt: string;
  htmlUrl: string;
}

interface GitHubRelease {
  tag_name?: unknown;
  published_at?: unknown;
  html_url?: unknown;
  draft?: unknown;
  prerelease?: unknown;
}

const endpoint = "https://api.github.com/repos/modern-swift-dev/pathways-swift/releases/latest";
const semanticVersionPattern = /^v?(\d+)\.(\d+)\.(\d+)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$/;
let latestReleasePromise: Promise<Release> | undefined;

async function fetchLatestRelease(): Promise<Release> {
  let response: Response;

  try {
    response = await fetch(endpoint, {
      headers: { Accept: "application/vnd.github+json" },
    });
  } catch (error) {
    throw new Error(`Could not fetch the latest Pathways release: ${String(error)}`);
  }

  if (!response.ok) {
    throw new Error(`Could not fetch the latest Pathways release: GitHub returned ${response.status} ${response.statusText}.`);
  }

  let payload: unknown;
  try {
    payload = await response.json();
  } catch (error) {
    throw new Error(`Could not parse the latest Pathways release from ${endpoint}: ${String(error)}`);
  }

  if (typeof payload !== "object" || payload === null) {
    throw new Error(`Could not use the latest Pathways release from ${endpoint}: expected a JSON object.`);
  }
  const release = payload as GitHubRelease;

  const tagName = typeof release.tag_name === "string" ? release.tag_name.trim() : "";
  const versionMatch = semanticVersionPattern.exec(tagName);
  const publishedAt = typeof release.published_at === "string" ? release.published_at : "";
  let releaseUrl: URL | undefined;
  try {
    releaseUrl = typeof release.html_url === "string" ? new URL(release.html_url) : undefined;
  } catch {
    releaseUrl = undefined;
  }

  if (
    versionMatch === null ||
    Number.isNaN(Date.parse(publishedAt)) ||
    releaseUrl?.protocol !== "https:" ||
    releaseUrl.hostname !== "github.com" ||
    !releaseUrl.pathname.startsWith("/modern-swift-dev/pathways-swift/releases/tag/") ||
    release.draft !== false ||
    release.prerelease !== false
  ) {
    throw new Error(`Could not use the latest Pathways release from ${endpoint}: expected a published, stable semantic-version release with a canonical GitHub URL.`);
  }

  return {
    tagName,
    installationVersion: `${versionMatch[1]}.${versionMatch[2]}.${versionMatch[3]}`,
    publishedAt,
    htmlUrl: releaseUrl.href,
  };
}

export function getLatestRelease(): Promise<Release> {
  latestReleasePromise ??= fetchLatestRelease();
  return latestReleasePromise;
}
