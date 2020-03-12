import path from 'path';

import * as Utils from './Utils';

export type GitLogOptions = {
  fromCommit?: string;
  toCommit?: string;
  paths?: string[];
};

export type GitLog = {
  hash: string;
  parent: string;
  title: string;
  authorName: string;
  committerRelativeDate: string;
};

export type GitFileLog = {
  path: string;
  relativePath: string;
  status: GitFileStatus;
};

export enum GitFileStatus {
  M = 'modified',
  C = 'copy',
  R = 'rename',
  A = 'added',
  D = 'deleted',
  U = 'unmerged',
}

/**
 * Returns repository's branch name that you're checked out.
 */
export async function getCurrentBranchNameAsync(): Promise<string> {
  const { stdout } = await Utils.spawnAsync('git', ['rev-parse', '--abbrev-ref', 'HEAD']);
  return stdout.replace(/\n+$/, '');
}

/**
 * Tries to deduce the SDK version from branch name. Returns null if the branch name is not a release branch.
 */
export async function getSDKVersionFromBranchNameAsync(): Promise<string | null> {
  const currentBranch = await getCurrentBranchNameAsync();
  const match = currentBranch.match(/\bsdk-(\d+)$/);

  if (match) {
    const sdkMajorNumber = match[1];
    return `${sdkMajorNumber}.0.0`;
  }
  return null;
}

/**
 * Returns full head commit hash.
 */
export async function getHeadCommitHashAsync(): Promise<string> {
  const { stdout } = await Utils.spawnAsync('git', ['rev-parse', 'HEAD']);
  return stdout.trim();
}

/**
 * Returns formatted results of `git log` command.
 */
export async function logAsync(cwd: string, options: GitLogOptions = {}): Promise<GitLog[]> {
  const fromCommit = options.fromCommit ?? '';
  const toCommit = options.toCommit ?? 'head';
  const paths = options.paths ?? ['.'];

  const format =
    ',{"hash":"%H","parent":"%P","title":"%s","authorName":"%aN","committerRelativeDate":"%cr"}';

  const { stdout } = await Utils.spawnAsync(
    'git',
    ['log', `--pretty=format:${format}`, `${fromCommit}..${toCommit}`, '--', ...paths],
    { cwd }
  );

  return JSON.parse(`[${stdout.slice(1)}]`);
}

export async function logFilesAsync(cwd: string, options: GitLogOptions): Promise<GitFileLog[]> {
  const fromCommit = options.fromCommit ?? '';
  const toCommit = options.toCommit ?? 'head';

  // This diff command returns a list of relative paths of files that have changed preceded by their status.
  // Status is just a letter, which is also a key of `GitFileStatus` enum.
  const { stdout } = await Utils.spawnAsync(
    'git',
    ['diff', '--name-status', `${fromCommit}..${toCommit}`, '--relative', '--', '.'],
    { cwd }
  );

  return stdout
    .split(/\n/g)
    .filter(Boolean)
    .map(line => {
      const [status, relativePath] = line.split(/\s+/);

      return {
        relativePath,
        path: path.join(cwd, relativePath),
        status: GitFileStatus[status],
      };
    });
}

/**
 * Simply spawns `git add` for given glob path patterns.
 */
export async function addFiles(paths: string[], options: object): Promise<void> {
  await Utils.spawnAsync('git', ['add', '--', ...paths], options);
}

/**
 * Resolves to boolean value meaning whether the repository contains any unstaged changes.
 */
export async function hasUnstagedChangesAsync(paths: string[] = []): Promise<boolean> {
  try {
    await Utils.spawnAsync('git', ['diff', '--quiet', '--', ...paths]);
    return false;
  } catch (error) {
    return true;
  }
}
