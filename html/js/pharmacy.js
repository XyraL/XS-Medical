(() => {
    const root = document.getElementById('xsm-pharmacy');
    let open = false;
    let data = null;
    let busy = false;

    function render() {
        const stage = XS.stage(root);
        const rx = XS.list(data.prescriptions);
        const counter = XS.list(data.counter);
        const money = data.money || {};
        stage.innerHTML = `
            <div class="ph-box">
                <div class="ph-head"><b>${XS.esc(XS.t('ph_title', null, 'Pharmacy'))}</b><span>${XS.esc(data.store || '')} · ${XS.esc(XS.t('ph_lookup', null, 'RX lookup'))}</span>
                    <span class="ph-money">${XS.esc(XS.t('ph_money', { cash: money.cash || 0, bank: money.bank || 0 }, `Cash $${money.cash || 0} · Bank $${money.bank || 0}`))}</span></div>
                <div class="ph-who">
                    <div><small>${XS.esc(XS.t('ph_patient', null, 'Patient'))}</small><b>${XS.esc(data.patient || '')}</b></div>
                    <div><small>${XS.esc(XS.t('ph_dob', null, 'Date of birth'))}</small><b>${XS.esc(data.dob || '—')}</b></div>
                    <div><small>${XS.esc(XS.t('ph_blood', null, 'Blood'))}</small><b>${XS.esc(data.blood || '—')}</b></div>
                    <div class="ph-allergy"><small>${XS.esc(XS.t('ph_allergies', null, 'Allergies'))}</small><b>${XS.esc(data.allergies || XS.t('ph_none', null, 'None on file'))}</b></div>
                </div>
                <div class="ph-body">
                    <div class="ph-col xsm-scroll"><h4>${XS.esc(XS.t('ph_rx', null, 'Prescriptions on file'))}</h4>
                        ${rx.length ? rx.map((r) => `
                            <div class="rx-row">
                                <div><b>${XS.esc(r.label)} · ${XS.esc(r.dose || '')}</b><span>${XS.esc(XS.t('ph_rx_line', { qty: r.qty, refills: r.refills, by: r.prescriber || '' }, `${r.qty} per fill · ${r.refills} refills left · ${r.prescriber || ''}`))}</span></div>
                                <span class="rx-price">$${XS.esc(r.price || 0)}</span>
                                <button class="xsm-key k-go" data-fill="${r.id}">${XS.esc(XS.t('ph_fill', null, 'Fill'))}</button>
                            </div>`).join('') : `<div class="xsm-empty">${XS.esc(XS.t('ph_no_rx', null, 'No prescriptions waiting. A doctor has to write one first.'))}</div>`}
                    </div>
                    <div class="ph-col xsm-scroll"><h4>${XS.esc(XS.t('ph_counter', null, 'Over the counter'))}</h4>
                        ${counter.map((c) => `
                            <div class="rx-row" style="grid-template-columns:1fr auto auto">
                                <div><b>${XS.esc(c.label)}</b></div>
                                <span class="rx-price">$${XS.esc(c.price)}</span>
                                <button class="xsm-key" data-buy="${XS.esc(c.item)}">${XS.esc(XS.t('ph_buy', null, 'Buy'))}</button>
                            </div>`).join('')}
                    </div>
                </div>
                <div class="ph-foot"><span>${XS.esc(XS.t('ph_foot', null, 'Prescriptions are pulled from your medical record.'))}</span><span>${XS.esc(XS.t('hint_esc', null, 'ESC to close'))}</span></div>
            </div>`;
        stage.querySelectorAll('[data-fill]').forEach((b) => b.addEventListener('click', () => act('pharmacy:fill', { id: Number(b.dataset.fill) })));
        stage.querySelectorAll('[data-buy]').forEach((b) => b.addEventListener('click', () => act('pharmacy:buy', { item: b.dataset.buy, qty: 1 })));
    }

    async function act(name, payload) {
        if (busy) return;
        busy = true;
        const res = await XS.rpc(name, payload);
        busy = false;
        XS.toast(res.ok ? res.data : res.error, res.ok ? 'ok' : 'error');
    }

    XS.apps.pharmacy = {
        isOpen: () => open,
        escape: () => XS.close('pharmacy'),
        on(action, payload) {
            if (action === 'open' || action === 'update') {
                data = payload;
                open = true;
                XS.show('xsm-pharmacy', true);
                render();
            } else if (action === 'close') {
                open = false;
                XS.show('xsm-pharmacy', false);
                root.innerHTML = '';
            }
        },
    };
})();
