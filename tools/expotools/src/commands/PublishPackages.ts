import path from 'path';
import fs from 'fs-extra';
import chalk from 'chalk';
import semver from 'semver';
import { set } from 'lodash';
import inquirer from 'inquirer';
import JsonFile from '@expo/json-file';
import { Command } from '@expo/commander';
import * as jsondiffpatch from 'jsondiffpatch';

import * as Npm from '../Npm';
import * as Git from '../Git';
import * as Utils from '../Utils';
import * as Workspace from '../Workspace';
import * as Formatter from '../Formatter';
import * as Changelogs from '../Changelogs';
import { EXPOTOOLS_DIR, EXPO_DIR } from '../Constants';
import { Package, getListOfPackagesAsync } from '../Packages';

const { green, yellow, cyan, blue, magenta, red } = chalk;
const BACKUP_FILE_NAME = '.publish-packages.backup.json';
const BACKUP_PATH = path.join(EXPOTOOLS_DIR, BACKUP_FILE_NAME);
const BACKUP_EXPIRATION_TIME = 30 * 60 * 1000; // 30 minutes

/**
 * An array of directories treated as containing native code.
 */
const NATIVE_DIRECTORIES = ['ios', 'android'];

type ActionOptions = {
  listUnpublished: boolean;
  prerelease: boolean | string;
  exclude: string;
  scope: string;
  retry: boolean;
  skipRepoChecks: boolean;
  dry: boolean;
};

type BackupableOptions = Pick<ActionOptions, 'scope' | 'exclude' | 'dry'>;

type PackageState = {
  hasUnpublishedChanges?: boolean;
  isSelectedToPublish?: boolean;
  changelogChanges?: Changelogs.ChangelogChanges;
  integral?: boolean;
  logs?: Git.GitLog[];
  fileLogs?: Git.GitFileLog[];
  releaseType?: ReleaseType;
  releaseVersion?: string | null;
};

type PackageFabric = {
  // Required keys that are assigned during data preparing phase.
  pkg: Package;
  pkgView: Npm.PackageViewType | null;
  changelog: Changelogs.Changelog;

  // Fields defined at later steps are being stored as serializable `state` object.
  state: PackageState;
};

type Fabrics = PackageFabric[];

type StateBackup = {
  timestamp: number;
  head: string;
  phaseIndex: number;
  options: BackupableOptions;
  state: {
    [key: string]: PackageState;
  };
};

// @tsapeta: rethink that enum approach?
enum ReleaseType {
  MAJOR = 'major',
  MINOR = 'minor',
  PATCH = 'patch',
  PREMAJOR = 'premajor',
  PREMINOR = 'preminor',
  PREPATCH = 'prepatch',
}

/**
 * Checks whether the command is run on master branch.
 * Otherwise, it prompts to confirm that you know what you're doing.
 */
async function checkBranchNameAsync(): Promise<boolean> {
  const branchName = await Git.getCurrentBranchNameAsync();

  if (branchName === 'master') {
    return true;
  }

  console.log(yellow.bold(`⚠️  It's recommended to publish from ${blue('master')} branch,`));

  const { confirmed } = await inquirer.prompt<{ confirmed: boolean }>([
    {
      type: 'confirm',
      name: 'confirmed',
      prefix: yellow('⚠️ '),
      message: yellow(`while you're at ${blue(branchName)}. Do you want to proceed?`),
      default: true,
    },
  ]);
  console.log();
  return confirmed;
}

/**
 * Gets a list of public packages in the monorepo,
 * downloads `npm view` result of them and creates Changelog instance.
 */
async function preparePackageFabricsAsync(options: ActionOptions): Promise<Fabrics> {
  const exclude = options.exclude?.split(/\s*,\s*/g) ?? [];
  const scope = options.scope?.split(/\s*,\s*/g) ?? null;

  console.log('🔎 Gathering data about packages...\n');

  const packages = (await getListOfPackagesAsync()).filter(pkg => {
    const isPrivate = pkg.packageJson.private;
    const isScoped = !scope || scope.includes(pkg.packageName);
    const isExcluded = exclude.includes(pkg.packageName);
    return !isPrivate && isScoped && !isExcluded;
  });

  const fabrics = await Promise.all(
    packages.map(
      async (pkg: Package): Promise<PackageFabric> => {
        const pkgView = await Npm.getPackageViewAsync(pkg.packageName, pkg.packageVersion);
        const changelog = Changelogs.loadFrom(pkg.changelogPath);
        const state = {};

        return { pkg, pkgView, changelog, state };
      }
    )
  );
  return fabrics;
}

