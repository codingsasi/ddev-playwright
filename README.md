# ddev-playwright

[![tests](https://github.com/codingsasi/ddev-playwright/actions/workflows/tests.yml/badge.svg)](https://github.com/codingsasi/ddev-playwright/actions/workflows/tests.yml) ![project is maintained](https://img.shields.io/maintenance/yes/2025.svg) [![ddev-get registry](https://img.shields.io/badge/ddev--get-registry-blue)](https://ddev.readthedocs.io/en/stable/users/extend/additional-services/) ![release](https://img.shields.io/github/v/release/codingsasi/ddev-playwright?label=latest%20release)

This is a DDEV addon that provides a Playwright testing environment for your DDEV projects.

## Installation

```bash
ddev add-on get codingsasi/ddev-playwright
ddev restart  # This will build Playwright browsers into the Docker image
```

## How It Works

This addon builds Playwright browsers directly into the DDEV web container Docker image. This means:
- **Browsers persist across DDEV restarts** - No need to reinstall after `ddev restart`
- **Faster startup times** - Browsers are pre-installed in the image
- **No runtime downloads** - Everything is ready to use immediately
- **Consistent environment** - All team members get the same browser versions

The first `ddev restart` after installation will take longer (5-10 minutes) as it builds the browsers into the Docker image. Subsequent restarts will be fast.

## Configuration

After installation, browsers are already installed. You can verify the installation:

```bash
# Verify Playwright and browser installation (optional)
ddev install-playwright

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

Your tests can access the DDEV_PRIMARY_URL environment variable:

```javascript
// Example test
import { test, expect } from '@playwright/test';

test('basic test', async ({ page }) => {
  // Using the DDEV_PRIMARY_URL environment variable
  await page.goto(process.env.DDEV_PRIMARY_URL || 'https://your.ddev.site');

  // Rest of your test...
});
```

### Running in --ui mode (outside ddev container)
```bash
# From project root
cd tests/Playwright # Go into playwright folder
nvm use 22
npm ci
npx playwright install # Works best on Windows, Mac and Ubuntu (and possibly other Debian based distros). I had trouble with Fedora/Manjaro but not impossible.
npx playwright test --ui
```

This will open up the playwright UI which you can use to run tests manually. See screenshot below.

![Playwright UI Screenshot](assets/playwright-ui-screenshot.png)

You should also update [`playwright.config.ts`](pw-examples/playwright.config.ts#L6) with your ddev base url: `const baseURL = process.env.DDEV_PRIMARY_URL || 'https://your.ddev.site';`

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