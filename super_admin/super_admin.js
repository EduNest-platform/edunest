// Super Admin Dashboard JS

document.addEventListener('DOMContentLoaded', () => {
  if (!window.supabaseClient) {
    alert('Database connection error. Please refresh or contact support.');
  }
  // Placeholder: Add dashboard logic here if needed
  // Example: Show welcome message
  const container = document.querySelector('.container');
  if (container) {
    const welcome = document.createElement('div');
    welcome.style.marginTop = '18px';
    welcome.style.fontSize = '1.08em';
    welcome.style.color = '#667eea';
    welcome.textContent = 'Welcome, Super Admin!';
    container.appendChild(welcome);
  }
}); 