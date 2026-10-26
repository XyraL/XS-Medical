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

    const BODY = {
        head: [100, 40], torso: [100, 122], stomach: [100, 172],
        rarm: [47, 166], larm: [153, 166], rleg: [82, 268], lleg: [118, 268],
    };

    function tone(injury) {
        if (injury.bleed > 0) return '#ff4d5e';
        if (injury.surgery) return '#a88bff';
        if (injury.fracture && !(injury.treated && injury.treated.splint)) return '#ffb020';
        if (injury.kind === 'burn') return '#ff8a3d';
        return '#4d8dff';
    }

    XS.Figure = {
        tone,
        body(injuries) {
            const marks = [];
            const counts = {};
            XS.list(injuries).forEach((injury) => {
                const spot = BODY[injury.part] || BODY.torso;
                const n = counts[injury.part] || 0;
                counts[injury.part] = n + 1;
                const x = spot[0] + (n % 2 === 0 ? 1 : -1) * Math.ceil(n / 2) * 10;
                const c = tone(injury);
                marks.push(`<circle cx="${x}" cy="${spot[1]}" r="${injury.bleed > 0 ? 17 : 15}" fill="${c}24"/><circle cx="${x}" cy="${spot[1]}" r="7.5" fill="${c}5c" stroke="${c}" stroke-width="2"><title>${XS.esc(XS.part(injury.part))}</title></circle>`);
            });
            return `<svg class="fig-body" viewBox="22 6 156 390" preserveAspectRatio="xMidYMid meet">
                <g fill="#1b1b1f" stroke="#3a3a42" stroke-width="2" stroke-linejoin="round"><ellipse cx="100" cy="40" rx="22" ry="26"/><path d="M90 64h20v14H90z"/><path d="M88 76 C70 79 57 82 51 95 L41 152 L33 206 Q31 223 37 227 Q45 228 46 213 L54 162 L61 121 L63 176 Q60 197 64 211 L68 300 L70 372 Q70 388 84 388 L92 388 L94 300 L98 224 Q100 218 102 224 L106 300 L108 388 L116 388 Q130 388 130 372 L132 300 L136 211 Q140 197 137 176 L139 121 L146 162 L154 213 Q155 228 163 227 Q169 223 167 206 L159 152 L149 95 C143 82 130 79 112 76 Z"/></g>
                <g fill="#4a4a52" font-family="Consolas,monospace" font-size="13" font-weight="700"><text x="28" y="30">${XS.esc(XS.t('fig_right', null, 'R'))}</text><text x="162" y="30">${XS.esc(XS.t('fig_left', null, 'L'))}</text></g>
                ${marks.join('')}
            </svg>`;
        },
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
