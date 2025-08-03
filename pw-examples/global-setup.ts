import { type FullConfig } from '@playwright/test';
import {execSync} from "child_process";

async function globalSetup(config: FullConfig) {
  const isDdev = process.env.IS_DDEV_PROJECT || false;

  if (process.env.CI) {
    console.log('Running in CI environment');
    // This is an example of how to run a drush command in the CI environment.
    // You can replace the drush command with any command you need to run.
    // We use platform cli to run commands in platform.sh. Use terminus in pantheon, etc,
    // or simple ssh like this: ssh -t user@domain.example 'cd /var/www/html && vendor/bin/drush status'
    try {
      execSync(`platform -edev drush status`, { stdio: 'inherit' });
    } catch (error) {
      console.log('Platform CLI or drush not available in CI');
    }
  } else {
    if (isDdev !== false) {
      console.log('Running in ddev container');
      try {
        execSync('drush status', { stdio: 'inherit' });
      } catch (error) {
        console.log('drush not available');
      }
    }
    else {
      console.log('Running from host, outside ddev container.');
      try {
        execSync('ddev drush status', { stdio: 'inherit' });
      } catch (error) {
        console.log('ddev drush not available');
      }
    }
  }
}

export default globalSetup;
