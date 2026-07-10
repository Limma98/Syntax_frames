/* Cinematic Cam NUI — talks to client/client.lua via NUI callbacks */

const resName = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'syntax_frames';

function post(name, data = {}) {
    fetch(`https://${resName}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data),
    });
}

const $ = (id) => document.getElementById(id);

// limit live slider posts to ~20/s so dragging doesn't flood the Lua side
function throttled(fn, ms) {
    let last = 0, timer = null;
    return (...args) => {
        const now = Date.now();
        clearTimeout(timer);
        if (now - last >= ms) {
            last = now;
            fn(...args);
        } else {
            timer = setTimeout(() => { last = Date.now(); fn(...args); }, ms);
        }
    };
}

/* ---------- sliders ---------- */

const sliders = {};

// paint the accent fill up to the thumb (plain CSS can't style the lower track in CEF)
function paintTrack(input) {
    const min = parseFloat(input.min), max = parseFloat(input.max);
    const pct = ((parseFloat(input.value) - min) / (max - min)) * 100;
    input.style.background = `linear-gradient(90deg, var(--gold) ${pct}%, var(--line) ${pct}%)`;
}

function setupSlider(id, valId, cbName, range, value, decimals) {
    const input = $(id), val = $(valId);
    input.min = range.min;
    input.max = range.max;
    input.step = range.step;
    input.value = value;
    val.textContent = Number(value).toFixed(decimals);
    paintTrack(input);

    if (!sliders[id]) {
        sliders[id] = { input, val, decimals };
        const send = throttled((v) => post(cbName, { value: v }), 50);
        input.addEventListener('input', () => {
            const v = parseFloat(input.value);
            val.textContent = v.toFixed(decimals);
            paintTrack(input);
            send(v);
        });
    } else {
        sliders[id].decimals = decimals;
    }
}

// update a slider from Lua without re-posting the value back
function setSliderValue(id, value) {
    const s = sliders[id];
    if (!s) return;
    s.input.value = value;
    s.val.textContent = Number(value).toFixed(s.decimals);
    paintTrack(s.input);
}

/* ---------- toggles / selects ---------- */

function setupToggle(id, cbName, checked) {
    const input = $(id);
    input.checked = checked;
    if (!input.dataset.bound) {
        input.dataset.bound = '1';
        input.addEventListener('change', () => post(cbName, { value: input.checked }));
    }
}

function fillSelect(id, items, selectedIndex) {
    const sel = $(id);
    sel.innerHTML = '';
    items.forEach((name, i) => {
        const opt = document.createElement('option');
        opt.value = i + 1;      // Lua tables are 1-based
        opt.textContent = name;
        sel.appendChild(opt);
    });
    sel.selectedIndex = selectedIndex - 1;
}

/* ---------- open / close / sync ---------- */

function setAttached(attached) {
    $('btn-attach').classList.toggle('active', attached);
}

function initPanel(d) {
    const S = d.strings || {};

    // labels straight from the resource's localization files
    $('title').textContent = S.menuTitle || 'Cinematic Cam';
    $('lbl-cam').textContent = S.toggleCam || 'Camera active';
    $('lbl-precision').textContent = S.precision || 'Camera Precision';
    $('lbl-filter-sec').textContent = S.filter || 'Filter';
    $('lbl-filter').textContent = S.filter || 'Filter';
    $('lbl-intensity').textContent = S.filterInten || 'Filter Intensity';
    $('btn-resetfilter').textContent = S.delFilter || 'Reset Filter';
    $('lbl-showmap').textContent = S.showMap || 'Show Minimap';
    $('lbl-freefly').textContent = S.freeFly || 'Free Fly Mode';
    $('lbl-charcontrol').textContent = S.charControl || 'Character Control';
    $('attach-label').textContent = S.attachCam || 'Attach camera to:';
    $('lbl-capture-sec').textContent = S.captureSec || 'Capture';
    $('lbl-screenshot').textContent = S.screenshot || 'Take Screenshot';

    setupSlider('in-precision', 'val-precision', 'setPrecision', d.ranges.precision, d.state.precision, 1);
    setupSlider('in-speed', 'val-speed', 'setSpeed', d.ranges.speed, d.state.speed, 1);
    setupSlider('in-fov', 'val-fov', 'setFov', d.ranges.fov, d.state.fov, 0);
    setupSlider('in-intensity', 'val-intensity', 'setIntensity', d.ranges.intensity, d.state.intensity, 1);

    setupToggle('in-cam', 'setCamActive', d.state.camActive);
    setupToggle('in-showmap', 'setShowMap', d.state.showMap);
    setupToggle('in-freefly', 'setFreeFly', d.state.freeFly);
    setupToggle('in-charcontrol', 'setCharControl', d.state.charControl);

    fillSelect('in-filter', d.filters, d.state.filter);

    $('btn-attach').classList.toggle('hidden', !d.attachEnabled);
    setAttached(d.state.attached);
    $('attach-target').textContent = '-';

    // OrbitCam section only shows when the OrbitCam resource is running
    if (d.orbit) {
        $('sec-orbit').classList.remove('hidden');
        $('lbl-orbit-sec').textContent = S.OrbitLabel || 'OrbitCam';
        $('lbl-orbit').textContent = S.OrbitLabel || 'OrbitCam';
        $('lbl-orbitspeed').textContent = S.OrbitSpeedLabel || 'Rotation speed';
        $('lbl-orbitcontrols').textContent = S.OrbitPlayerCon || 'Controls';
        $('lbl-orbitbone').textContent = S.OrbitBoneLabel || 'Bone';

        setupToggle('in-orbit', 'setOrbit', d.orbit.active);
        setupToggle('in-orbitcontrols', 'setOrbitControls', d.orbit.controls);
        setupSlider('in-orbitspeed', 'val-orbitspeed', 'setOrbitSpeed', d.ranges.intensity, d.orbit.speed, 1);
        fillSelect('in-orbitbone', d.orbit.bones, d.orbit.bone);
    } else {
        $('sec-orbit').classList.add('hidden');
    }

    // clear any leftover screenshot state from a previous session
    $('panel').style.visibility = '';
    $('btn-screenshot').classList.remove('is-busy');

    $('panel').classList.remove('hidden');
    navReset();
}

/* ---------- arrow-key navigation ---------- */
/* Fully keyboard-driven: ↑/↓ move, ←/→ adjust, Enter selects, Backspace = back.
   Mouse still works; hovering a row syncs the highlight to it. WASD keeps flying
   the cam (those keys never collide with the nav keys). */

let navItems = [];
let navIndex = 0;

// every visible interactive row / button, in on-screen order
function collectNavItems() {
    const out = [];
    document.querySelectorAll('#body .row, #body .btn').forEach((el) => {
        if (el.offsetParent === null) return;               // skip hidden sections
        out.push(el);
    });
    return out;
}

// the actual control inside a nav row (or the button itself)
function navControl(el) {
    return el.querySelector('input[type="range"]')
        || el.querySelector('input[type="checkbox"]')
        || el.querySelector('select')
        || (el.classList.contains('btn') ? el : null);
}

function navHighlight() {
    navItems.forEach((el, i) => el.classList.toggle('nav-active', i === navIndex));
}

function navReset() {
    navItems = collectNavItems();
    navIndex = 0;               // always start from the top row when the panel opens
    navHighlight();
}

function navMove(dir) {
    navItems = collectNavItems();
    if (!navItems.length) return;
    navIndex = (navIndex + dir + navItems.length) % navItems.length;
    navHighlight();
    navItems[navIndex].scrollIntoView({ block: 'nearest' });
}

// ←/→ : nudge sliders, cycle selects, flip toggles
function navAdjust(dir) {
    const el = navItems[navIndex];
    if (!el) return;
    const c = navControl(el);
    if (!c) return;

    if (c.tagName === 'INPUT' && c.type === 'range') {
        if (dir > 0) c.stepUp(); else c.stepDown();
        c.dispatchEvent(new Event('input'));
    } else if (c.tagName === 'INPUT' && c.type === 'checkbox') {
        c.checked = !c.checked;
        c.dispatchEvent(new Event('change'));
    } else if (c.tagName === 'SELECT') {
        const n = c.options.length;
        if (!n) return;
        c.selectedIndex = (c.selectedIndex + dir + n) % n;
        c.dispatchEvent(new Event('change'));
    }
}

// Enter : click buttons, flip toggles
function navActivate() {
    const el = navItems[navIndex];
    if (!el) return;
    if (el.classList.contains('btn')) { el.click(); return; }
    const c = navControl(el);
    if (c && c.tagName === 'INPUT' && c.type === 'checkbox') {
        c.checked = !c.checked;
        c.dispatchEvent(new Event('change'));
    }
}

// keep the highlight in sync when the mouse is used
document.addEventListener('mouseover', (e) => {
    const el = e.target.closest('#body .row, #body .btn');
    if (!el) return;
    const idx = navItems.indexOf(el);
    if (idx !== -1 && idx !== navIndex) { navIndex = idx; navHighlight(); }
});

function applySync(p) {
    if (p.speed !== undefined) setSliderValue('in-speed', p.speed);
    if (p.fov !== undefined) setSliderValue('in-fov', p.fov);
    if (p.intensity !== undefined) setSliderValue('in-intensity', p.intensity);
    if (p.filter !== undefined) $('in-filter').selectedIndex = p.filter - 1;
    if (p.camActive !== undefined) $('in-cam').checked = p.camActive;
    if (p.attachLabel !== undefined) $('attach-target').textContent = p.attachLabel;
    if (p.attached !== undefined) setAttached(p.attached);
}

window.addEventListener('message', ({ data: msg }) => {
    if (msg.action === 'open') initPanel(msg.data);
    else if (msg.action === 'close') $('panel').classList.add('hidden');
    else if (msg.action === 'sync') applySync(msg.data);
    // hide the panel for a clean screenshot, then bring it back
    else if (msg.action === 'hideForShot') $('panel').style.visibility = 'hidden';
    else if (msg.action === 'showAfterShot') {
        $('panel').style.visibility = '';
        $('btn-screenshot').classList.remove('is-busy');
    }
});

/* ---------- static bindings ---------- */

$('btn-close').addEventListener('click', () => post('uiClose'));
$('btn-resetfilter').addEventListener('click', () => post('resetFilter'));
$('btn-attach').addEventListener('click', () => post('toggleAttach'));
$('btn-screenshot').addEventListener('click', () => {
    const b = $('btn-screenshot');
    if (b.classList.contains('is-busy')) return;   // already capturing
    b.classList.add('is-busy');
    post('takeScreenshot');
});

$('in-filter').addEventListener('change', () => post('setFilter', { value: $('in-filter').selectedIndex + 1 }));
$('in-orbitbone').addEventListener('change', () => post('setOrbitBone', { value: $('in-orbitbone').selectedIndex + 1 }));

// Keyboard navigation. DEL is handled game-side so it can also re-open the panel.
document.addEventListener('keydown', (e) => {
    if ($('panel').classList.contains('hidden')) return;

    // drop native focus so a mouse-focused slider/select doesn't double-handle arrows
    if (document.activeElement && document.activeElement !== document.body) {
        document.activeElement.blur();
    }

    switch (e.key) {
        case 'ArrowDown':  navMove(1);  e.preventDefault(); break;
        case 'ArrowUp':    navMove(-1); e.preventDefault(); break;
        case 'ArrowRight': navAdjust(1);  e.preventDefault(); break;
        case 'ArrowLeft':  navAdjust(-1); e.preventDefault(); break;
        case 'Enter':      navActivate(); e.preventDefault(); break;
        case 'Backspace':  post('uiClose'); e.preventDefault(); break;
        case 'Escape':     post('uiClose'); break;
    }
});
