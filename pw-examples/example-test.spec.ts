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

// Notes:
// - Replace paths, selectors, and expectations with your actual site structure
// - The DDEV site is accessible via the hostname 'web' or via DDEV_PRIMARY_URL
// - Run tests with: ddev playwright test