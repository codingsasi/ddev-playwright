import { test, expect } from '@playwright/test';

// Example test that visits the homepage of the DDEV site
test('homepage has correct title', async ({ page }) => {
  // Navigate to the homepage
  await page.goto('/');

  // You can use an explicit URL if needed
  // await page.goto('http://web');
  // Or use the DDEV_PRIMARY_URL environment variable
  // await page.goto(process.env.DDEV_PRIMARY_URL || 'http://web');

  // Check that the page has loaded
  await expect(page).toHaveTitle(/Home|Welcome|Index/);

  // Example of taking a screenshot
  await page.screenshot({ path: 'homepage.png' });
});

// Example of testing a form
test('can fill out a simple form', async ({ page }) => {
  // Go to the form page (adjust path as needed)
  await page.goto('/contact');

  // Fill out form fields
  await page.getByLabel('Name').fill('Test User');
  await page.getByLabel('Email').fill('test@example.com');
  await page.getByLabel('Message').fill('This is a test message');

  // Submit the form
  await page.getByRole('button', { name: 'Submit' }).click();

  // Check that submission was successful
  await expect(page.getByText('Thank you')).toBeVisible();
});

// Notes:
// - Replace paths, selectors, and expectations with your actual site structure
// - The DDEV site is accessible via the hostname 'web' or via DDEV_PRIMARY_URL
// - Run tests with: ddev playwright test