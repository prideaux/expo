import basicSpawnAsync from '@expo/spawn-async';

import { EXPO_DIR } from './Constants';

/**
 * Asynchronously spawns a process with given command, args and options. Working directory is set to repo's root by default.
 */
export async function spawnAsync(
  command: string,
  args: Readonly<string[]> = [],
  options: object = {}
) {
  return await basicSpawnAsync(command, args, {
    cwd: EXPO_DIR,
    ...options,
  });
}

/**
 * Does the same as `spawnAsync` but parses the output to JSON object.
 */
export async function spawnJSONCommandAsync(
  command: string,
  args: Readonly<string[]> = [],
  options: object = {}
) {
  const child = await spawnAsync(command, args, {
    cwd: EXPO_DIR,
    ...options,
  });
  return JSON.parse(child.stdout);
}

/**
 * Deeply clones an object. It's used to make a backup of home's `app.json` file.
 */
export function deepCloneObject<ObjectType extends object = object>(
  object: ObjectType
): ObjectType {
  return JSON.parse(JSON.stringify(object));
}
