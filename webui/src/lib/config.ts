import { arch } from 'node:os';
import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';

/** Project root (one level up from webui/) */
export const PROJECT_ROOT = join(import.meta.dirname, '..', '..', '..');

/**
 * Get the appropriate BeatportDL binary path based on architecture.
 * Can be overridden via BEATPORTDL_BINARY_PATH env var.
 */
function getBinaryPath(): string {
  const envOverride = process.env.BEATPORTDL_BINARY_PATH;
  if (envOverride) {
    return envOverride;
  }
  const defaultBinaryName = arch() === 'arm64' ? 'beatportdl-linux-arm64' : 'beatportdl-linux-amd64';
  return join(PROJECT_ROOT, 'bin', defaultBinaryName);
}

/** Path to the BeatportDL binary */
export const BINARY_PATH = getBinaryPath();

/** Path to the BeatportDL config file */
export const CONFIG_PATH = join(homedir(), '.config', 'beatportdl', 'beatportdl-config.yml');

/** Fallback downloads directory */
export const DEFAULT_DOWNLOADS_DIR = join(homedir(), 'Downloads', 'beatportdl');

/** Path to the convert script (used as fallback) */
export const CONVERT_SCRIPT_PATH = join(PROJECT_ROOT, 'scripts', 'convert_to_mp3.sh');

/** Temporary data directory for storing job results */
export const DATA_DIR = join(PROJECT_ROOT, 'webui', '.data');

export interface BeatportConfig {
  downloads_directory?: string;
  quality?: string;
}

/**
 * Parse the beatportdl YAML config to extract settings.
 * Simple YAML parsing for key: value lines.
 */
export function parseConfig(): BeatportConfig {
  if (!existsSync(CONFIG_PATH)) {
    return {};
  }
  const content = readFileSync(CONFIG_PATH, 'utf-8');
  const config: BeatportConfig = {};

  for (const line of content.split('\n')) {
    const match = line.match(/^(\w+):\s*(.+)$/);
    if (match) {
      const [, key, value] = match;
      const cleanValue = value.replace(/^["']|["']$/g, '').trim();
      if (key === 'downloads_directory') {
        config.downloads_directory = cleanValue;
      } else if (key === 'quality') {
        config.quality = cleanValue;
      }
    }
  }
  return config;
}

/**
 * Get the downloads directory from config or default.
 */
export function getDownloadsDir(): string {
  const config = parseConfig();
  return config.downloads_directory || DEFAULT_DOWNLOADS_DIR;
}

/**
 * Check if required dependencies are available.
 */
export function checkDependencies(): { ok: boolean; errors: string[] } {
  const errors: string[] = [];

  if (!existsSync(BINARY_PATH)) {
    errors.push(`BeatportDL binary not found at ${BINARY_PATH}. Please build it first.`);
  }

  if (!existsSync(CONFIG_PATH)) {
    errors.push(`Config file not found at ${CONFIG_PATH}. Please run create_config.sh first.`);
  }

  return { ok: errors.length === 0, errors };
}
