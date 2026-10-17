"""Particle stream hero, ported from the design prototype into Jac.

A ribbon of particles flows from a far bend to the foreground: each dot is a product moving
through Kenya's supply chain. Gold at the source, sage in transit, teal at the shopper.
"""

import from react { useEffect }

obj Particle {
    has t: float = 0.0,
        off: float = 0.0,
        seed: float = 0.0,
        speed: float = 0.03,
        size: float = 1.0;
}

obj LutPoint {
    has x: float,
        y: float,
        nx: float,
        ny: float;
}

obj FieldState {
    has run: bool = False,
        w: float = 1.0,
        h: float = 1.0,
        s: float = 1.0,
        lut: list[LutPoint] = [],
        ps: list[Particle] = [],
        tx: float = 0.0,
        ty: float = 0.0,
        mx: float = 0.0,
        my: float = 0.0,
        last: float = 0.0;
}

glob CTRL: list[list[float]] = [
    [0.43, 0.25], [0.31, 0.265], [0.20, 0.31], [0.17, 0.39], [0.30, 0.47],
    [0.50, 0.55], [0.70, 0.66], [0.88, 0.79], [1.02, 0.90], [1.14, 1.02]
];
glob GOLD: list[float] = [222.0, 170.0, 62.0];
glob SAGE: list[float] = [118.0, 168.0, 140.0];
glob TEAL: list[float] = [36.0, 182.0, 182.0];
glob LUT_N: int = 600;
glob _st: FieldState = FieldState();

# typed wrappers over the browser's Math
def _rand() -> float { return Math.random() as float; }
def _sin(x: float) -> float { return Math.sin(x) as float; }
def _pow(b: float, e: float) -> float { return Math.pow(b, e) as float; }
def _floor(x: float) -> int { return Math.floor(x) as int; }
def _abs(x: float) -> float { return -x if x < 0 else x; }
def _clamp(x: float, lo: float, hi: float) -> float { return lo if x < lo else (hi if x > hi else x); }

def _catmull(p0: float, p1: float, p2: float, p3: float, t: float) -> float {
    t2 = t * t;
    t3 = t2 * t;
    return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3);
}

def _smooth(a: float, b: float, x: float) -> float {
    t = _clamp((x - a) / (b - a), 0.0, 1.0);
    return t * t * (3 - 2 * t);
}

def _mix(c1: list[float], c2: list[float], t: float) -> list[float] {
    return [c1[0] + (c2[0] - c1[0]) * t, c1[1] + (c2[1] - c1[1]) * t, c1[2] + (c2[2] - c1[2]) * t];
}

def _color_at(t: float) -> list[float] {
    if t < 0.38 {
        return _mix(GOLD, SAGE, _smooth(0.12, 0.38, t));
    }
    return _mix(SAGE, TEAL, _smooth(0.38, 0.8, t));
}

def _spawn(p: Particle, fresh: bool) -> Particle {
    p.t = _rand() if fresh else 0.0;
    p.off = (_rand() + _rand() + _rand() - 1.5) / 1.5;
    p.seed = _rand() * 6.2832;
    p.speed = 0.022 + _rand() * 0.03;
    p.size = 0.6 + _rand() * 0.8;
    return p;
}

def _build_lut() {
    segs = len(CTRL) - 1;
    pts: list[list[float]] = [];
    for i in range(LUT_N) {
        u = i / (LUT_N - 1) * segs;
        s = min(segs - 1, _floor(u));
        f = u - s;
        p0 = CTRL[max(0, s - 1)];
        p1 = CTRL[s];
        p2 = CTRL[s + 1];
        p3 = CTRL[min(segs, s + 2)];
        pts.append([_catmull(p0[0], p1[0], p2[0], p3[0], f) * _st.w, _catmull(p0[1], p1[1], p2[1], p3[1], f) * _st.h]);
    }
    lut: list[LutPoint] = [];
    for j in range(len(pts)) {
        a = pts[max(0, j - 1)];
        b = pts[min(len(pts) - 1, j + 1)];
        dx = b[0] - a[0];
        dy = b[1] - a[1];
        ln = (dx * dx + dy * dy) ** 0.5 or 1.0;
        lut.append(LutPoint(x=pts[j][0], y=pts[j][1], nx=-dy / ln, ny=dx / ln));
    }
    _st.lut = lut;
}

