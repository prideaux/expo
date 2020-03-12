import { spawnAsync, spawnJSONCommandAsync } from './Utils';
import { Package } from './Packages';

export type PackageViewType = {
  name: string;
  'dist-tags': { [tag: string]: string };
  versions: string[];
  time: {
    created: string;
    modified: string;
    [time: string]: string;
  };
  maintainers: string[];
  description: string;
  author: string;
  // and more but these are the basic ones, we shouldn't need more.
  [key: string]: any;
};

/**
 * Runs `npm view` for package with given name. Returns null if package is not published yet.
 */
export async function getPackageViewAsync(
  packageName: string,
  version?: string
): Promise<PackageViewType | null> {
  try {
    return await spawnJSONCommandAsync('npm', [
      'view',
      version ? `${packageName}@${version}` : packageName,
      '--json',
    ]);
  } catch (error) {
    return null;
  }
}

export async function packAsync(pkg: Package): Promise<string> {
  await spawnAsync('npm', ['pack'], { cwd: pkg.path, stdio: 'ignore' });
  return `${pkg.packageName}-${pkg.packageVersion}.tgz`;
}