/**
 * Checks packages integrity - package is integral if `gitHead` in `package.json` matches `gitHead`
 * of the package published under current version specified in `package.json`.
 */
function checkPackagesIntegrity(fabrics: Fabrics): void {
  for (const { pkg, pkgView, state } of fabrics) {
    state.integral = !pkgView || pkg.packageJson.gitHead === pkgView.gitHead;

    if (!state.integral) {
      console.log(
        yellow(`Package integrity check failed for ${green(pkg.packageName)}, git heads mismatch.`)
      );
      console.log(
        yellow(
          `Published head: ${green(pkgView?.gitHead)}, currently in the repo: ${green(
            pkg.packageJson.gitHead
          )}`
        )
      );
    }
  }
}

/**
 * Finds unpublished packages. Package is considered unpublished if there are
 * any new commits or changelog entries prior to previous publish on the current branch.
 */
async function findUnpublishedPackagesAsync(
  fabrics: Fabrics,
  options: ActionOptions
): Promise<void> {
  for (const { pkg, changelog, state } of fabrics) {
    const changelogChanges = await changelog.getChangesAsync();
    const logs = await Git.logAsync(pkg.path, {
      fromCommit: pkg.packageJson.gitHead,
      toCommit: 'head',
    });

    const fileLogs = await Git.logFilesAsync(pkg.path, {
      fromCommit: logs[logs.length - 1]?.hash,
      toCommit: logs[0]?.hash,
    });

    // Remove last commit from logs if `gitHead` is present.
    // @tsapeta: Actually we should check whether last's commit parent is equal to `gitHead`,
    // but that wasn't true prior to publish-packages v2.
    if (pkg.packageJson.gitHead) {
      logs.pop();
    }

    state.logs = logs;
    state.fileLogs = fileLogs;
    state.changelogChanges = changelogChanges;
    state.hasUnpublishedChanges = logs.length > 0 || changelogChanges.totalCount > 0;
    state.releaseType = getSuggestedReleaseType(pkg.packageVersion, fileLogs, changelogChanges);
    state.releaseVersion = semver.inc(pkg.packageVersion, state.releaseType);

    if (!state.releaseType || !state.releaseVersion) {
      // @tsapeta: throw an error?
      continue;
    }

    // If `--prerelease` is provided and the current version isn't a prerelease,
    // then we just get the suggested version and increment it again with prerelease option.
    const prerelease = options.prerelease === true ? 'rc' : options.prerelease;
    if (prerelease && state.releaseVersion && state.releaseType) {
      state.releaseType = ReleaseType.PRERELEASE;
      state.releaseVersion = semver.inc(state.releaseVersion, state.releaseType, prerelease);
    }
  }
}

/**
 * Lists packages that have any unpublished changes.
 */
async function listUnpublishedPackages(fabrics: Fabrics): Promise<void> {
  const unpublished = fabrics.filter(({ state }) => state.hasUnpublishedChanges);

  if (unpublished.length === 0) {
    console.log(cyan('🥳 All packages are up-to-date.\n'));
    return;
  }

  console.log(cyan('🧩 Unpublished packages:\n'));
  unpublished.forEach(fabric => printPackageFabric(fabric.pkg, fabric.state));
  console.log();
}

/**
 * Prints gathered crucial informations about the package.
 */
function printPackageFabric(pkg: Package, state: PackageState) {
  const { logs, fileLogs, changelogChanges, releaseType } = state;

  console.log(
    '📦',
    green.bold(pkg.packageName),
    `has some changes since ${cyan.bold(pkg.packageVersion)}`
  );

  console.log(yellow(' >'), magenta.bold('New commits:'));

  // eslint-disable-next-line no-unused-expressions
  logs?.forEach(log => {
    console.log(yellow('   -'), Formatter.formatCommitLog(log));
  });

  const masterChanges = changelogChanges?.versions.master ?? {};

  for (const changeType in masterChanges) {
    const changes = masterChanges[changeType];

    if (changes.length > 0) {
      console.log(
        yellow(' >'),
        magenta.bold(`${Formatter.stripNonAsciiChars(changeType).trim()}:`)
      );

      for (const change of masterChanges[changeType]) {
        console.log(yellow('   -'), Formatter.formatChangelogEntry(change));
      }
    }
  }

  if (fileLogs?.length) {
    console.log(yellow(' >'), magenta.bold('File changes:'));

    // eslint-disable-next-line no-unused-expressions
    fileLogs?.forEach(fileLog => {
      console.log(yellow('   -'), Formatter.formatFileLog(fileLog));
    });
  }

  if (releaseType) {
    const version = pkg.packageVersion;
    const suggestedVersion = semver.inc(version, releaseType);

    console.log(
      yellow(' >'),
      magenta.bold(
        `Suggested ${cyan(releaseType)} upgrade from ${cyan(version)} to ${cyan(suggestedVersion!)}`
      )
    );
  }

  console.log();
}

