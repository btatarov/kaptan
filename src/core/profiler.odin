package core

import "core:time"
import "core:slice"

FrameProfilerTick :: time.Tick
FRAME_PROFILE_SAMPLE_COUNT :: 2048

FrameProfileBucket :: struct {
    last_ns:      i64,
    total_ns:     i64,
    max_ns:       i64,
    samples:      [FRAME_PROFILE_SAMPLE_COUNT]i64,
    sample_index: int,
    sample_count: int,
}

FrameProfilerRenderCounters :: struct {
    layer_items_visited: u64,
    sprites_drawn:       u64,
    sprites_skipped:     u64,
    draw_shapes_drawn:   u64,
    draw_shapes_skipped: u64,
    texts_drawn:         u64,
    texts_skipped:       u64,
    text_boxes_drawn:    u64,
    text_boxes_skipped:  u64,
}

FrameProfileBucketSnapshot :: struct {
    last_ms: f64,
    avg_ms:  f64,
    max_ms:  f64,
    p95_ms:  f64,
    p99_ms:  f64,
}

FrameProfileSnapshot :: struct {
    enabled:               bool,
    frames:                u64,
    total:                 FrameProfileBucketSnapshot,
    physics:               FrameProfileBucketSnapshot,
    lua:                   FrameProfileBucketSnapshot,
    audio:                 FrameProfileBucketSnapshot,
    render:                FrameProfileBucketSnapshot,
    end_drawing:           FrameProfileBucketSnapshot,
    temp_free:             FrameProfileBucketSnapshot,
    last_render_counters:  FrameProfilerRenderCounters,
    total_render_counters: FrameProfilerRenderCounters,
}

FrameProfiler :: struct {
    enabled:               bool,
    frames:                u64,
    total:                 FrameProfileBucket,
    physics:               FrameProfileBucket,
    lua:                   FrameProfileBucket,
    audio:                 FrameProfileBucket,
    render:                FrameProfileBucket,
    end_drawing:           FrameProfileBucket,
    temp_free:             FrameProfileBucket,
    current_render_counters: FrameProfilerRenderCounters,
    last_render_counters:  FrameProfilerRenderCounters,
    total_render_counters: FrameProfilerRenderCounters,
}

@(private="file") profiler: FrameProfiler

FrameProfilerIsEnabled :: proc "contextless" () -> bool {
    return profiler.enabled
}

FrameProfilerSetEnabled :: proc "contextless" (enabled: bool) {
    if enabled && ! profiler.enabled {
        FrameProfilerReset()
    }

    profiler.enabled = enabled
}

FrameProfilerReset :: proc "contextless" () {
    enabled := profiler.enabled
    profiler = {}
    profiler.enabled = enabled
}

FrameProfilerNow :: proc "contextless" () -> FrameProfilerTick {
    return time.tick_now()
}

FrameProfilerBeginFrame :: proc "contextless" () -> FrameProfilerTick {
    profiler.current_render_counters = {}
    return FrameProfilerNow()
}

FrameProfilerAddPhysics :: proc "contextless" (start: FrameProfilerTick) {
    add_duration(&profiler.physics, start)
}

FrameProfilerAddLua :: proc "contextless" (start: FrameProfilerTick) {
    add_duration(&profiler.lua, start)
}

FrameProfilerAddAudio :: proc "contextless" (start: FrameProfilerTick) {
    add_duration(&profiler.audio, start)
}

FrameProfilerAddRender :: proc "contextless" (start: FrameProfilerTick) {
    add_duration(&profiler.render, start)
}

FrameProfilerAddEndDrawing :: proc "contextless" (start: FrameProfilerTick) {
    add_duration(&profiler.end_drawing, start)
}

FrameProfilerAddTempFree :: proc "contextless" (start: FrameProfilerTick) {
    add_duration(&profiler.temp_free, start)
}

FrameProfilerEndFrame :: proc "contextless" (start: FrameProfilerTick) {
    add_duration(&profiler.total, start)
    profiler.frames += 1
    profiler.last_render_counters = profiler.current_render_counters
    add_render_counters(&profiler.total_render_counters, profiler.current_render_counters)
}

FrameProfilerCountLayerItemVisited :: proc "contextless" () {
    if profiler.enabled {
        profiler.current_render_counters.layer_items_visited += 1
    }
}

FrameProfilerCountSpriteDrawn :: proc "contextless" () {
    if profiler.enabled {
        profiler.current_render_counters.sprites_drawn += 1
    }
}

FrameProfilerCountSpriteSkipped :: proc "contextless" () {
    if profiler.enabled {
        profiler.current_render_counters.sprites_skipped += 1
    }
}

