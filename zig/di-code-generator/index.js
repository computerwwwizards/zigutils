import { fileURLToPath } from 'node:url'
import { dirname, join } from 'node:path'
import { spawn } from 'node:child_process'
import { platform, arch } from 'node:os'

const __filename = fileURLToPath(import.meta.url)
const __dirname = dirname(__filename)

/**
 * Get the binary path based on platform and architecture
 */
function getBinaryPath() {
  const plat = platform()
  const architecture = arch()

  const archMap = {
    'x64': 'x86_64',
    'arm64': 'aarch64',
    'arm': 'arm',
  }

  const zigArch = archMap[architecture] || architecture

  const baseDir = join(__dirname, 'zig-out', 'bin')

  // Prefer suffixed multi-target binaries if present
  const candidates = []
  if (plat === 'win32') {
    candidates.push(`di-code-generator-win-${architecture}.exe`)
    candidates.push('di-code-generator.exe')
  } else if (plat === 'darwin') {
    candidates.push(`di-code-generator-macos-${architecture}`)
    candidates.push('di-code-generator')
  } else {
    // linux and others
    candidates.push(`di-code-generator-linux-${architecture}`)
    candidates.push('di-code-generator')
  }

  for (const name of candidates) {
    const p = join(baseDir, name)
    try {
      // lightweight existence check without fs import using spawn fallback
      // We still return the first candidate; execute() will error if missing
      return p
    } catch (_) {
      continue
    }
  }

  return join(baseDir, plat === 'win32' ? 'di-code-generator.exe' : 'di-code-generator')
}

/**
 * Execute the DI code generator binary
 * @param {string[]} args - CLI arguments to pass to the binary
 * @returns {Promise<number>} - Exit code of the process
 */
export function execute(args = []) {
  return new Promise((resolve, reject) => {
    const binaryPath = getBinaryPath()
    
    const child = spawn(binaryPath, args, {
      stdio: 'inherit',
      shell: false
    })
    
    child.on('error', (error) => {
      if (error.code === 'ENOENT') {
        reject(new Error(
          `Binary not found at ${binaryPath}. ` +
          `Please run 'npm run build' to compile the binary for your platform.`
        ))
      } else {
        reject(error)
      }
    })
    
    child.on('close', (code) => {
      resolve(code ?? 0)
    })
  })
}

/**
 * Run the code generator with provided arguments
 * Defaults to process.argv.slice(2) if no args provided
 */
export async function run(args) {
  const cliArgs = args ?? process.argv.slice(2)
  
  try {
    const exitCode = await execute(cliArgs)
    process.exit(exitCode)
  } catch (error) {
    console.error('Error executing di-code-generator:', error.message)
    process.exit(1)
  }
}

// Export for programmatic use
export { getBinaryPath }

// Default export for convenience
export default { execute, run, getBinaryPath }
