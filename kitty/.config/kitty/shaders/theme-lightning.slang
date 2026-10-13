#language slang 2026
// Copyright (C) 2026 Kovid Goyal <kovid at kovidgoyal.net>
// Distributed under terms of the GPLv3 license.
//
// Lightning cursor trail — kitty's stock cursor-trail-lightning, re-coloured to
// track the active theme instead of the hardcoded orange/red.
//
// Every colour below is derived at runtime from d.cursor_trail_color.rgb, which
// kitty fills from the cursor_trail_color option and falls back to the cursor
// colour when that option is none. Serpantinum's matugen template writes the
// cursor colour from the Material You palette, so the bolt re-tints itself
// every time a new wallpaper regenerates ~/.config/kitty/colors.conf.
//
// Keep cursor_trail_color none in kitty.conf for this to keep working.

import kitty_custom_shader_types;

// Bolt lifetime in seconds. Shorter reads as a crackle rather than an arc.
static const float DURATION = 0.11;
// Sideways displacement relative to bolt length.
static const float JAGGEDNESS = 0.07;
// Core stroke width in pixels.
static const float CORE_WIDTH = 0.85;
// Glow radius in pixels. A wide halo smears the bolt into a blob.
static const float GLOW_WIDTH = 2.8;
// Number of linear segments that make up the main bolt.
static const int BOLT_SEGMENTS = 12;
// How far the bolt core is pushed toward white. 0 keeps the pure theme colour,
// 1 makes the core white and leaves the theme colour to the glow only.
static const float BOLT_WHITENESS = 0.5;
// Brightness of the outer glow relative to the theme colour. Deliberately low
// so the bolt stays a thin filament rather than a blob of colour.
static const float GLOW_GAIN = 0.26;
// Raises a very dark theme colour so the bolt stays visible against a dark
// background. 1.0 disables the correction.
static const float DARK_COLOR_FLOOR = 0.18;

static float
hash11(float p) {
    p = frac(p * 0.1031);
    p *= p + 33.33;
    p *= p + p;
    return frac(p);
}

static float
segDist(float2 p, float2 a, float2 b) {
    float2 ab = b - a;
    float t = clamp(dot(p - a, ab) / max(dot(ab, ab), 1e-7), 0.0, 1.0);
    return length(p - (a + ab * t));
}

// A point on the piecewise-linear bolt.  Endpoints stay fixed; interior nodes
// are displaced perpendicular to the travel direction.
static float2
boltPoint(float2 a, float2 b, float t, float seed) {
    float2 delta = b - a;
    float boltLength = length(delta);
    float2 perp = float2(-delta.y, delta.x) / max(boltLength, 1e-5);
    float node = floor(t * float(BOLT_SEGMENTS) + 0.5);
    float rnd = hash11(node * 17.17 + seed) * 2.0 - 1.0;
    float fade = sin(3.14159265 * t);
    return lerp(a, b, t) + perp * rnd * boltLength * JAGGEDNESS * fade;
}

// Minimum distance from p to the main bolt's piecewise-linear path.
static float
mainBoltDist(float2 p, float2 a, float2 b, float seed) {
    float minD = 1e5;
    float2 prev = a;
    [ForceUnroll]
    for (int i = 1; i <= BOLT_SEGMENTS; i++) {
        float t = float(i) / float(BOLT_SEGMENTS);
        float2 cur = boltPoint(a, b, t, seed);
        minD = min(minD, segDist(p, prev, cur));
        prev = cur;
    }
    return minD;
}

