// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

document.addEventListener('turbo:load', () => {
  const menuToggle = document.querySelector('.menu-toggle');
  const navButtons = document.querySelector('.nav-buttons');

  if (menuToggle && navButtons) {
    menuToggle.addEventListener('click', () => {
      menuToggle.classList.toggle('active');
      navButtons.classList.toggle('active');
    });

    // Close menu when clicking outside
    document.addEventListener('click', (e) => {
      if (!menuToggle.contains(e.target) && !navButtons.contains(e.target)) {
        menuToggle.classList.remove('active');
        navButtons.classList.remove('active');
      }
    });
  }
}); 