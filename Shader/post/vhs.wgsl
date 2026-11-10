
override vhs_enabled: bool = true;
override vhs_screen_type: u32 = 1u;

override vhs_grain: f32 = 0.13;
override vhs_dark_grain: f32 = 2.4;
override vhs_grain_speed: f32 = 24.0;

override vhs_overlay_strength: f32 = 0.58;
override vhs_bottom_noise_strength: f32 = 0.95;

override vhs_chromatic: f32 = 0.48;
override vhs_achromatic: f32 = 0.72;
override vhs_jpeg_compression: f32 = 0.82;
override vhs_jpeg_blocks: f32 = 0.65;
override vhs_color_artifacts: f32 = 0.16;

override vhs_scanlines: f32 = 0.14;
override vhs_scanline_fine: f32 = 0.04;

override vhs_bloom_strength: f32 = 1.35;
override vhs_bloom_threshold: f32 = 0.68;
override vhs_bloom_radius: f32 = 12.0;
override vhs_bloom_depth: f32 = 0.45;
override vhs_highlight_boost: f32 = 0.25;

override vhs_vignette: f32 = 0.18;
override vhs_flicker: f32 = 0.012;
override vhs_tape_noise: f32 = 0.045;
override vhs_dropout: f32 = 0.35;
override vhs_desaturation: f32 = 0.08;

fn vhs_hash(p: vec2<u32>, seed: u32) -> f32 {
    var h = p.x ^ (p.y * 0x9e3779b9u) ^ seed;
    h = h ^ (h >> 16u);
    h = h * 0x7feb352du;
    h = h ^ (h >> 15u);
    h = h * 0x846ca68bu;
    h = h ^ (h >> 16u);
    return f32(h >> 8u) * (1.0 / 16777216.0);
}

fn vhs_random(p: vec2<f32>, seed: u32) -> f32 {
    let cell = vec2<u32>(
        u32(max(floor(p.x), 0.0)),
        u32(max(floor(p.y), 0.0))
    );
    return vhs_hash(cell, seed);
}

fn vhs_clamp_uv(uv: vec2<f32>) -> vec2<f32> {
    return clamp(uv, vec2<f32>(0.001), vec2<f32>(0.999));
}

fn vhs_luma(c: vec3<f32>) -> f32 {
    return dot(c, vec3<f32>(0.299, 0.587, 0.114));
}

fn vhs_ycbcr(c: vec3<f32>) -> vec3<f32> {
    let y = vhs_luma(c);
    let cb = (c.b - y) * 0.564 + 0.5;
    let cr = (c.r - y) * 0.713 + 0.5;
    return vec3<f32>(y, cb, cr);
}

fn vhs_rgb(c: vec3<f32>) -> vec3<f32> {
    let y = c.x;
    let cb = c.y - 0.5;
    let cr = c.z - 0.5;
    return vec3<f32>(
        y + 1.402 * cr,
        y - 0.344136 * cb - 0.714136 * cr,
        y + 1.772 * cb
    );
}

fn vhs_sample(uv: vec2<f32>) -> vec3<f32> {
    return textureSampleLevel(
        previous,
        linear_sampler,
        vhs_clamp_uv(uv),
        0.0
    ).rgb;
}

fn vhs_bloom_sample(uv: vec2<f32>) -> vec3<f32> {
    let c = vhs_sample(uv);
    let brightness = vhs_luma(c);
    return c * max(brightness - vhs_bloom_threshold, 0.0);
}

fn vhs_bloom(
    uv: vec2<f32>,
    depth: f32,
    resolution: vec2<f32>
) -> vec3<f32> {
    let radius = vhs_bloom_radius / resolution;
    let x = vec2<f32>(radius.x, 0.0);
    let y = vec2<f32>(0.0, radius.y);
    let d1 = vec2<f32>(radius.x, radius.y);
    let d2 = vec2<f32>(radius.x, -radius.y);

    var bloom = vec3<f32>(0.0);

    bloom += vhs_bloom_sample(uv + x);
    bloom += vhs_bloom_sample(uv - x);
    bloom += vhs_bloom_sample(uv + y);
    bloom += vhs_bloom_sample(uv - y);
    bloom += vhs_bloom_sample(uv + d1) * 0.7;
    bloom += vhs_bloom_sample(uv - d1) * 0.7;
    bloom += vhs_bloom_sample(uv + d2) * 0.7;
    bloom += vhs_bloom_sample(uv - d2) * 0.7;
    bloom += vhs_bloom_sample(uv + x * 2.0) * 0.45;
    bloom += vhs_bloom_sample(uv - x * 2.0) * 0.45;
    bloom += vhs_bloom_sample(uv + y * 2.0) * 0.45;
    bloom += vhs_bloom_sample(uv - y * 2.0) * 0.45;

    let depth_factor = mix(
        1.0,
        0.85 + clamp(depth, 0.0, 1.0) * 0.3,
        vhs_bloom_depth
    );

    return bloom / 10.8 * depth_factor;
}

