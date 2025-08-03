# ddev-playwright

[![tests](https://github.com/codingsasi/ddev-playwright/actions/workflows/tests.yml/badge.svg)](https://github.com/codingsasi/ddev-playwright/actions/workflows/tests.yml) ![project is maintained](https://img.shields.io/maintenance/yes/2025.svg) [![ddev-get registry](https://img.shields.io/badge/ddev--get-registry-blue)](https://ddev.readthedocs.io/en/stable/users/extend/additional-services/) ![release](https://img.shields.io/github/v/release/codingsasi/ddev-playwright?label=latest%20release)

This is a DDEV addon that provides a Playwright testing environment for your DDEV projects.

## Installation

```bash
ddev add-on get codingsasi/ddev-playwright
ddev restart
```

## Configuration

After installation, you'll need to set up Playwright in your project if you haven't already:

```bash
# Install Playwright dependencies and browsers in your project.
ddev playwright install-deps
ddev playwright install

```

## Usage

You can run Playwright commands directly using the `ddev playwright` command:

```bash
# Run Playwright tests
ddev playwright test

# Show Playwright help
ddev playwright --help
```

## Accessing the Web Application from Tests

Your tests can access the web application using the hostname `web` or the DDEV_PRIMARY_URL environment variable:

```javascript
// Example test
import { test, expect } from '@playwright/test';

test('basic test', async ({ page }) => {
  // Using the DDEV_PRIMARY_URL environment variable
  await page.goto(process.env.DDEV_PRIMARY_URL || 'http://web');

  // Rest of your test...
});
```

## Global Setup and Teardown

I've included config to have playwright's global setup and teardown hooks. This allows you to run code once before all tests begin and once after all tests complete. This is useful for:

- **Global Setup**: Database seeding, user creation, service initialization, cache warming
- **Global Teardown**: Cleanup operations, test data removal, service shutdown

These hooks run independently of individual test files and are executed in a separate Node.js process.

### Configuration Files

#### `global-setup.ts`
Runs **before** all tests execute. The included setup file demonstrates:
- Environment detection (CI vs DDEV vs host)
- Running drush commands in different environments

#### `global-teardown.ts`
Runs **after** all tests complete. The included teardown file demonstrates:
- Running cleanup commands based on environment

### Environment Detection

Both files automatically detect the execution environment:

- **CI Environment** (`process.env.CI`): Uses platform CLI commands for cloud hosting
- **DDEV Container** (`process.env.IS_DDEV_PROJECT`): Runs drush commands directly
- **Host Machine**: Prefixes commands with `ddev` to execute in the container

### Customization

Edit these files to match your project's needs:

```typescript
// Example: Custom setup for your application
execSync('drush user:create testuser --password=testpass', { stdio: 'inherit' });
execSync('drush config:set system.site page.front /custom-page', { stdio: 'inherit' });
```

The global hooks are automatically configured in `playwright.config.ts` and will run whenever you execute `ddev playwright test`.

## Customizing

You can customize the Playwright configuration by editing the `playwright.config.ts` file in your project. TypeScript is enforced by initializing playwright with ts when add-on is installed because it brings order to lawless world of JavaScript.

## Contributing

Feel free to submit issues or pull requests with improvements.

**Contributed and maintained by [Abhai Sasidharan/codingsasi]**

## Notes

This is a very lightweight playwright ddev addon, if you want a more advanced playwright integration into ddev, use "https://github.com/Lullabot/ddev-playwright" or "https://github.com/julienloizelet/ddev-playwright". They have a VNC running inside ddev that is capable of --ui. Using my add-on, if you want the --ui to work, you'll have to run it outside of ddev which is quite easy. See the global-setup.ts and global-teardown.ts files. See more about UI mode here: https://playwright.dev/docs/test-ui-mode.