function getSuggestedReleaseType(
  currentVersion: string,
  fileLogs?: Git.GitFileLog[],
  changelogChanges?: Changelogs.ChangelogChanges
  prerelease: boolean | string,
): ReleaseType {
  if (semver.prerelease(currentVersion)) {
    return ReleaseType.PRERELEASE;
  }
  if (changelogChanges?.versions.master?.[Changelogs.ChangeType.BREAKING_CHANGES]?.length) {
    return ReleaseType.MAJOR;
  }
  if (fileLogs && fileLogsContainNativeChanges(fileLogs)) {
    return ReleaseType.MINOR;
  }
  return ReleaseType.PATCH;
}

function fileLogsContainNativeChanges(fileLogs: Git.GitFileLog[]): boolean {
  return fileLogs.some(fileLog => {
    return NATIVE_DIRECTORIES.some(dir => fileLog.relativePath.startsWith(`${dir}/`));
  });
}

// function formatPackageChangesDescription(fabric: PackageFabric): string {
//   const lines: string[] = [];

//   const { pkg, state } = fabric;
//   const { logs, changelogChanges } = state;

//   lines.push(green.bold(pkg.packageName));

//   lines.push(yellow('  > ') + magenta.bold(`New commits since ${cyan.bold(pkg.packageVersion)}:`));

//   // eslint-disable-next-line no-unused-expressions
//   logs?.all?.forEach(log => {
//     lines.push(yellow('    - ') + reset(Formatter.formatCommitLog(log)));
//   });

//   const masterChanges = changelogChanges?.versions.master ?? {};

//   for (const changeType in masterChanges) {
//     const changes = masterChanges[changeType];

//     if (changes.length > 0) {
//       lines.push(
//         yellow('  > ') + magenta.bold(`${Formatter.stripNonAsciiChars(changeType).trim()}:`)
//       );

//       for (const change of masterChanges[changeType]) {
//         lines.push(yellow('    - ') + reset(Formatter.formatChangelogEntry(change)));
//       }
//     }
//   }
//   return lines.join('\n');
// }

async function findDependantPackagesAsync(fabrics: Fabrics): Promise<void> {
  // nothing yet
}

/**
 * Prompts which suggested packages are going to be published.
 */
async function choosePackagesToPublishAsync(fabrics: Fabrics): Promise<void> {
  const unpublished = fabrics.filter(({ state }) => state.hasUnpublishedChanges);

  if (unpublished.length === 0) {
    return;
  }

  console.log('👉 Choosing packages to publish...\n');

  for (const { pkg, state } of unpublished) {
    printPackageFabric(pkg, state);

    const { selected } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'selected',
        prefix: '❔',
        message: `Do you want to publish ${green.bold(pkg.packageName)} as version ${cyan.bold(
          state.releaseVersion!
        )}?`,
        default: true,
      },
    ]);
    console.log();

    state.isSelectedToPublish = selected;
  }
}

/**
 * Updates versions in packages selected to be published.
 */
async function updateVersionsAsync(fabrics: Fabrics): Promise<void> {
  for (const { pkg, state } of fabrics) {
    const gitHead = state.logs?.[0]?.hash ?? pkg.packageJson.gitHead;

    if (!gitHead || !state.releaseVersion) {
      // TODO: do it better
      continue;
    }

    // Make a deep clone of `package.json` - `pkg.packageJson` should stay immutable.
    const packageJson = Utils.deepCloneObject(pkg.packageJson);

    console.log(
      `📦 Updating ${magenta.bold('package.json')} in ${green.bold(pkg.packageName)} with...`
    );

    const update = {
      version: state.releaseVersion,
      gitHead,
    };

    for (const key in update) {
      console.log(yellow(' >'), `${yellow.bold(key)}: ${cyan.bold(update[key])}`);
      set(packageJson, key, update[key]);
    }

    // Saving new contents of `package.json`.
    await JsonFile.writeAsync(path.join(pkg.path, 'package.json'), packageJson);

    console.log();
  }
}