fn vhs_grain_noise(pixel: vec2<f32>, seed: u32) -> f32 {
    let p = floor(pixel);
    let fine = vhs_random(p, seed);
    let medium = vhs_random(floor(p / 2.0), seed + 91u);
    let coarse = vhs_random(floor(p / 4.0), seed + 157u);
    let micro = vhs_random(floor(p / 8.0), seed + 211u);

    return (
        (fine - 0.5) * 0.55 +
        (medium - 0.5) * 0.23 +
        (coarse - 0.5) * 0.14 +
        (micro - 0.5) * 0.08
    );
}

fn vhs_overlay_noise(pixel: vec2<f32>, seed: u32) -> f32 {
    let fine = vhs_random(pixel, seed);
    let medium = vhs_random(pixel / 2.0, seed + 73u);
    let soft = vhs_random(pixel / 5.0, seed + 149u);

    return (
        (fine - 0.5) * 0.72 +
        (medium - 0.5) * 0.20 +
        (soft - 0.5) * 0.08
    );
}

fn vhs_scanline(pixel: vec2<f32>) -> f32 {
    let y = floor(pixel.y);
    let coarse = 0.5 + 0.5 * cos(y * 3.14159265);
    let fine = 0.5 + 0.5 * cos(y * 6.2831853);
    let variation = vhs_random(vec2<f32>(y, 13.0), 29u);

    return 1.0 -
        coarse * vhs_scanlines -
        fine * vhs_scanline_fine -
        variation * vhs_scanlines * 0.06;
}

fn vhs_tape_overlay(pixel: vec2<f32>, seed: u32) -> f32 {
    let row = floor(pixel.y);
    let line_random = vhs_random(vec2<f32>(row, 17.0), 329u + seed);
    let line_mask = step(0.991, line_random);

    let detail = vhs_random(pixel / vec2<f32>(3.0, 1.0), 541u + seed);
    let secondary = vhs_random(pixel / vec2<f32>(9.0, 3.0), 673u + seed);

    return (
        (detail - 0.5) * 0.7 +
        (secondary - 0.5) * 0.3
    ) * line_mask;
}

fn vhs_dropout_noise(pixel: vec2<f32>) -> f32 {
    let row = floor(pixel.y / 2.0);
    let column = floor(pixel.x / 24.0);
    let random_value = vhs_random(vec2<f32>(row, column), 853u);

    return step(
        1.0 - clamp(vhs_dropout, 0.0, 1.0) * 0.008,
        random_value
    );
}

fn vhs_time_seed(time: f32, speed: f32, period: f32) -> u32 {
    let phase = fract(time / period);
    return u32(floor(phase * period * speed));
}

fn vhs_chroma_corruption(
    pixel: vec2<f32>,
    seed: u32
) -> vec2<f32> {
    let p8 = floor(pixel / 8.0);
    let p16 = floor(pixel / 16.0);

    let a = vhs_random(p8, seed + 311u);
    let b = vhs_random(p8 + vec2<f32>(17.0, 31.0), seed + 617u);
    let c = vhs_random(p16, seed + 919u);

    let irregular = mix(a, b, 0.42);
    let broad = mix(irregular, c, 0.32);

    let cb = (irregular - 0.5) * 0.34 + (b - 0.5) * 0.16;
    let cr = (broad - 0.5) * 0.42 + (a - 0.5) * 0.12;

    return vec2<f32>(cb, cr);
}

fn vhs_chroma_bleed(
    uv: vec2<f32>,
    resolution: vec2<f32>,
    strength: f32
) -> vec2<f32> {
    let offset = vec2<f32>(2.0, 1.0) / resolution;

    let left = vhs_ycbcr(vhs_sample(uv - offset));
    let right = vhs_ycbcr(vhs_sample(uv + offset));
    let up = vhs_ycbcr(vhs_sample(uv + vec2<f32>(0.0, offset.y)));
    let down = vhs_ycbcr(vhs_sample(uv - vec2<f32>(0.0, offset.y)));

    let center = vhs_ycbcr(vhs_sample(uv));

    let neighbor_cb = (left.y + right.y + up.y + down.y) * 0.25;
    let neighbor_cr = (left.z + right.z + up.z + down.z) * 0.25;

    return vec2<f32>(
        mix(center.y, neighbor_cb, strength),
        mix(center.z, neighbor_cr, strength)
    );
}

