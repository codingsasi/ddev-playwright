#ddev-generated
import { test, expect } from '@playwright/test';

// Example test that checks the homepage returns 200 status
test('homepage returns 200 status', async ({ page }) => {
  // Navigate to the homepage and check response status
  const response = await page.goto('/');

  // Verify the page loaded successfully
  expect(response?.status()).toBe(200);

  // Check that the page has the expected content
  await expect(page.getByRole('heading', { name: 'The way is clear!' })).toBeVisible();

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