import { type FullConfig } from '@playwright/test';
import {execSync} from "child_process";

async function globalTeardown(config: FullConfig) {
  const isDdev = process.env.IS_DDEV_PROJECT || false;

  if (process.env.CI) {
    console.log('Running in CI environment');
    // Clean up test users and data in CI environment.
    // Uses platform CLI to run drush commands in platform.sh. Use terminus in pantheon, etc,
    // or simple ssh like this: ssh -t user@domain.example 'cd /var/www/html && vendor/bin/drush status'
    execSync(`platform -edev drush status`, { stdio: 'inherit' });
  } else {
    if (isDdev !== false) {
      console.log('Running in ddev container');
      execSync('drush status', { stdio: 'inherit' });
    }
    else {
      console.log('Running from host, outside ddev container.');
      execSync('ddev drush status', { stdio: 'inherit' });
    }
  }
}

export default globalTeardown;
