(() => {
    'use strict';
    if (window.photoboothGuideLoaded) return;
    window.photoboothGuideLoaded = true;

    let dispose = () => {};
    const seenInMemory = new Set();
    const visible = (element) => element && element.getClientRects().length && getComputedStyle(element).visibility !== 'hidden';
    const findTarget = (selector) => selector ? [...document.querySelectorAll(selector)].find(visible) : null;

    function initialize() {
        dispose();
        const configElement = document.getElementById('photobooth-guide-config');
        const help = document.getElementById('photobooth-help');
        if (!configElement || !help) return;
        const config = JSON.parse(configElement.dataset.config);
        // Route key excludes record IDs: editing a second record does not restart the tour.
        const storageKey = `photobooth:guide:v1:${config.user}:${config.key}`;
        let dialog, card, spotlight, steps, index, previousFocus, frame, autoTimer;
        let previousScroll;

        function remember() {
            seenInMemory.add(storageKey);
            try { localStorage.setItem(storageKey, 'seen'); } catch (_) { /* Private mode: keep this visit usable. */ }
        }

        function close(markSeen = true) {
            if (!dialog) return;
            if (markSeen) remember();
            cancelAnimationFrame(frame);
            dialog.close();
            dialog.remove();
            dialog = null;
            window.removeEventListener('resize', schedulePosition);
            window.removeEventListener('scroll', schedulePosition, true);
            if (previousScroll) window.scrollTo({ ...previousScroll, behavior: 'instant' });
            if (previousFocus?.isConnected) previousFocus.focus({ preventScroll: true });
        }

        function position() {
            if (!dialog) return;
            const target = findTarget(steps[index].target);
            const width = window.innerWidth;
            const height = window.innerHeight;
            const margin = 16;
            const bounds = target?.getBoundingClientRect();
            spotlight.hidden = !bounds;
            let left = (width - card.offsetWidth) / 2;
            let top = (height - card.offsetHeight) / 2;
            if (bounds) {
                const x = Math.max(4, bounds.left - 5);
                const y = Math.max(4, bounds.top - 5);
                const right = Math.min(width - 4, bounds.right + 5);
                const bottom = Math.min(height - 4, bounds.bottom + 5);
                spotlight.hidden = right <= x || bottom <= y;
                Object.assign(spotlight.style, { left: `${x}px`, top: `${y}px`, width: `${Math.max(0, right - x)}px`, height: `${Math.max(0, bottom - y)}px` });
                left = bounds.left;
                if (bottom + card.offsetHeight + margin < height) top = bottom + 12;
                else if (y - card.offsetHeight - margin > 0) top = y - card.offsetHeight - 12;
                else if (right + card.offsetWidth + margin < width) { left = right + 12; top = y; }
                else { left = width - card.offsetWidth - margin; top = height - card.offsetHeight - margin; }
            }
            dialog.classList.toggle('pb-guide-no-target', spotlight.hidden);
            card.style.left = `${Math.max(margin, Math.min(left, width - card.offsetWidth - margin))}px`;
            card.style.top = `${Math.max(margin, Math.min(top, height - card.offsetHeight - margin))}px`;
        }

        function schedulePosition() {
            cancelAnimationFrame(frame);
            frame = requestAnimationFrame(position);
        }

        function showStep() {
            const step = steps[index];
            card.querySelector('[data-progress]').textContent = `TUTORIAL HALAMAN • ${index + 1} / ${steps.length}`;
            card.querySelector('h2').textContent = step.title;
            card.querySelector('[data-body]').textContent = step.body;
            card.querySelector('[data-prev]').disabled = index === 0;
            card.querySelector('[data-next]').textContent = index === steps.length - 1 ? 'Selesai' : 'Selanjutnya →';
            const target = findTarget(step.target);
            if (target) {
                const bounds = target.getBoundingClientRect();
                const spaceNeeded = card.offsetHeight + 28;
                const cardOverlaps = bounds.top < spaceNeeded && window.innerHeight - bounds.bottom < spaceNeeded;
                if (cardOverlaps && bounds.height + spaceNeeded + 24 < window.innerHeight) {
                    target.scrollIntoView({ behavior: 'instant', block: 'start' });
                    window.scrollBy({ top: -16, behavior: 'instant' });
                } else if (bounds.top < 0 || bounds.bottom > window.innerHeight) {
                    target.scrollIntoView({ behavior: 'instant', block: bounds.height > window.innerHeight / 2 ? 'start' : 'center' });
                }
            }
            position();
            // Focus the heading to announce each step, including when moving backwards.
            card.querySelector('h2').focus({ preventScroll: true });
        }

        function start() {
            clearTimeout(autoTimer);
            if (dialog) return;
            previousFocus = document.activeElement;
            previousScroll = { left: window.scrollX, top: window.scrollY };
            const optionalTargets = ['.fi-ta-search-field', '.fi-ta-filters-trigger-action-ctn', '.fi-header-actions-ctn'];
            steps = config.steps.filter(step => !optionalTargets.includes(step.target) || findTarget(step.target));
            if (!steps.length) return;
            index = 0;
            dialog = document.createElement('dialog');
            dialog.className = 'pb-guide-dialog';
            dialog.setAttribute('aria-labelledby', 'pb-guide-title');
            dialog.setAttribute('aria-describedby', 'pb-guide-body');
            dialog.innerHTML = `<div class="pb-guide-spotlight" aria-hidden="true"></div>
                <section class="pb-guide-card">
                    <div class="pb-guide-top"><span data-progress></span><button type="button" data-skip>Lewati</button></div>
                    <h2 id="pb-guide-title" tabindex="-1"></h2><p id="pb-guide-body" data-body></p>
                    <a class="pb-guide-docs">Buka dokumentasi lengkap ↗</a>
                    <div class="pb-guide-actions"><button type="button" data-prev>← Sebelumnya</button><button type="button" data-next>Selanjutnya →</button></div>
                </section>`;
            card = dialog.querySelector('.pb-guide-card');
            spotlight = dialog.querySelector('.pb-guide-spotlight');
            card.querySelector('a').href = config.docs;
            card.querySelector('a').addEventListener('click', () => close());
            card.querySelector('[data-skip]').addEventListener('click', () => close());
            card.querySelector('[data-prev]').addEventListener('click', () => { if (index > 0) { index--; showStep(); } });
            card.querySelector('[data-next]').addEventListener('click', () => {
                if (index === steps.length - 1) close();
                else { index++; showStep(); }
            });
            dialog.addEventListener('cancel', event => { event.preventDefault(); close(); });
            document.body.append(dialog);
            dialog.showModal();
            showStep();
            window.addEventListener('resize', schedulePosition);
            window.addEventListener('scroll', schedulePosition, true);
        }

        help.addEventListener('click', start);
        let seen = seenInMemory.has(storageKey);
        try { seen ||= localStorage.getItem(storageKey) === 'seen'; } catch (_) { /* Storage may be unavailable. */ }
        if (!seen) autoTimer = setTimeout(start, 450);
        dispose = () => { clearTimeout(autoTimer); close(false); help.removeEventListener('click', start); };
    }

    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', initialize, { once: true });
    else initialize();
    document.addEventListener('livewire:navigating', () => dispose());
    document.addEventListener('livewire:navigated', initialize);
})();
