import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, readdirSync, statSync, unlinkSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import type { APIRoute } from 'astro';
import {
  BINARY_PATH,
  checkDependencies,
  DATA_DIR,
  getDownloadsDir,
  PROJECT_ROOT,
} from '../../lib/config';

interface DownloadRequest {
  urls: string;
}

/**
 * Run a command and return a promise that resolves when it completes.
 */
function runCommand(
  command: string,
  args: string[],
  cwd?: string
): Promise<{ code: number; stdout: string; stderr: string }> {
  return new Promise((resolve) => {
    const proc = spawn(command, args, {
      cwd,
      env: { ...process.env },
    });

    let stdout = '';
    let stderr = '';

    proc.stdout.on('data', (data) => {
      stdout += data.toString();
      console.log('[stdout]', data.toString());
    });

    proc.stderr.on('data', (data) => {
      stderr += data.toString();
      console.error('[stderr]', data.toString());
    });

    proc.on('close', (code) => {
      resolve({ code: code ?? 1, stdout, stderr });
    });

    proc.on('error', (err) => {
      resolve({ code: 1, stdout, stderr: err.message });
    });
  });
}

/**
 * Get list of audio files in a directory recursively.
 */
function getAudioFiles(dir: string, extensions: string[] = ['.mp3']): string[] {
  const files: string[] = [];

  if (!existsSync(dir)) {
    return files;
  }

  const entries = readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = join(dir, entry.name);
    if (entry.isDirectory()) {
      files.push(...getAudioFiles(fullPath, extensions));
    } else if (extensions.some((ext) => entry.name.endsWith(ext))) {
      files.push(fullPath);
    }
  }

  return files;
}

/**
 * Get the corresponding MP3 path for a source file (M4A/FLAC).
 */
function getMp3PathForSource(sourcePath: string): string {
  const dir = sourcePath.substring(0, sourcePath.lastIndexOf('/'));
  let filename = sourcePath.substring(sourcePath.lastIndexOf('/') + 1);

  // Remove extension
  filename = filename.substring(0, filename.lastIndexOf('.'));

  // Remove track number prefix (e.g., "01. ")
  filename = filename.replace(/^[0-9]{1,2}\. /, '');

  return join(dir, `${filename}.mp3`);
}

/**
 * Convert a single audio file to MP3 using ffmpeg.
 */
async function convertToMp3(inputPath: string): Promise<{ success: boolean; outputPath: string }> {
  const outputPath = getMp3PathForSource(inputPath);

  // Skip if MP3 already exists
  if (existsSync(outputPath)) {
    console.log(`[convert] Skipping (exists): ${outputPath}`);
    return { success: true, outputPath };
  }

  // Get extension for quality determination
  const ext = inputPath.substring(inputPath.lastIndexOf('.'));

  // Determine quality based on source format
  const isFlac = ext.toLowerCase() === '.flac';
  const qualityArgs = isFlac
    ? ['-b:a', '320k'] // FLAC -> 320kbps CBR
    : ['-q:a', '2']; // AAC/M4A -> V2 VBR (~190kbps)

  console.log(`[convert] Converting: ${inputPath} -> ${outputPath}`);

  const result = await runCommand('ffmpeg', [
    '-nostdin',
    '-i',
    inputPath,
    '-codec:a',
    'libmp3lame',
    ...qualityArgs,
    '-map_metadata',
    '0',
    '-id3v2_version',
    '3',
    '-write_id3v1',
    '1',
    '-y',
    '-loglevel',
    'error',
    outputPath,
  ]);

  if (result.code !== 0) {
    console.error(`[convert] Failed: ${inputPath}`, result.stderr);
    return { success: false, outputPath: '' };
  }

  console.log(`[convert] Success: ${outputPath}`);

  // Delete source file after successful conversion
  try {
    unlinkSync(inputPath);
    console.log(`[convert] Deleted source file: ${inputPath}`);
  } catch (err) {
    console.error(`[convert] Failed to delete source file: ${inputPath}`, err);
    // Don't fail the conversion if deletion fails
  }

  return { success: true, outputPath };
}

/**
 * Convert all FLAC and M4A files in a directory to MP3.
 */
async function convertDirectory(dir: string): Promise<string[]> {
  const sourceFiles = getAudioFiles(dir, ['.flac', '.m4a']);
  const convertedFiles: string[] = [];

  console.log(`[convert] Found ${sourceFiles.length} source file(s) to convert`);

  for (const file of sourceFiles) {
    const result = await convertToMp3(file);
    if (result.success && result.outputPath) {
      convertedFiles.push(result.outputPath);
    }
  }

  return convertedFiles;
}

/**
 * Create a zip archive of the given files.
 */
async function createZip(files: string[], outputPath: string): Promise<boolean> {
  const result = await runCommand('zip', ['-j', outputPath, ...files]);
  return result.code === 0;
}