/**
 * Updates `bundledNativeModules.json` file in `expo` package.
 * It's used internally by some `expo-cli` commands so we know which package versions are compatible with `expo` version.
 */
async function updateBundledNativeModulesFileAsync(fabrics: Fabrics): Promise<void> {
  const toPublish = fabrics.filter(({ state }) => state.isSelectedToPublish);

  if (toPublish.length === 0) {
    return;
  }

  const bundledNativeModulesPath = path.join(EXPO_DIR, 'packages/expo/bundledNativeModules.json');
  const bundledNativeModules = await JsonFile.readAsync(bundledNativeModulesPath);

  console.log(`✏️  Updating ${magenta.bold('bundledNativeModules.json')} file...`);

  for (const { pkg, state } of toPublish) {
    const versionRange = `~${state.releaseVersion}`;

    bundledNativeModules[pkg.packageName] = versionRange;
    console.log(yellow(' >'), `${yellow.bold(pkg.packageName)}: ${cyan.bold(versionRange)}`);
  }
  await JsonFile.writeAsync(bundledNativeModulesPath, bundledNativeModules);
  console.log();
}

/**
 * Updates versions of packages to be published in other workspace projects depending on them.
 */
async function updateWorkspaceDependenciesAsync(fabrics: Fabrics): Promise<void> {
  const workspaceInfo = await Workspace.getInfoAsync();
  console.log(workspaceInfo);
}

async function publishPackagesAsync(fabrics: Fabrics): Promise<void> {
  // nothing yet
}

async function backupExistsAsync(): Promise<boolean> {
  try {
    await fs.access(BACKUP_PATH, fs.constants.R_OK);
    return true;
  } catch (error) {
    return false;
  }
}

function isBackupValid(backup: StateBackup, currentHead: string, options: ActionOptions): boolean {
  if (currentHead !== backup.head || Date.now() - backup.timestamp > BACKUP_EXPIRATION_TIME) {
    return false;
  }
  const delta = jsondiffpatch.diff(pickBackupableOptions(options), backup.options);

  if (delta) {
    console.warn(
      yellow(
        `⚠️  Found backup file but you've run the command with different options. Continuing from scratch...\n`
      )
    );
    return false;
  }
  return true;
}

/**
 * Returns command's backup if it exists and is still valid, `null` otherwise.
 * Backup is valid if current head commit hash is the same as from the time where the backup was saved,
 * and if the time difference is no longer than `BACKUP_EXPIRATION_TIME`.
 */
async function maybeRestoreBackupAsync(
  currentHead: string,
  options: ActionOptions
): Promise<StateBackup | null> {
  if (!(await backupExistsAsync())) {
    return null;
  }
  const backup = await JsonFile.readAsync<StateBackup>(BACKUP_PATH);

  if (!isBackupValid(backup, currentHead, options)) {
    return null;
  }
  if (options.retry) {
    return backup;
  }
  const { restore } = await inquirer.prompt([
    {
      type: 'confirm',
      name: 'restore',
      prefix: '❔',
      message: cyan('Found valid backup file. Would you like to use it?'),
    },
  ]);
  console.log();
  return restore ? backup : null;
}

/**
 * Returns options that are capable of being backed up.
 * We will need just a few options to determine whether the backup is valid
 * and we can't pass them all because `options` is in fact commander's `Command` instance.
 */
function pickBackupableOptions({ scope, exclude, dry }: ActionOptions): BackupableOptions {
  return { scope, exclude, dry };
}

/**
 * Saves backup of command's state.
 * This method is synchronous as we must be able to complete it immediately before exiting the process.
 */
function saveBackup(head: string, phaseIndex: number, fabrics: Fabrics, options: ActionOptions) {
  const backup: StateBackup = {
    timestamp: Date.now(),
    head,
    phaseIndex,
    options: pickBackupableOptions(options),
    state: {},
  };

  for (const { pkg, state } of fabrics) {
    backup.state[pkg.packageName] = JSON.parse(JSON.stringify(state));
  }
  fs.outputFileSync(BACKUP_PATH, JSON.stringify(backup, null, 2));
}