fn vhs_chroma_palette_artifact(
    pixel: vec2<f32>,
    seed: u32
) -> vec3<f32> {
    let a = vhs_random(floor(pixel / 8.0), seed + 1201u);
    let b = vhs_random(floor(pixel / 16.0), seed + 1451u);

    let purple = vec3<f32>(0.48, 0.035, 0.72);
    let magenta = vec3<f32>(0.85, 0.035, 0.42);
    let blue = vec3<f32>(0.035, 0.18, 0.85);
    let pink = vec3<f32>(0.92, 0.22, 0.52);

    let first = mix(purple, magenta, a);
    let second = mix(blue, pink, b);

    return mix(first, second, b);
}

fn vhs_bottom_noise(
    pixel: vec2<f32>,
    resolution: vec2<f32>,
    seed: u32
) -> vec2<f32> {
    let normalized = pixel / resolution;
    let bottom_distance = 1.0 - normalized.y;

    let vertical_mask = 1.0 - smoothstep(
        0.006,
        0.052,
        bottom_distance
    );

    let fine = vhs_random(pixel, seed);
    let fine2 = vhs_random(pixel, seed + 193u);
    let fine3 = vhs_random(pixel, seed + 397u);

    let grain = (
        (fine - 0.5) * 0.65 +
        (fine2 - 0.5) * 0.25 +
        (fine3 - 0.5) * 0.10
    );

    let noise = clamp(0.5 + grain * 1.8, 0.0, 1.0);

    return vec2<f32>(noise, vertical_mask);
}

