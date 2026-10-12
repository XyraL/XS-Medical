(() => {
    const SPOTS = {
        head: [90, 26], torso: [90, 72], stomach: [90, 104],
        rarm: [50, 92], larm: [130, 92], rleg: [76, 178], lleg: [104, 178],
    };

    function colour(injury) {
        if (injury.bleed > 0) return '#ff4b4b';
        if (injury.surgery) return '#ff9ef0';
        if (injury.fracture && !(injury.treated && injury.treated.splint)) return '#ffe14a';
        if (injury.kind === 'burn') return '#ffb020';
        return '#36d8ff';
    }

    XS.Figure = {
        svg(injuries, opts) {
            const list = XS.list(injuries);
            const line = (opts && opts.line) || '#2c4a3d';
            const marks = [];
            const counts = {};
            list.forEach((injury) => {
                const spot = SPOTS[injury.part] || SPOTS.torso;
                const n = counts[injury.part] || 0;
                counts[injury.part] = n + 1;
                const dx = (n % 2 === 0 ? 1 : -1) * Math.ceil(n / 2) * 9;
                const c = colour(injury);
                marks.push(`<circle cx="${spot[0] + dx}" cy="${spot[1]}" r="8" fill="${c}55" stroke="${c}" stroke-width="2"><title>${XS.esc(XS.part(injury.part))}</title></circle>`);
            });
            return `<svg class="fig-svg" viewBox="0 0 180 230" preserveAspectRatio="xMidYMid meet">
                <g fill="none" stroke="${line}" stroke-width="2"><circle cx="90" cy="26" r="18"/><path d="M62 52 h56 l8 70 h-72 z"/><path d="M62 54 l-22 70 M118 54 l22 70"/><path d="M72 122 l-8 96 M108 122 l8 96"/></g>
                <g fill="#3f6153" font-family="Consolas" font-size="12" font-weight="700"><text x="10" y="24">${XS.esc(XS.t('fig_right', null, 'R'))}</text><text x="160" y="24">${XS.esc(XS.t('fig_left', null, 'L'))}</text></g>
                ${marks.join('')}
            </svg>`;
        },
    };
})();
