const initializePasswordToggles = () => {
    document.querySelectorAll('.password-toggle').forEach((button) => {
        button.addEventListener('click', () => {
            const inputId = button.getAttribute('aria-controls');
            const input = inputId ? document.getElementById(inputId) : null;
            const showIcon = button.querySelector('[data-eye-show]');
            const hideIcon = button.querySelector('[data-eye-hide]');

            if (!(input instanceof HTMLInputElement) || !showIcon || !hideIcon) return;

            const visible = input.type === 'password';
            input.type = visible ? 'text' : 'password';
            button.setAttribute('aria-pressed', String(visible));
            button.setAttribute('aria-label', visible ? 'Ocultar contraseña' : 'Mostrar contraseña');
            showIcon.hidden = visible;
            hideIcon.hidden = !visible;
        });
    });
};

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializePasswordToggles, { once: true });
} else {
    initializePasswordToggles();
}
