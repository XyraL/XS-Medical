(() => {
    const root = document.getElementById('xsm-menu');
    let open = false;
    let spec = null;
    const qty = {};

    function render() {
        const stage = XS.stage(root);
        const items = XS.list(spec.items);
        stage.innerHTML = `
            <div class="mu-box">
                <div class="mu-head"><b>${XS.esc(spec.title || '')}</b>${spec.subtitle ? `<span>${XS.esc(spec.subtitle)}</span>` : ''}</div>
                ${spec.note ? `<div class="mu-note">${XS.esc(spec.note)}</div>` : ''}
                <div class="mu-list xsm-scroll">${items.length ? items.map((it, i) => `
                    <div class="mu-row" data-i="${i}">
                        <b>${XS.esc(it.label)}</b>
                        ${it.qty ? `<div class="mu-qty" data-q="${i}"><button data-d="-1">−</button><em>${qty[i] || 1}</em><button data-d="1">+</button></div>` : ''}
                        ${it.right ? `<span>${XS.esc(it.right)}</span>` : ''}
                    </div>`).join('') : `<div class="xsm-empty">${XS.esc(XS.t('menu_empty', null, 'Nothing here'))}</div>`}</div>
                <div class="mu-foot"><span>${XS.esc(XS.t('menu_hint', null, 'Click to choose'))}</span><span>${XS.esc(XS.t('hint_esc', null, 'ESC to close'))}</span></div>
            </div>`;
        stage.querySelectorAll('.mu-qty button').forEach((b) => {
            b.addEventListener('click', (e) => {
                e.stopPropagation();
                const i = Number(b.parentElement.dataset.q);
                qty[i] = Math.max(1, Math.min(20, (qty[i] || 1) + Number(b.dataset.d)));
                b.parentElement.querySelector('em').textContent = qty[i];
            });
        });
        stage.querySelectorAll('.mu-row').forEach((row) => {
            row.addEventListener('click', async () => {
                const i = Number(row.dataset.i);
                const item = items[i];
                const res = await XS.rpc('menu:pick', { id: item.id, qty: qty[i] || 1, keep: !!item.qty });
                if (!res.ok && res.error) XS.toast(res.error, 'error');
            });
        });
    }

    XS.apps.menu = {
        isOpen: () => open,
        escape: () => XS.close('menu'),
        on(action, data) {
            if (action === 'open') {
                spec = data;
                Object.keys(qty).forEach((k) => delete qty[k]);
                open = true;
                XS.show('xsm-menu', true);
                render();
            } else if (action === 'close') {
                open = false;
                XS.show('xsm-menu', false);
                root.innerHTML = '';
            }
        },
    };
})();
