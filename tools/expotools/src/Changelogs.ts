import fs from 'fs-extra';
import * as Markdown from './Markdown';

/**
 * Type of the objects representing changelog entries.
 */
export type ChangelogChanges = {
  totalCount: number;
  versions: {
    [key: string]: {
      [key in ChangeType]?: string[];
    };
  };
};

/**
 * Enum with changelog sections that are commonly used by us.
 */
export enum ChangeType {
  BREAKING_CHANGES = '🛠 Breaking changes',
  NEW_FEATURES = '🎉 New features',
  BUG_FIXES = '🐛 Bug fixes',
}

/**
 * Depth of headings that mean the version containing following changes.
 */
const VERSION_HEADING_DEPTH = 2;

/**
 * Depth of headings that are being recognized as the type of changes (breaking changes, new features of bugfixes).
 */
const CHANGE_TYPE_HEADING_DEPTH = 3;

/**
 * Class representing a changelog.
 */
export class Changelog {
  filePath: string;
  tokens: Markdown.Token[] | null = null;

  constructor(filePath: string) {
    this.filePath = filePath;
  }

  async getChangesAsync(
    fromVersion?: string,
    toVersion: string = 'master'
  ): Promise<ChangelogChanges> {
    const tokens = await this.getTokensAsync();
    const versions = {};
    const changes: ChangelogChanges = { totalCount: 0, versions };

    let currentVersion: string | null = null;
    let currentSection: string | null = null;

    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i];

      if (token.type === Markdown.TokenType.HEADING) {
        if (token.depth === VERSION_HEADING_DEPTH) {
          if (token.text !== toVersion && (!fromVersion || token.text === fromVersion)) {
            // We've iterated over everything we needed, stop the loop.
            break;
          }

          currentVersion = token.text;
          currentSection = null;

          if (!versions[currentVersion]) {
            versions[currentVersion] = {};
          }
        } else if (currentVersion && token.depth === CHANGE_TYPE_HEADING_DEPTH) {
          currentSection = token.text;

          if (!versions[currentVersion][currentSection]) {
            versions[currentVersion][currentSection] = [];
          }
        }
        continue;
      }

      if (currentVersion && currentSection && token.type === Markdown.TokenType.LIST_ITEM_START) {
        i++;
        for (; tokens[i].type !== Markdown.TokenType.LIST_ITEM_END; i++) {
          const token = tokens[i] as Markdown.TextToken;

          if (token.text) {
            changes.totalCount++;
            versions[currentVersion][currentSection].push(token.text);
          }
        }
      }
    }
    return changes;
  }

  async getTokensAsync(): Promise<Markdown.Token[]> {
    if (!this.tokens) {
      await fs.access(this.filePath, fs.constants.R_OK);
      this.tokens = Markdown.lexify(await fs.readFile(this.filePath, 'utf8'));
    }
    return this.tokens;
  }
}

/**
 * Convenient method creating `Changelog` instance.
 */
export function loadFrom(path: string): Changelog {
  return new Changelog(path);
}