FrameProfilerCountDrawShapeDrawn :: proc "contextless" () {
    if profiler.enabled {
        profiler.current_render_counters.draw_shapes_drawn += 1
    }
}

FrameProfilerCountDrawShapeSkipped :: proc "contextless" () {
    if profiler.enabled {
        profiler.current_render_counters.draw_shapes_skipped += 1
    }
}

FrameProfilerCountTextDrawn :: proc "contextless" () {
    if profiler.enabled {
        profiler.current_render_counters.texts_drawn += 1
    }
}

FrameProfilerCountTextSkipped :: proc "contextless" () {
    if profiler.enabled {
        profiler.current_render_counters.texts_skipped += 1
    }
}

FrameProfilerCountTextBoxDrawn :: proc "contextless" () {
    if profiler.enabled {
        profiler.current_render_counters.text_boxes_drawn += 1
    }
}

FrameProfilerCountTextBoxSkipped :: proc "contextless" () {
    if profiler.enabled {
        profiler.current_render_counters.text_boxes_skipped += 1
    }
}

FrameProfilerSnapshot :: proc() -> FrameProfileSnapshot {
    return FrameProfileSnapshot{
        enabled = profiler.enabled,
        frames = profiler.frames,
        total = bucket_snapshot(profiler.total, profiler.frames),
        physics = bucket_snapshot(profiler.physics, profiler.frames),
        lua = bucket_snapshot(profiler.lua, profiler.frames),
        audio = bucket_snapshot(profiler.audio, profiler.frames),
        render = bucket_snapshot(profiler.render, profiler.frames),
        end_drawing = bucket_snapshot(profiler.end_drawing, profiler.frames),
        temp_free = bucket_snapshot(profiler.temp_free, profiler.frames),
        last_render_counters = profiler.last_render_counters,
        total_render_counters = profiler.total_render_counters,
    }
}

@(private="file")
add_duration :: proc "contextless" (bucket: ^FrameProfileBucket, start: FrameProfilerTick) {
    if ! profiler.enabled {
        return
    }

    ns := time.duration_nanoseconds(time.tick_since(start))
    bucket.last_ns = ns
    bucket.total_ns += ns
    bucket.max_ns = max(bucket.max_ns, ns)
    bucket.samples[bucket.sample_index] = ns
    bucket.sample_index = (bucket.sample_index + 1) % FRAME_PROFILE_SAMPLE_COUNT
    bucket.sample_count = min(bucket.sample_count + 1, FRAME_PROFILE_SAMPLE_COUNT)
}

@(private="file")
bucket_snapshot :: proc(bucket: FrameProfileBucket, frames: u64) -> FrameProfileBucketSnapshot {
    avg: f64
    if frames > 0 {
        avg = ns_to_ms(bucket.total_ns) / f64(frames)
    }

    return FrameProfileBucketSnapshot{
        last_ms = ns_to_ms(bucket.last_ns),
        avg_ms = avg,
        max_ms = ns_to_ms(bucket.max_ns),
        p95_ms = percentile_ms(bucket, 0.95),
        p99_ms = percentile_ms(bucket, 0.99),
    }
}

@(private="file")
percentile_ms :: proc(bucket: FrameProfileBucket, percentile: f64) -> f64 {
    if bucket.sample_count <= 0 {
        return 0
    }

    samples := make([]i64, bucket.sample_count, context.temp_allocator)
    for i in 0..<bucket.sample_count {
        samples[i] = bucket.samples[i]
    }

    slice.sort_by(samples, proc(a, b: i64) -> bool {
        return a < b
    })

    index := int(f64(bucket.sample_count) * percentile + 0.999999) - 1
    index = clamp(index, 0, bucket.sample_count - 1)

    return ns_to_ms(samples[index])
}

@(private="file")
ns_to_ms :: proc "contextless" (ns: i64) -> f64 {
    return f64(ns) / 1_000_000
}

@(private="file")
add_render_counters :: proc "contextless" (total: ^FrameProfilerRenderCounters, frame: FrameProfilerRenderCounters) {
    total.layer_items_visited += frame.layer_items_visited
    total.sprites_drawn += frame.sprites_drawn
    total.sprites_skipped += frame.sprites_skipped
    total.draw_shapes_drawn += frame.draw_shapes_drawn
    total.draw_shapes_skipped += frame.draw_shapes_skipped
    total.texts_drawn += frame.texts_drawn
    total.texts_skipped += frame.texts_skipped
    total.text_boxes_drawn += frame.text_boxes_drawn
    total.text_boxes_skipped += frame.text_boxes_skipped
}
