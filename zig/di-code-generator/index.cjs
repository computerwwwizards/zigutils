const { fileURLToPath } = require('node:url')
const { dirname, join } = require('node:path')
const { spawn } = require('node:child_process')
const { platform, arch } = require('node:os')

/**
 * Get the binary path based on platform and architecture
 */
function getBinaryPath() {
  const plat = platform()
  const architecture = arch()
  
  // Map Node.js arch to common names
  const archMap = {
    'x64': 'x86_64',
    'arm64': 'aarch64',
    'arm': 'arm'
  }
  
  const zigArch = archMap[architecture] || architecture
  
  // Binary name varies by platform
  const binaryName = plat === 'win32' ? 'di-code-generator.exe' : 'di-code-generator'
  
  // Path to the compiled binary
  return join(__dirname, 'zig-out', 'bin', binaryName)
}

/**
 * Execute the DI code generator binary
 * @param {string[]} args - CLI arguments to pass to the binary
 * @returns {Promise<number>} - Exit code of the process
 */
function execute(args = []) {
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
async function run(args) {
  const cliArgs = args ?? process.argv.slice(2)
  
  try {
    const exitCode = await execute(cliArgs)
    process.exit(exitCode)
  } catch (error) {
    console.error('Error executing di-code-generator:', error.message)
    process.exit(1)
  }
}

// Exports
module.exports = {
  execute,
  run,
  getBinaryPath
}

module.exports.default = module.exports
