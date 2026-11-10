
override motion_enabled: bool = true;

override motion_idle_strength: f32 = 0.10;
override motion_walk_strength: f32 = 0.34;
override motion_run_strength: f32 = 0.56;

const MOTION_PI: f32 = 3.14159265359;
const MOTION_TAU: f32 = 6.28318530718;

fn motion_clamp_uv(uv: vec2<f32>) -> vec2<f32> {
    return clamp(uv, vec2<f32>(0.001), vec2<f32>(0.999));
}

fn motion_smooth_value(a: f32, b: f32, x: f32) -> f32 {
    let t = clamp((x - a) / max(b - a, 0.0001), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
}

fn motion_stable_speed(raw_speed: f32, time: f32) -> f32 {
    let slow = sin(time * 0.35) * 0.015;
    let medium = sin(time * 0.17 + 1.7) * 0.012;

    let stable = raw_speed * (1.0 + slow + medium);

    return clamp(stable, 0.0, 8.0);
}

fn motion_bobbing_offset(speed: f32, time: f32) -> vec2<f32> {
    let walking = motion_smooth_value(0.15, 1.5, speed);
    let running = motion_smooth_value(4.0, 6.0, speed);

    let frequency = mix(
        0.48,
        0.82,
        walking * (1.0 - running)
    );

    let final_frequency = mix(frequency, 1.08, running);

    let amplitude = mix(
        motion_idle_strength,
        motion_walk_strength,
        walking
    );

    let final_amplitude = mix(
        amplitude,
        motion_run_strength,
        running
    );

    let phase = time * MOTION_TAU * final_frequency;

    let horizontal =
        sin(phase) * final_amplitude * 0.25 +
        sin(phase * 0.5 + 1.2) * final_amplitude * 0.10;

    let vertical =
        sin(phase * 2.0 - 0.4) * final_amplitude * 0.34 +
        sin(phase * 0.7) * final_amplitude * 0.10;

    return vec2<f32>(horizontal, vertical);
}

fn motion_hand_instability(time: f32) -> vec2<f32> {
    let x =
        sin(time * 0.73) * 0.025 +
        sin(time * 0.41 + 2.0) * 0.018;

    let y =
        sin(time * 0.61 + 1.3) * 0.022 +
        sin(time * 0.32) * 0.016;

    return vec2<f32>(x, y);
}

fn motion_rotation_uv(
    uv: vec2<f32>,
    angle: f32
) -> vec2<f32> {
    let centered = uv - vec2<f32>(0.5);

    let c = cos(angle);
    let s = sin(angle);

    let rotated = vec2<f32>(
        centered.x * c - centered.y * s,
        centered.x * s + centered.y * c
    );

    return rotated + vec2<f32>(0.5);
}

fn motion_orientation(
    speed: f32,
    time: f32
) -> vec3<f32> {
    let walking = motion_smooth_value(0.15, 1.5, speed);
    let running = motion_smooth_value(4.0, 6.0, speed);

    let frequency = mix(0.82, 1.08, running);
    let phase = time * MOTION_TAU * frequency;

    let roll =
        sin(phase) * 0.0010 * walking +
        sin(time * 0.43) * 0.00035;

    let pitch =
        sin(phase * 2.0 - 0.5) * 0.00065 * walking +
        sin(time * 0.55) * 0.00025;

    let yaw =
        sin(phase * 0.5 + 1.0) * 0.00055 * walking +
        sin(time * 0.37) * 0.0003;

    return vec3<f32>(roll, pitch, yaw);
}

fn post(input: PostInput) -> vec4<f32> {
    if (!motion_enabled) {
        return input.color;
    }

    let dt = clamp(frame.delta_time, 0.001, 0.05);
    let time = frame.time;

    var raw_speed = 0.0;

    let movement = frame.camera_motion.xz;
    raw_speed = length(movement) / dt;

    let speed = motion_stable_speed(raw_speed, time);

    let walking = motion_smooth_value(0.15, 1.5, speed);
    let running = motion_smooth_value(4.0, 6.0, speed);

    let bob = motion_bobbing_offset(speed, time);
    let hands = motion_hand_instability(time);

    let orientation = motion_orientation(speed, time);

    let roll = orientation.x;
    let pitch = orientation.y;
    let yaw = orientation.z;

    let breathing =
        sin(time * MOTION_TAU * 0.22) *
        (1.0 - walking) *
        0.0008;

    let horizontal_sway =
        sin(time * MOTION_TAU * 0.42) *
        walking * 0.025;

    let vertical_sway =
        sin(time * MOTION_TAU * 0.82) *
        walking * 0.035;

    let resolution = max(
        frame.resolution,
        vec2<f32>(1.0)
    );

    let offset_pixels = vec2<f32>(
        bob.x + hands.x + horizontal_sway,
        bob.y + hands.y + breathing + vertical_sway
    );

    let offset_uv = offset_pixels / resolution;

    let rotated = motion_rotation_uv(
        input.uv,
        roll
    );

    let pitched = rotated +
        vec2<f32>(
            yaw * (input.uv.y - 0.5),
            pitch
        );

    let final_uv = motion_clamp_uv(
        pitched + offset_uv
    );

    return textureSampleLevel(
        previous,
        linear_sampler,
        final_uv,
        0.0
    );
}
