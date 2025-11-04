import { test, expect } from '@playwright/test';

const USERNAME = process.env.TEST_USERNAME || 'emma.lopez@gmail.com';
const PASSWORD = process.env.TEST_PASSWORD || 'Password.123';
const TIMEOUT = 10000;

test.describe('Shopping Site Core Functionality', () => {
  test.beforeEach(async ({ page }) => {
    await page.context().clearCookies();
  });

  test('should load homepage', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/One Stop Market/);
    // Check for Sign In link in navigation
    await expect(page.getByRole('link', { name: 'Sign In' })).toBeVisible({ timeout: TIMEOUT });
    // Check for product showcases
    await expect(page.locator('text="Product Showcases"')).toBeVisible();
  });

  test('should login successfully', async ({ page }) => {
    await page.goto('/customer/account/login/');
    
    // Fill in login form using the correct selectors from Magento
    await page.getByRole('textbox', { name: 'Email*' }).fill(USERNAME);
    await page.getByRole('textbox', { name: 'Password*' }).fill(PASSWORD);
    
    // Click Sign In button
    await page.getByRole('button', { name: 'Sign In' }).click();
    
    // Wait for navigation to complete
    await page.waitForURL('**/customer/account/**', { timeout: TIMEOUT });
    
    // Check we're logged in - should see welcome message
    await expect(page.locator(`text="Welcome, Emma Lopez!"`)).toBeVisible({ timeout: TIMEOUT });
  });

  test('should browse products', async ({ page }) => {
    await page.goto('/');
    
    // Check for product links on homepage
    const productLinks = await page.locator('.product-item a[href*=".html"]').count();
    expect(productLinks).toBeGreaterThan(0);
    
    // Click on first product
    await page.locator('.product-item a[href*=".html"]').first().click();
    await page.waitForLoadState('networkidle');
    
    // Check we're on a product page - should have Add to Cart button
    await expect(page.getByRole('button', { name: 'Add to Cart' })).toBeVisible({ timeout: TIMEOUT });
  });

  test('should access shopping cart', async ({ page }) => {
    await loginUser(page);
    
    // Click on cart link
    const cartLink = page.getByRole('link', { name: /My Cart/ });
    await expect(cartLink).toBeVisible({ timeout: TIMEOUT });
    await cartLink.click();
    
    // Cart dropdown should appear or navigate to cart page
    const cartDropdown = page.locator('text="Items in Cart"');
    const cartPage = page.locator('h1:has-text("Shopping Cart")');
    
    // Either cart dropdown or cart page should be visible
    const dropdownVisible = await cartDropdown.isVisible().catch(() => false);
    const pageVisible = await cartPage.isVisible().catch(() => false);
    
    expect(dropdownVisible || pageVisible).toBeTruthy();
  });

  test('should search for products', async ({ page }) => {
    await page.goto('/');
    
    // Find and use search box
    const searchBox = page.getByRole('combobox', { name: 'Search' });
    await expect(searchBox).toBeVisible({ timeout: TIMEOUT });
    
    await searchBox.fill('shirt');
    await searchBox.press('Enter');
    
    // Wait for search results page
    await page.waitForURL('**/catalogsearch/result/**');
    
    // Check for search results heading
    await expect(page.locator('h1:has-text("Search results for")')).toBeVisible();
    
    // Check if we have results or "no results" message
    const noResults = await page.locator('text="Your search returned no results"').isVisible().catch(() => false);
    const hasProducts = await page.locator('.product-item').count() > 0;
    
    // Either should have products or show no results message
    expect(hasProducts || noResults).toBeTruthy();
  });

  test('should navigate categories', async ({ page }) => {
    await page.goto('/');
    
    // Check category navigation exists
    const categories = ['Electronics', 'Grocery & Gourmet Food', 'Home & Kitchen'];
    
    for (const category of categories) {
      const categoryLink = page.getByRole('link', { name: category });
      await expect(categoryLink).toBeVisible({ timeout: TIMEOUT });
    }
    
    // Click on a category
    await page.getByRole('link', { name: 'Electronics' }).click();
    await page.waitForLoadState('networkidle');
    
    // Should be on category page
    await expect(page.url()).toContain('electronics');
  });
});

async function loginUser(page) {
  await page.goto('/customer/account/login/');
  await page.getByRole('textbox', { name: 'Email*' }).fill(USERNAME);
  await page.getByRole('textbox', { name: 'Password*' }).fill(PASSWORD);
  await page.getByRole('button', { name: 'Sign In' }).click();
  await page.waitForURL('**/customer/account/**', { timeout: TIMEOUT });
}