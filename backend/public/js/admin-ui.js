const initializeAdminModals = () => {
    const confirmationDialog = document.getElementById('admin-confirm-dialog');
    let pendingForm = null;

    document.addEventListener('click', (event) => {
        if (!(event.target instanceof Element)) return;

        const openButton = event.target.closest('[data-modal-open]');
        if (openButton) {
            const dialogId = openButton.getAttribute('data-modal-open');
            const dialog = dialogId ? document.getElementById(dialogId) : null;
            if (!(dialog instanceof HTMLDialogElement)) return;

            const currentDialog = document.querySelector('dialog[open]');
            if (currentDialog && currentDialog !== dialog) currentDialog.close();
            if (!dialog.open) dialog.showModal();
            initializeProductImagePreviews(dialog);
            return;
        }

        const closeButton = event.target.closest('[data-modal-close]');
        if (closeButton) {
            closeButton.closest('dialog')?.close();
            return;
        }

        if (event.target.closest('[data-confirm-accept]') && pendingForm) {
            const form = pendingForm;
            pendingForm = null;
            form.dataset.confirmed = 'true';
            confirmationDialog?.close();
            form.requestSubmit();
            return;
        }

        if (event.target.closest('[data-print-receipt]')) {
            window.print();
        }
    });

    document.addEventListener('submit', (event) => {
        const form = event.target;
        if (!(form instanceof HTMLFormElement) || !form.hasAttribute('data-confirm')) return;
        if (form.dataset.confirmed === 'true') {
            delete form.dataset.confirmed;
            return;
        }
        event.preventDefault();
        const message = form.getAttribute('data-confirm-message');
        if (!(confirmationDialog instanceof HTMLDialogElement)) {
            if (window.confirm(message || '¿Confirmas esta acción?')) form.requestSubmit();
            return;
        }
        confirmationDialog.querySelector('[data-confirm-message]').textContent = message || 'Confirma para continuar.';
        pendingForm = form;
        confirmationDialog.showModal();
    });

    document.querySelectorAll('dialog.admin-modal').forEach((dialog) => {
        dialog.addEventListener('click', (event) => {
            if (event.target === dialog) dialog.close();
        });
    });

    document.querySelectorAll('dialog[data-open-on-errors="true"]').forEach((dialog) => {
        if (dialog instanceof HTMLDialogElement && !dialog.open) {
            dialog.showModal();
            initializeProductImagePreviews(dialog);
        }
    });
};

const normalizeProductImageUrl = (value) => {
    const source = String(value || '').trim();
    if (!source) return null;

    try {
        const url = /^https?:\/\//i.test(source)
            ? new URL(source)
            : new URL(`/${source.replace(/^\/+/, '')}`, window.location.origin);

        return ['http:', 'https:'].includes(url.protocol) ? url.href : null;
    } catch {
        return null;
    }
};

const updateProductImagePreview = (container, source) => {
    const image = container.querySelector('[data-image-preview]');
    const placeholder = container.querySelector('[data-image-preview-placeholder]');
    if (!(image instanceof HTMLImageElement) || !(placeholder instanceof HTMLElement)) return;

    const url = normalizeProductImageUrl(source);
    image.hidden = true;

    if (!url) {
        placeholder.hidden = false;
        placeholder.textContent = source.trim()
            ? 'La URL o ruta de imagen no es válida.'
            : 'Agrega una URL para ver la imagen.';
        image.removeAttribute('src');
        return;
    }

    placeholder.hidden = true;
    image.onload = () => {
        image.hidden = false;
        placeholder.hidden = true;
    };
    image.onerror = () => {
        image.hidden = true;
        placeholder.hidden = false;
        placeholder.textContent = 'No se pudo cargar. Verifica la URL o que el archivo exista en public.';
    };
    image.src = url;
};

const initializeProductImagePreviews = (root) => {
    root.querySelectorAll('[data-product-image-preview]').forEach((container) => {
        if (container.dataset.previewInitialized === 'true') return;

        const form = container.closest('form');
        const input = form?.querySelector('[data-product-image-input]');
        const source = input instanceof HTMLInputElement
            ? input.value
            : container.getAttribute('data-image-url') || '';

        container.dataset.previewInitialized = 'true';
        if (input instanceof HTMLInputElement) {
            input.addEventListener('input', () => updateProductImagePreview(container, input.value));
        }

        updateProductImagePreview(container, source);
    });
};

const initializeAdminPasswordToggles = () => {
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

const initializeScrollReveals = () => {
    if (window.matchMedia('(prefers-reduced-motion: reduce)').matches || !('IntersectionObserver' in window)) {
        return;
    }

    const elements = document.querySelectorAll('.panel, .stat-card, .parameter-card');
    if (elements.length === 0) return;

    const observer = new IntersectionObserver((entries, currentObserver) => {
        entries.forEach((entry) => {
            if (!entry.isIntersecting) return;
            entry.target.classList.add('is-visible');
            currentObserver.unobserve(entry.target);
        });
    }, { threshold: 0.05 });

    elements.forEach((element, index) => {
        element.classList.add('scroll-reveal', `scroll-reveal--delay-${Math.min(index % 4, 3)}`);
        observer.observe(element);
    });
};

const initializeAdminUi = () => {
    initializeAdminModals();
    initializeAdminPasswordToggles();
    initializeScrollReveals();
};

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initializeAdminUi, { once: true });
} else {
    initializeAdminUi();
}
