# DI Code Generator

A minimal, focused code generator written in Zig for creating TypeScript/JavaScript dependency injection boilerplate.

## Overview

This project provides primitives for string interpolation and name manipulation - the foundational building blocks needed to generate DI registration files and related boilerplate code.

## Features

### String Interpolation
- Parse template strings with `{param}` placeholders
- Apply parameter values to generate final strings
- Concatenate strings with customizable separators

### Name Utilities
- **Case Conversions**: Convert between different naming conventions
  - `camelCase`
  - `PascalCase`
  - `snake_case`
  - `kebab-case`
  - `SCREAMING_SNAKE_CASE`
- **Name Parameterization**: Apply names to templates with automatic case conversion
- **Name Concatenation**: Join multiple name parts with patterns

## Building

```bash
# Build the project
zig build

# Run the example
zig build run

# Run all tests
zig build test
```

## Testing

Tests are organized by concern:
- **interpolation tests**: String template parsing and parameter application
- **name_utils tests**: Case conversion and name manipulation
- **module tests**: Integration tests

```bash
zig build test
```

## Usage Example

```zig
const std = @import("std");
const di_gen = @import("di-code-generator");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Template interpolation with case conversion
    const result = try di_gen.name_utils.parameterizeName(
        allocator,
        "register{Name}",
        "user_service",
        .PascalCase,
    );
    defer allocator.free(result);
    // Result: "registerUserService"

    // Case conversions
    const snake = try di_gen.name_utils.toSnakeCase(allocator, "HelloWorld");
    defer allocator.free(snake);
    // Result: "hello_world"
}
```

## Project Structure

```
zig/di-code-generator/
├── build.zig              # Build configuration
├── build.zig.zon          # Package metadata
├── src/
│   ├── root.zig           # Module exports
│   ├── main.zig           # CLI executable
│   ├── interpolation.zig  # String interpolation primitives
│   └── name_utils.zig     # Name manipulation utilities
└── README.md
```

## API Reference

### Interpolation Module (`interpolation.zig`)

#### `InterpolationPart`
Union type representing either literal text or a parameter placeholder.

#### `parseTemplate(allocator, template) ![]InterpolationPart`
Parse a template string into parts. Template format: `"Hello {name}!"`

#### `applyParams(allocator, parts, params) ![]u8`
Apply parameter values to interpolation parts.

#### `concat(allocator, separator, strings) ![]u8`
Concatenate multiple strings with a separator.

### Name Utils Module (`name_utils.zig`)

#### Case Conversion Functions
- `toCamelCase(allocator, input) ![]u8`
- `toPascalCase(allocator, input) ![]u8`
- `toSnakeCase(allocator, input) ![]u8`
- `toKebabCase(allocator, input) ![]u8`

#### `parameterizeName(allocator, pattern, name, case) ![]u8`
Apply a name to a pattern with automatic case conversion.
- `pattern`: Template string like `"register{Name}"`
- `name`: The name to insert
- `case`: Target naming convention

## Design Decisions

### Minimal Scope
This implementation focuses solely on the **primitives** needed for code generation:
1. **String interpolation** - Building strings from templates
2. **Name manipulation** - Converting and parameterizing names

These are the most fundamental operations required to generate any boilerplate code. Higher-level features (file generation, directory structure, etc.) can be built on top of these primitives.

### No Dependencies
The project uses only Zig's standard library, making it lightweight and easy to integrate.

### Test Organization
Tests are separated by concern into different executables, allowing focused testing and faster iteration during development.

## License

See repository root for license information.

## Related

This generator is designed to work with [@computerwwizards/dependency-injection](https://www.npmjs.com/package/@computerwwwizards/dependency-injection) - a reflection-free IoC container for JavaScript/TypeScript.

## NPM Package Usage

This tool is also available as an npm package: `@computerwwwizards/di-code-generator`

### Installation

```bash
npm install @computerwwwizards/di-code-generator
# or
pnpm add @computerwwwizards/di-code-generator
```

### CLI Usage

```bash
# Auto-discover config.json in current directory
npx di-code-gen

# Specify config file
npx di-code-gen --config ./services.config.json

# Override output directory  
npx di-code-gen --config ./config.json --output ./src/di
```

### Quick CLI Generation (Auto-inferred Interface)

Generate a service directly via CLI without a config file. The interface name is automatically inferred from the service name (e.g., `userService` → `IUserService`):

```bash
# Single service
npx di-code-gen --service userService --output ./src/di

# Multiple services
npx di-code-gen --service userService --service paymentGateway --output ./src/di

# Custom interface name (optional; defaults to I + PascalCase of service name)
npx di-code-gen --service userService:IUserAuthService --output ./src/di

# Combination: CLI services override config
npx di-code-gen --config config.json --service customService --output ./src/di
```

**Auto-inference examples:**
- `userService` → `IUserService`
- `paymentGateway` → `IPaymentGateway`
- `auth_service` → `IAuthService`
- `DBConnection` → `IDbconnection`

When `--service` is provided, CLI services take precedence over config file services.

### Concrete Example (UserService)

1) Create a config file `di.config.json`:

```json
{
  "output": "./src/di",
  "services": [
    { "name": "userService", "interface": "IUserService" }
  ]
}
```

2) Run the generator:

```bash
npx di-code-gen --config ./di.config.json
```

3) Generated structure:

```
src/di/
  userService/
    types.ts
    registerUserService.ts
```

4) `types.ts` (empty ServicesList with augmentation elsewhere):

```ts
import { PreProcessDependencyContainerWithUse } from '@computerwwwizards/dependency-injection'

export interface ServicesList {}
export type ContainerCtx = PreProcessDependencyContainerWithUse<ServicesList>
```

5) `registerUserService.ts` includes `IUserService`, default `register()` stub, a `mock()` helper, and augments `ServicesList`:

```ts
export interface IUserService {}

export default function register(ctx: ContainerCtx) {
  // TODO: register real implementation
}

export function mock(ctx: ContainerCtx) {
  // TODO: register mock for tests
}

declare module './types' {
  interface ServicesList {
    userService: IUserService
  }
}

register.mock = mock
```

### Programmatic API

**ESM:**
```javascript
import { execute } from '@computerwwwizards/di-code-generator'

const exitCode = await execute([
  '--config', './my-config.json',
  '--output', './src/generated'
])
```

**CommonJS:**
```javascript
const { execute } = require('@computerwwwizards/di-code-generator')

const exitCode = await execute(['--config', './config.json'])
```

### Platform Support

Includes pre-compiled binaries for Linux, macOS, and Windows (x64, arm64).
