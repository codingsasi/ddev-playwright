# ddev-playwright

[![tests](https://github.com/codingsasi/ddev-playwright/actions/workflows/tests.yml/badge.svg)](https://github.com/codingsasi/ddev-playwright/actions/workflows/tests.yml) ![project is maintained](https://img.shields.io/maintenance/yes/2026.svg) [![ddev-get registry](https://img.shields.io/badge/ddev--get-registry-blue)](https://ddev.readthedocs.io/en/stable/users/extend/additional-services/) ![release](https://img.shields.io/github/v/release/codingsasi/ddev-playwright?label=latest%20release)

This is a DDEV addon that provides a Playwright testing environment for your DDEV projects.

## Installation

1. **Add the addon** (you will be prompted for Playwright version):

   ```bash
   ddev add-on get codingsasi/ddev-playwright
   ```

2. **Restart** to build the web container with Playwright support:

   ```bash
   ddev restart
   ```

3. **Init Playwright and install browsers** (uses the version from your config):

   ```bash
   ddev install-playwright
   ```

4. **Run tests** — `ddev playwright` is the Playwright CLI:

   ```bash
   ddev playwright test
   ```

The addon depends on **ddev-nvm**; the Playwright project folder gets a default `.nvmrc` set to Node 22 (Node 20+ is required).

## How It Works

This addon installs Playwright system dependencies and the Playwright CLI into the DDEV web container, then mounts a Docker volume at `/opt/playwright-browsers` for the actual browser binaries. The first `ddev install-playwright` populates this volume; subsequent restarts (and other projects) reuse it.

- **Reinstall browsers only when needed:** `ddev reinstall-browsers`

### Shared browser cache across projects

The browser cache lives in a globally-named Docker volume — `ddev-playwright-browsers` — that is shared across **every** DDEV project using this addon. The full browser set is ~1.2 GB, so sharing means it lives on disk once instead of per project, and new projects skip the download entirely after the first install.

Each Playwright version gets its own subdirectory inside the volume (e.g. `/opt/playwright-browsers/1.49.0/`, `/opt/playwright-browsers/1.59.1/`), so projects pinned to different Playwright versions coexist safely. This isolation is required because `npx playwright install` cleans up browser folders it doesn't recognize, which would otherwise wipe other versions' binaries.

The volume is declared `external: true`, so removing the addon from one project (or `ddev delete -O`) does **not** wipe browsers other projects still depend on. To reclaim the disk space once no project needs it, run:

```bash
docker volume rm ddev-playwright-browsers
```

## Configuration

### Customizing the Test Directory

By default, Playwright tests are installed in the `tests/playwright` directory. You can customize this location by setting the `PLAYWRIGHT_TEST_DIR` environment variable in your `.ddev/config.yaml`:

```yaml
web_environment:
  - PLAYWRIGHT_TEST_DIR=test  # Use "test" instead of "tests"
```

After changing this setting, run:

```bash
ddev restart
```

**Note:** If you change this after initial installation, you'll need to manually move your existing Playwright directory to the new location.

### Pinning the Playwright Version

During `ddev add-on get` you will be prompted to enter a version:

```
Playwright version configuration
See releases: https://github.com/microsoft/playwright/releases

Enter Playwright version [latest]:
```

Press Enter to use the latest release, or type a specific version (e.g. `1.49.0`). The choice is written directly into your project's `.ddev/config.yaml` — commit this file so the whole team uses the same version.

To change the version later, run `ddev add-on get` again (you will be prompted only if the version is not yet set) or edit `PLAYWRIGHT_VERSION` in `.ddev/config.yaml` under `web_environment` and run `ddev restart`:

## Usage

`ddev playwright` is the Playwright CLI (pass any Playwright CLI args):

```bash
ddev playwright test
ddev playwright --help
ddev playwright codegen
ddev playwright show-report --host=0.0.0.0   # then open http://<project>.ddev.site:9323
```

**Commands:**

| Command | Description |
|---------|-------------|
| `ddev install-playwright` | Init Playwright project (if needed), install browsers, set up `.installed` to indicate browsers are installed |
| `ddev reinstall-browsers` | Reinstall browser binaries even if already installed |
| `ddev playwright ...` | Run the Playwright CLI (e.g. `test`, `codegen`, `show-report`) |

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
cd tests/playwright # Go into playwright folder (or "test/playwright" if you customized PLAYWRIGHT_TEST_DIR)
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

This is a very lightweight playwright ddev addon, if you want a more advanced playwright integration into ddev, use [Lullabot's playwright ddev addon](https://github.com/Lullabot/ddev-playwright) or [Julien Loizelet's ddev addon](https://github.com/julienloizelet/ddev-playwright). They have a VNC running inside ddev that is capable of --ui. Using my add-on, if you want the --ui to work, you'll have to run it outside of ddev which is quite easy. See the global-setup.ts and global-teardown.ts files. See more about UI mode here: https://playwright.dev/docs/test-ui-mode.

### Node.js Version Management

As of DDEV v1.25.0, nvm is no longer included by default. In most cases this will be required (Drupal themes, progressively decoupled apps, full decoupled apps etc). So for this add-on, I've added ddev-nvm as a dependency and it is required for this add-on.