// Three small forks growing out of alternating points on the main bolt.
static float
forkDist(float2 p, float2 a, float2 b, float seed) {
    float minD = 1e5;
    float2 delta = b - a;
    float boltLength = length(delta);
    float2 perp = float2(-delta.y, delta.x) / max(boltLength, 1e-5);
    float2 dir = normalize(delta);
    [ForceUnroll]
    for (int i = 0; i < 3; i++) {
        float fi = float(i);
        float t = 0.28 + fi * 0.22;
        float2 root = boltPoint(a, b, t, seed);
        float side = lerp(-1.0, 1.0, step(0.5, hash11(seed + fi * 41.0)));
        float reach = boltLength * (0.055 + 0.035 * hash11(seed + fi * 53.0));
        float2 along = dir * reach * (hash11(seed + fi * 67.0) - 0.35);
        float2 tip = root + perp * side * reach + along;
        float2 elbow = lerp(root, tip, 0.52) - perp * side * reach * (0.12 + 0.18 * hash11(seed + fi * 79.0));
        minD = min(minD, segDist(p, root, elbow));
        minD = min(minD, segDist(p, elbow, tip));
    }
    return minD;
}

public float4
fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
    float age = clamp((d.timestamp - d.cursor_trail_change_time) / DURATION, 0.0, 1.0);
    if (age >= 1.0) return color;

    // Theme colour, in linear RGB. Falls back to the cursor colour when
    // cursor_trail_color is none, which is what keeps this in sync with matugen.
    float3 theme = d.cursor_trail_color.rgb;
    // Normalise so a near-black accent still throws a visible bolt.
    float peak = max(max(theme.r, theme.g), theme.b);
    theme *= lerp(1.0, DARK_COLOR_FLOOR / max(peak, 1e-4), step(peak, DARK_COLOR_FLOOR));
    float3 boltColor = lerp(theme, float3(1.0), saturate(BOLT_WHITENESS));
    float3 glowColor = theme * GLOW_GAIN;

    float2 pixelDims = float2(d.viewport_size_pixels) * t.viewport.zw;

    // Cursor centres in pixel space (edge: .x=left .y=right .z=top .w=bottom, y-up).
    float2 curCenter = float2((d.cursor_trail_edge.x + d.cursor_trail_edge.y) * 0.5, (d.cursor_trail_edge.z + d.cursor_trail_edge.w) * 0.5) * pixelDims;
    float2 prevCenter =
        float2((d.cursor_trail_prev_edge.x + d.cursor_trail_prev_edge.y) * 0.5, (d.cursor_trail_prev_edge.z + d.cursor_trail_prev_edge.w) * 0.5) * pixelDims;

    float2 px = t.pos * pixelDims;

    // Quantise the event time for a stable bolt shape across the bolt's lifetime.
    float seed = floor(d.cursor_trail_change_time * 1000.0) * 0.013;

    float mainD = mainBoltDist(px, prevCenter, curCenter, seed);
    float forkD = forkDist(px, prevCenter, curCenter, seed);

    float pixel = max(fwidth(mainD), 0.65);
    float core = 1.0 - smoothstep(CORE_WIDTH, CORE_WIDTH + pixel, mainD);
    float forkCore = 1.0 - smoothstep(CORE_WIDTH * 0.72, CORE_WIDTH * 0.72 + pixel, forkD);
    float glow = exp(-mainD * mainD / (GLOW_WIDTH * GLOW_WIDTH));
    float forkGlow = exp(-forkD * forkD / (GLOW_WIDTH * GLOW_WIDTH * 0.55));

    // Flash hard, then rapidly lose the core, leaving only glow.
    float flash = 1.0 - smoothstep(0.0, 1.0, age);
    flash *= flash;
    float flicker = 0.82 + 0.18 * sin(age * 95.0 + seed);
    float glowAmt = max(glow, forkGlow * 0.55) * flash * flicker * 0.72;
    float coreAmt = max(core, forkCore * 0.82) * flash * flicker;

    float3 rgb = lerp(color.rgb, glowColor, clamp(glowAmt, 0.0, 1.0));
    rgb = lerp(rgb, boltColor, clamp(coreAmt, 0.0, 1.0));

    // Keep the cursor crisp above the effect.
    float insideCursor = step(d.cursor_trail_edge.x, t.pos.x) * step(t.pos.x, d.cursor_trail_edge.y) * step(d.cursor_trail_edge.w, t.pos.y) *
                         step(t.pos.y, d.cursor_trail_edge.z);
    rgb = lerp(rgb, color.rgb, insideCursor);

    return float4(rgb, color.a);
}