/**
 * Main action of the command.
 */
async function action(options: ActionOptions): Promise<void> {
  if (!options.skipRepoChecks) {
    if (!(await checkBranchNameAsync())) {
      return;
    }
    if (await Git.hasUnstagedChangesAsync()) {
      console.error(
        red.bold(`🚫 Repository contains unstaged changes, please make sure to have it clear.\n`)
      );
      return;
    }
  }

  const headCommitHash = await Git.getHeadCommitHashAsync();
  const fabrics = await preparePackageFabricsAsync(options);

  if (options.listUnpublished) {
    await findUnpublishedPackagesAsync(fabrics);
    listUnpublishedPackages(fabrics);
    return;
  }

  const phases: ((fabrics: Fabrics, options: ActionOptions) => any)[] = [
    checkPackagesIntegrity,
    findUnpublishedPackagesAsync,
    // findDependantPackagesAsync,
    choosePackagesToPublishAsync,
    updateVersionsAsync,
    updateBundledNativeModulesFileAsync,
    // updateWorkspaceDependenciesAsync,
    // commitChangesAsync,
    // publishPackagesAsync,
  ];
  const backup = await maybeRestoreBackupAsync(headCommitHash, options);
  let phaseIndex = 0;

  if (backup) {
    const dateString = new Date(backup.timestamp).toLocaleString();

    console.log(cyan(`♻️  Restoring from backup saved on ${magenta(dateString)}...\n`));
    phaseIndex = backup.phaseIndex;

    for (const item of fabrics) {
      const restoredState = backup.state[item.pkg.packageName];

      if (restoredState) {
        item.state = { ...item.state, ...restoredState };
      }
    }
  }

  for (; phaseIndex < phases.length; phaseIndex++) {
    try {
      await phases[phaseIndex](fabrics, options);
    } catch (error) {
      console.error(red(error.stack));
      console.log(red(`🛑 Command failed at phase ${cyan('' + phaseIndex)}.`));
      process.exit(1);
    }

    // Make a backup after each successful phase.
    saveBackup(headCommitHash, phaseIndex, fabrics, options);
  }
  await fs.remove(BACKUP_PATH);
}

export default (program: Command) => {
  program
    .command('publish-packages')
    .alias('pub-pkg', 'pp')
    .option(
      '-l, --list-unpublished',
      'Lists packages that some changes have been applied since the previous published version.',
      false
    )
    .option(
      '-p, --prerelease [string]',
      'If used, the default new version will be a prerelease version like `1.0.0-rc.0`. You can pass another string if you want prerelease identifier other than `rc`.',
      false
    )
    .option(
      '-s, --scope [string]',
      "Comma-separated names of packages to be published. By default, it's trying to publish all public packages that have unpublished changes.",
      ''
    )
    .option(
      '-e, --exclude [string]',
      'Comma-separated names of packages to be excluded from publish. It has a higher precedence than `scope` flag.',
      ''
    )
    .option(
      '-r, --retry',
      `Retries previous call from the state saved before the phase at which the process has stopped. Some other options like ${magenta.italic(
        '--scope'
      )} and ${magenta.italic('--exclude')} must stay the same.`,
      false
    )
    .option(
      '--skip-repo-checks',
      'Skips checking whether the command is run on master branch and there are no unstaged changes.',
      false
    )
    .option(
      '-d, --dry',
      'Whether to skip `npm publish` command. Despite this, some files might be changed after running this script.',
      false
    )
    .description(
      // prettier-ignore
      `This script publishes packages within the monorepo and takes care of bumping version numbers,
updating other workspace projects, committing and pushing changes to remote repo.

As it's prone to errors due to its complexity and the fact it sometimes may take some time, we made it stateful.
It's been splitted into a few phases after each a backup is saved under ${magenta.bold(path.relative(EXPO_DIR, BACKUP_PATH))} file
and all file changes it made are added to Git's index as part of the backup. Due to its stateful nature,
your local repo must be clear (without unstaged changes) and you shouldn't make any changes in the repo when the command is running.

In case of any errors or mistakes you can always go back to the previous phase with ${magenta.italic('--retry')} flag,
but remember to leave staged changes as they were because they're also part of the backup.`
    )
    .asyncAction(action);
};
