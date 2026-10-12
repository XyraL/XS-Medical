(() => {
    const waves = new Set();
    let running = false;
    let prev = performance.now();

    function ecgAt(phase, rhythm) {
        if (rhythm === 'asystole') return 0;
        if (rhythm === 'vf') return Math.sin(phase * 31) * 0.28 + Math.sin(phase * 13.7) * 0.18;
        if (phase < 0.08) return Math.sin(phase / 0.08 * Math.PI) * 0.12;
        if (phase < 0.16) return 0;
        if (phase < 0.19) return -0.14;
        if (phase < 0.22) return 0.95;
        if (phase < 0.25) return -0.32;
        if (phase < 0.4) return 0;
        if (phase < 0.55) return Math.sin((phase - 0.4) / 0.15 * Math.PI) * 0.2;
        return 0;
    }

    function plethAt(phase, rhythm) {
        if (rhythm === 'asystole' || rhythm === 'vf') return 0;
        return Math.max(0, Math.sin(phase * Math.PI * 2 - 0.6)) * 0.8 + Math.max(0, Math.sin(phase * Math.PI * 4 - 1.2)) * 0.15;
    }

    function frame(now) {
        const dt = Math.min(0.1, (now - prev) / 1000);
        prev = now;
        waves.forEach((w) => {
            if (!w.canvas.isConnected) { waves.delete(w); return; }
            const ctx = w.ctx;
            const width = w.canvas.width;
            const height = w.canvas.height;
            const hr = Math.max(0, Number(w.opts.hr()) || 0);
            const rhythm = w.opts.rhythm ? w.opts.rhythm() : 'sinus';
            w.beat += hr > 0 ? dt * hr / 60 : dt * 2.4;
            const phase = w.beat % 1;
            const nx = w.x + (w.opts.speed || 150) * dt;
            const amp = height * (w.opts.amp || 0.42);
            const base = height * (w.opts.kind === 'pleth' ? 0.78 : 0.62);
            const value = w.opts.kind === 'pleth' ? plethAt(phase, hr > 0 ? rhythm : 'asystole') : ecgAt(phase, hr > 0 || rhythm === 'vf' ? rhythm : 'asystole');
            const y = base - value * amp;
            ctx.clearRect(nx, 0, 16, height);
            if (w.lastY !== null && nx > w.x) {
                ctx.strokeStyle = w.opts.color;
                ctx.lineWidth = w.opts.width || 2.4;
                ctx.lineJoin = 'round';
                ctx.beginPath();
                ctx.moveTo(w.x, w.lastY);
                ctx.lineTo(nx, y);
                ctx.stroke();
            }
            w.lastY = y;
            w.x = nx;
            if (w.x > width) { w.x = 0; w.lastY = null; }
        });
        if (waves.size) requestAnimationFrame(frame);
        else running = false;
    }

    XS.Wave = {
        attach(canvas, opts) {
            if (!canvas) return;
            const rect = canvas.getBoundingClientRect();
            if (!canvas.width || canvas.width === 300) canvas.width = Math.max(200, Math.round(rect.width || 600));
            const w = { canvas, ctx: canvas.getContext('2d'), opts, x: 0, lastY: null, beat: 0 };
            waves.add(w);
            if (!running) {
                running = true;
                prev = performance.now();
                requestAnimationFrame(frame);
            }
        },
    };
})();