export const POST: APIRoute = async ({ request }) => {
  try {
    // Check dependencies
    const deps = checkDependencies();
    if (!deps.ok) {
      return new Response(JSON.stringify({ error: deps.errors.join('\n') }), {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      });
    }

    // Parse request
    const body = (await request.json()) as DownloadRequest;
    const urlsRaw = body.urls || '';

    // Parse and validate URLs
    const urls = urlsRaw
      .split('\n')
      .map((u: string) => u.trim())
      .filter(
        (u: string) => u.length > 0 && (u.includes('beatport.com') || u.includes('beatsource.com'))
      );

    if (urls.length === 0) {
      return new Response(
        JSON.stringify({ error: 'No valid Beatport/Beatsource URLs provided.' }),
        {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Generate job ID
    const jobId = `job-${Date.now()}`;

    // Ensure data directory exists
    mkdirSync(DATA_DIR, { recursive: true });

    // Write URLs to a temp file for this job
    const urlsFilePath = join(DATA_DIR, `${jobId}-urls.txt`);
    writeFileSync(urlsFilePath, urls.join('\n'), 'utf-8');

    // Get downloads directory before running (to know where files will be)
    const downloadsDir = getDownloadsDir();
    console.log(`[${jobId}] Downloads directory: ${downloadsDir}`);

    // Get list of existing MP3 files before download (to compare later)
    const existingMp3s = new Set(getAudioFiles(downloadsDir, ['.mp3']));
    console.log(`[${jobId}] Existing MP3 files: ${existingMp3s.size}`);

    // Run BeatportDL binary
    console.log(`[${jobId}] Starting download with ${urls.length} URL(s)...`);
    const downloadResult = await runCommand(BINARY_PATH, ['-q', urlsFilePath], PROJECT_ROOT);

    if (downloadResult.code !== 0) {
      console.error(`[${jobId}] Download failed:`, downloadResult.stderr);
      return new Response(
        JSON.stringify({
          error: 'Download failed. Check your Beatport credentials and subscription.',
          details: downloadResult.stderr,
        }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    console.log(`[${jobId}] Download complete, checking for source files...`);

    // Check what files were downloaded
    const downloadedFlac = getAudioFiles(downloadsDir, ['.flac']);
    const downloadedM4a = getAudioFiles(downloadsDir, ['.m4a']);
    console.log(
      `[${jobId}] Downloaded: ${downloadedFlac.length} FLAC, ${downloadedM4a.length} M4A`
    );

    // Run conversion natively
    console.log(`[${jobId}] Starting conversion...`);
    const convertedFiles = await convertDirectory(downloadsDir);
    console.log(`[${jobId}] Conversion complete: ${convertedFiles.length} file(s)`);

    // Get all MP3 files after conversion
    const allMp3s = getAudioFiles(downloadsDir, ['.mp3']);
    console.log(`[${jobId}] Total MP3 files now: ${allMp3s.length}`);

    // Find newly created MP3 files
    let newFiles = allMp3s.filter((f) => !existingMp3s.has(f));
    console.log(`[${jobId}] New MP3 files: ${newFiles.length}`);

    if (newFiles.length === 0) {
      // If no new MP3s, check for recently downloaded source files and use their corresponding MP3s
      const fiveMinutesAgo = Date.now() - 5 * 60 * 1000;
      const allSourceFiles = getAudioFiles(downloadsDir, ['.m4a', '.flac']);
      const recentSourceFiles = allSourceFiles.filter((f) => {
        const mtime = statSync(f).mtimeMs;
        return mtime > fiveMinutesAgo;
      });

      if (recentSourceFiles.length > 0) {
        // Find corresponding MP3 files for the recent source files (use existing MP3s)
        console.log(`[${jobId}] Looking for corresponding MP3 files for ${recentSourceFiles.length} recent source file(s)...`);
        const correspondingMp3s = recentSourceFiles
          .map((sourceFile) => getMp3PathForSource(sourceFile))
          .filter((mp3Path) => existsSync(mp3Path));
        
        console.log(`[${jobId}] Found ${correspondingMp3s.length} existing MP3 file(s) for recent downloads`);
        newFiles = correspondingMp3s;
      } else {
        // If no new MP3s, maybe include all recent MP3 files
        const filesWithTime = allMp3s.map((f) => ({
          path: f,
          mtime: statSync(f).mtimeMs,
        }));
        filesWithTime.sort((a, b) => b.mtime - a.mtime);

        // Take files modified in the last 5 minutes
        const recentFiles = filesWithTime.filter((f) => f.mtime > fiveMinutesAgo).map((f) => f.path);
        console.log(`[${jobId}] Recent MP3 files (last 5 min): ${recentFiles.length}`);

        if (recentFiles.length === 0) {
          return new Response(
            JSON.stringify({
              error:
                'No audio files were created. The tracks may already exist or download failed.',
              debug: {
                downloadsDir,
                existingMp3Count: existingMp3s.size,
                downloadedFlac: downloadedFlac.length,
                downloadedM4a: downloadedM4a.length,
                convertedCount: convertedFiles.length,
                totalMp3s: allMp3s.length,
              },
            }),
            {
              status: 500,
              headers: { 'Content-Type': 'application/json' },
            }
          );
        } else {
          newFiles = recentFiles;
        }
      }
    }

    // Create zip file
    const zipPath = join(DATA_DIR, `${jobId}.zip`);
    console.log(`[${jobId}] Creating zip with ${newFiles.length} file(s)...`);
    const zipSuccess = await createZip(newFiles, zipPath);

    if (!zipSuccess) {
      return new Response(
        JSON.stringify({
          error: 'Failed to create zip archive.',
        }),
        {
          status: 500,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    console.log(`[${jobId}] Job complete! ${newFiles.length} file(s) packaged.`);

    // Clean up temp URLs file
    try {
      const { unlinkSync } = await import('node:fs');
      unlinkSync(urlsFilePath);
    } catch {
      // Ignore cleanup errors
    }

    return new Response(
      JSON.stringify({
        jobId,
        fileCount: newFiles.length,
      }),
      {
        status: 200,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  } catch (err) {
    console.error('Download API error:', err);
    return new Response(
      JSON.stringify({
        error: err instanceof Error ? err.message : 'An unexpected error occurred',
      }),
      {
        status: 500,
        headers: { 'Content-Type': 'application/json' },
      }
    );
  }
};