fn post(input: PostInput) -> vec4<f32> {
    let original = input.color;

    if (!vhs_enabled) {
        return original;
    }

    let resolution = max(frame.resolution, vec2<f32>(1.0));
    let aspect = resolution.x / resolution.y;
    let time = frame.time;
    let pixel = floor(input.pixel);

    let grain_seed = vhs_time_seed(time, max(vhs_grain_speed, 1.0), 64.0);
    let flicker_seed = vhs_time_seed(time, 12.0, 32.0);
    let overlay_seed = vhs_time_seed(time, 8.0, 64.0);
    let bottom_seed = vhs_time_seed(time, 24.0, 64.0);

    var target_aspect = 16.0 / 9.0;

    if (vhs_screen_type == 1u) {
        target_aspect = 4.0 / 3.0;
    } else if (vhs_screen_type == 2u) {
        target_aspect = 1.0;
    }

    var screen_scale = vec2<f32>(1.0);

    if (target_aspect < aspect) {
        screen_scale.x = target_aspect / aspect;
    } else {
        screen_scale.y = aspect / target_aspect;
    }

    let screen_offset = (vec2<f32>(1.0) - screen_scale) * 0.5;

    if (
        input.uv.x < screen_offset.x ||
        input.uv.x > screen_offset.x + screen_scale.x ||
        input.uv.y < screen_offset.y ||
        input.uv.y > screen_offset.y + screen_scale.y
    ) {
        return vec4<f32>(0.0, 0.0, 0.0, original.a);
    }

    let uv = (input.uv - screen_offset) / screen_scale;
    let centered = (uv - vec2<f32>(0.5)) * vec2<f32>(aspect, 1.0);
    let edge = smoothstep(0.12, 0.85, length(centered));
    let radial = normalize(centered + vec2<f32>(0.00001));

    var color = original.rgb;

    let chromatic_offset = radial * edge * vhs_chromatic * 0.65 / resolution;
    let red_sample = vhs_sample(input.uv + chromatic_offset);
    let blue_sample = vhs_sample(input.uv - chromatic_offset);

    color.r = mix(
        color.r,
        red_sample.r,
        clamp(vhs_chromatic, 0.0, 1.0) * edge * 0.55
    );

    color.b = mix(
        color.b,
        blue_sample.b,
        clamp(vhs_chromatic, 0.0, 1.0) * edge * 0.55
    );

    let achromatic_offset = radial * edge * vhs_achromatic * 2.0 / resolution;

    let lens_center = vhs_luma(vhs_sample(input.uv));
    let lens_outer = vhs_luma(vhs_sample(input.uv + achromatic_offset));
    let lens_inner = vhs_luma(vhs_sample(input.uv - achromatic_offset));

    let lens_edge = (lens_outer + lens_inner) * 0.5 - lens_center;

    color += vec3<f32>(
        lens_edge * clamp(vhs_achromatic, 0.0, 1.0) * edge * 0.85
    );

    let compression = clamp(vhs_jpeg_compression, 0.0, 1.0);
    let block_strength = clamp(vhs_jpeg_blocks, 0.0, 1.0);
    let artifact_strength = clamp(vhs_color_artifacts, 0.0, 0.5) * 2.0;

    let chroma_bleed = vhs_chroma_bleed(
        input.uv,
        resolution,
        compression * 0.92
    );

    let ycc = vhs_ycbcr(color);

    let chroma_corruption = vhs_chroma_corruption(
        uv * resolution,
        overlay_seed
    );

    let block_noise = chroma_corruption *
        compression *
        block_strength;

    let corrupted_ycc = vec3<f32>(
        ycc.x,
        chroma_bleed.x + block_noise.x * 0.30,
        chroma_bleed.y + block_noise.y * 0.30
    );

    let chroma_color = vhs_rgb(corrupted_ycc);

    color = mix(
        color,
        chroma_color,
        compression * 0.82
    );

    let block_palette = vhs_chroma_palette_artifact(
        uv * resolution,
        overlay_seed
    );

    let block_position = fract(uv * resolution / 8.0);

    let block_edge = min(
        min(block_position.x, 1.0 - block_position.x),
        min(block_position.y, 1.0 - block_position.y)
    );

    let block_boundary = 1.0 - smoothstep(
        0.0,
        0.18,
        block_edge
    );

    let block_random = vhs_random(
        floor(uv * resolution / 8.0),
        overlay_seed + 1789u
    );

    let irregular_mask = smoothstep(
        0.38,
        0.82,
        block_random
    );

    let chroma_patch = block_palette *
        irregular_mask *
        compression *
        block_strength *
        artifact_strength;

    color += chroma_patch * 0.24;

    let ringing = vhs_chroma_corruption(
        uv * resolution + vec2<f32>(3.0, 7.0),
        overlay_seed + 2017u
    );

    color += vec3<f32>(
        ringing.x * 0.65 + ringing.y * 0.25,
        -ringing.x * 0.15 + ringing.y * 0.12,
        ringing.x * 0.35 - ringing.y * 0.55
    ) * compression * artifact_strength * 0.22;

    color += block_palette *
        block_boundary *
        block_random *
        compression *
        block_strength *
        artifact_strength *
        0.025;

    let luminance = vhs_luma(max(color, vec3<f32>(0.0)));
    let darkness = 1.0 - smoothstep(0.025, 0.65, luminance);

    let grain = vhs_grain_noise(pixel, grain_seed);
    let grain_strength = vhs_grain * (1.0 + darkness * vhs_dark_grain);

    let scanline = vhs_scanline(pixel);
    let bloom = vhs_bloom(input.uv, input.depth, resolution);

    let bloom_intensity = vhs_bloom_strength * (1.0 + darkness * 0.45);
    let highlight = smoothstep(vhs_bloom_threshold, 1.0, luminance);

    color += bloom * bloom_intensity;
    color += vec3<f32>(highlight * vhs_highlight_boost);

    let highlight_overexposure = smoothstep(
        0.72,
        1.15,
        vhs_luma(max(color, vec3<f32>(0.0)))
    );

    color = mix(
        color,
        color + vec3<f32>(0.16, 0.14, 0.12),
        highlight_overexposure * 0.35
    );

    let vignette_distance = dot(centered, centered);
    let vignette = 1.0 - smoothstep(0.28, 1.0, vignette_distance) * vhs_vignette;

    let flicker_random = vhs_random(
        vec2<f32>(f32(flicker_seed), 7.0),
        13u
    );

    let flicker = 1.0 + (flicker_random - 0.5) * vhs_flicker;

    color = mix(
        color,
        vec3<f32>(vhs_luma(color)),
        vhs_desaturation
    );

    color *= scanline * vignette * flicker;

    let overlay = vhs_overlay_noise(pixel, overlay_seed);
    let tape = vhs_tape_overlay(pixel, overlay_seed);
    let dropout = vhs_dropout_noise(pixel);

    color += vec3<f32>(
        grain * grain_strength +
        overlay * vhs_tape_noise * vhs_overlay_strength +
        tape * vhs_tape_noise * vhs_overlay_strength +
        dropout * vhs_tape_noise * 1.5 * vhs_overlay_strength
    );

    let bottom_noise = vhs_bottom_noise(
        uv * resolution,
        resolution,
        bottom_seed
    );

    let bottom_mask = bottom_noise.y;
    let bottom_intensity = clamp(vhs_bottom_noise_strength, 0.0, 1.0);

    let bottom_background = vec3<f32>(0.008);
    let bottom_grain = vec3<f32>(bottom_noise.x * 0.34);

    let bottom_color = mix(
        bottom_background,
        bottom_grain,
        0.88
    );

    color = mix(
        color,
        bottom_color,
        bottom_mask * bottom_intensity
    );

    color = max(color, vec3<f32>(0.0));

    return vec4<f32>(color, original.a);
}