def _resize(canvas: any, ctx: any) {
    dpr: float = min(window.devicePixelRatio or 1, 2);  # jac:ignore[E1030]
    r = canvas.getBoundingClientRect();
    _st.w = max(1.0, r.width as float);
    _st.h = max(1.0, r.height as float);
    _st.s = max(0.55, _st.w / 1366);
    canvas.width = round(_st.w * dpr);
    canvas.height = round(_st.h * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    _build_lut();
    count = round(min(4200.0, max(1500.0, _st.w * 3.0)));
    _st.ps = [_spawn(Particle(), True) for _ in range(count)];
}

def _draw(ctx: any, time: float) {
    sec = time / 1000;
    sc = _st.s;
    ctx.clearRect(0, 0, _st.w, _st.h);
    for p in _st.ps {
        c = _st.lut[min(LUT_N - 1, max(0, _floor(p.t * (LUT_N - 1))))];
        spread = (3 + 150 * _pow(p.t, 1.55)) * sc;
        drift = _sin(sec * 0.6 + p.seed) * 0.12 + _sin(sec * 0.23 + p.seed * 2.1) * 0.08;
        o = (p.off + drift) * spread;
        depth = 0.15 + p.t * 0.85;
        x = c.x + c.nx * o - _st.mx * depth * 46 * sc;
        y = c.y + c.ny * o - _st.my * depth * 30 * sc;
        size = (p.size * 0.55 + _pow(p.t, 1.3) * 2.8 * p.size) * sc;
        alpha = _smooth(0, 0.1, p.t) * (0.28 + 0.72 * _smooth(0.05, 0.5, p.t)) * (1 - _abs(p.off) * 0.35);
        col = _color_at(p.t);
        ctx.fillStyle = "rgba(" + str(round(col[0])) + "," + str(round(col[1])) + "," + str(round(col[2])) + "," + str(alpha) + ")";
        if size < 1.4 {
            ctx.fillRect(x, y, size, size);
        } else {
            ctx.beginPath();
            ctx.arc(x, y, size * 0.5, 0, 6.2832);
            ctx.fill();
        }
    }
}

def _tick(ctx: any, time: float) {
    if not _st.run {
        return;
    }
    dt = min(0.05, (time - _st.last) / 1000 or 0.016);
    _st.last = time;
    _st.mx = _st.mx + (_st.tx - _st.mx) * min(1.0, dt * 4);
    _st.my = _st.my + (_st.ty - _st.my) * min(1.0, dt * 4);
    for p in _st.ps {
        p.t = p.t + p.speed * dt * (0.55 + p.t * 0.9);
        if p.t >= 1 {
            _spawn(p, False);
        }
    }
    _draw(ctx, time);
    requestAnimationFrame(lambda (t: float) { _tick(ctx, t); });
}

def:pub ParticleField(className: str = "") -> JsxElement {
    has canvasRef: Ref[HTMLCanvasElement] = Ref();

    useEffect(lambda {
        canvas: any = canvasRef.current;
        ctx: any = canvas.getContext("2d") if canvas else None;
        mq: any = window.matchMedia("(prefers-reduced-motion: reduce)");  # jac:ignore[E1030]
        reduce = mq.matches as bool;
        on_move = lambda (e: any) {
            vw = window.innerWidth as float;  # jac:ignore[E1030]
            vh = window.innerHeight as float;  # jac:ignore[E1030]
            _st.tx = ((e.clientX as float) / vw) * 2 - 1;
            _st.ty = ((e.clientY as float) / vh) * 2 - 1;
        };
        on_resize = lambda (e: any) { if canvas { _resize(canvas, ctx); } };
        if canvas {
            _resize(canvas, ctx);
            window.addEventListener("resize", on_resize);
            if reduce {
                _draw(ctx, 0);
            } else {
                window.addEventListener("pointermove", on_move);
                _st.run = True;
                requestAnimationFrame(lambda (t: float) { _tick(ctx, t); });
            }
        }
        return lambda {
            _st.run = False;
            window.removeEventListener("resize", on_resize);
            window.removeEventListener("pointermove", on_move);
        };
    }, []);

    return <canvas ref={canvasRef} aria-hidden="true" className={"absolute inset-0 block h-full w-full " + className}></canvas>;
}
