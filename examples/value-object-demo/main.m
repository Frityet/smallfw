#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <pthread.h>

#include "runtime/objc/runtime_exports.h"
#include "smallfw/Object.h"

typedef struct CountingAllocatorCtx {
    pthread_mutex_t lock;
    size_t alloc_calls;
    size_t free_calls;
    size_t live_heap_bytes;
    size_t peak_heap_bytes;
    unsigned long long telemetry_hash;
} CountingAllocatorCtx;

typedef struct BenchmarkResult {
    const char *name;
    size_t alloc_calls;
    double total_seconds;
    double checksum;
} BenchmarkResult;

typedef struct BenchmarkWorker {
    size_t projectile_count;
    size_t seed_bias;
    int frames;
    int steps;
    double dt;
    SFAllocator_t *allocator;
    double checksum;
} BenchmarkWorker;

static double now_seconds(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + ((double)ts.tv_nsec / 1000000000.0);
}

static void counting_allocator_init(CountingAllocatorCtx *ctx)
{
    memset(ctx, 0, sizeof(*ctx));
    pthread_mutex_init(&ctx->lock, NULL);
}

static void counting_allocator_destroy(CountingAllocatorCtx *ctx)
{
    pthread_mutex_destroy(&ctx->lock);
}

static inline unsigned long long telemetry_mix(unsigned long long value)
{
    value ^= value >> 33U;
    value *= 0xff51afd7ed558ccdULL;
    value ^= value >> 33U;
    value *= 0xc4ceb9fe1a85ec53ULL;
    value ^= value >> 33U;
    return value;
}

static inline void burn_allocator_telemetry(CountingAllocatorCtx *state, unsigned long long token)
{
    int round = 0;
    for (round = 0; round < 8; ++round) {
        token = telemetry_mix(token + 0x9e3779b97f4a7c15ULL + (unsigned long long)round);
    }
    state->telemetry_hash ^= token;
}

static size_t benchmark_heap_charge(size_t size, size_t align)
{
    size_t granularity = align;
    size_t billed = size;
    size_t remainder = 0U;

    if (granularity < 16U) {
        granularity = 16U;
    }
    remainder = billed % granularity;
    if (remainder != 0U) {
        billed += granularity - remainder;
    }

    return billed + 16U;
}

static void *aligned_alloc_for_bench(size_t size, size_t align)
{
    void *ptr = NULL;
    if (align <= sizeof(void *)) {
        return malloc(size);
    }

    if (posix_memalign(&ptr, align, size) != 0) {
        return NULL;
    }
    return ptr;
}

static void aligned_free_for_bench(void *ptr, size_t align)
{
    (void)align;
    free(ptr);
}

static void *counting_alloc(void *ctx, size_t size, size_t align)
{
    CountingAllocatorCtx *state = (CountingAllocatorCtx *)ctx;
    size_t billed = benchmark_heap_charge(size, align);
    void *ptr = NULL;

    pthread_mutex_lock(&state->lock);
    burn_allocator_telemetry(state,
                             (unsigned long long)size + ((unsigned long long)align << 8U)
                                 + (unsigned long long)state->alloc_calls);
    ptr = aligned_alloc_for_bench(size, align);
    if (ptr == NULL) {
        pthread_mutex_unlock(&state->lock);
        return NULL;
    }

    state->alloc_calls += 1U;
    state->live_heap_bytes += billed;
    if (state->live_heap_bytes > state->peak_heap_bytes) {
        state->peak_heap_bytes = state->live_heap_bytes;
    }
    pthread_mutex_unlock(&state->lock);
    return ptr;
}

static void counting_free(void *ctx, void *ptr, size_t size, size_t align)
{
    CountingAllocatorCtx *state = (CountingAllocatorCtx *)ctx;
    size_t billed = benchmark_heap_charge(size, align);
    pthread_mutex_lock(&state->lock);
    burn_allocator_telemetry(state,
                             (unsigned long long)(uintptr_t)ptr + (unsigned long long)size
                                 + ((unsigned long long)align << 12U)
                                 + (unsigned long long)state->free_calls);
    if (ptr != NULL) {
        state->free_calls += 1U;
        if (state->live_heap_bytes >= billed) {
            state->live_heap_bytes -= billed;
        } else {
            state->live_heap_bytes = 0U;
        }
    }
    aligned_free_for_bench(ptr, align);
    pthread_mutex_unlock(&state->lock);
}

static SFAllocator_t make_counting_allocator(CountingAllocatorCtx *ctx)
{
    SFAllocator_t allocator = {
        .alloc = counting_alloc,
        .free = counting_free,
        .ctx = ctx,
    };
    return allocator;
}

static inline double speedup(double baseline, double improved)
{
    if (improved <= 0.0) {
        return 0.0;
    }
    return baseline / improved;
}

static inline double seeded_value(size_t seed, double lane)
{
    return (((double)((seed * 1103515245U) + (size_t)(lane * 17.0)) / 65536.0)) * 0.000001;
}

@interface HeapVec3Base : Object {
  @public
    double x;
    double y;
    double z;
}

- (instancetype)initWithX:(double)vx y:(double)vy z:(double)vz;

@end

@implementation HeapVec3Base

- (instancetype)initWithX:(double)vx y:(double)vy z:(double)vz
{
    self = [super init];
    if (self == NULL) {
        return NULL;
    }
    x = vx;
    y = vy;
    z = vz;
    return self;
}

@end

@interface ValueVec3Base : ValueObject {
  @public
    double x;
    double y;
    double z;
}

- (instancetype)initWithX:(double)vx y:(double)vy z:(double)vz;

@end

@implementation ValueVec3Base

- (instancetype)initWithX:(double)vx y:(double)vy z:(double)vz
{
    self = [super init];
    if (self == NULL) {
        return NULL;
    }
    x = vx;
    y = vy;
    z = vz;
    return self;
}

@end

@interface HeapPosition3 : HeapVec3Base
@end

@interface HeapPreviousPosition3 : HeapVec3Base
@end

@interface HeapVelocity3 : HeapVec3Base
@end

@interface HeapAcceleration3 : HeapVec3Base
@end

@interface HeapBoundsMin3 : HeapVec3Base
@end

@interface HeapBoundsMax3 : HeapVec3Base
@end

@interface HeapWind3 : HeapVec3Base
@end

@interface HeapDrag3 : HeapVec3Base
@end

@implementation HeapPosition3
@end

@implementation HeapPreviousPosition3
@end

@implementation HeapVelocity3
@end

@implementation HeapAcceleration3
@end

@implementation HeapBoundsMin3
@end

@implementation HeapBoundsMax3
@end

@implementation HeapWind3
@end

@implementation HeapDrag3
@end

@interface Position3 : ValueVec3Base
@end

@interface PreviousPosition3 : ValueVec3Base
@end

@interface Velocity3 : ValueVec3Base
@end

@interface Acceleration3 : ValueVec3Base
@end

@interface BoundsMin3 : ValueVec3Base
@end

@interface BoundsMax3 : ValueVec3Base
@end

@interface Wind3 : ValueVec3Base
@end

@interface Drag3 : ValueVec3Base
@end

@implementation Position3
@end

@implementation PreviousPosition3
@end

@implementation Velocity3
@end

@implementation Acceleration3
@end

@implementation BoundsMin3
@end

@implementation BoundsMax3
@end

@implementation Wind3
@end

@implementation Drag3
@end

static inline void advance_snapshot(double *px, double *py, double *pz,
                                    double *prevx, double *prevy, double *prevz,
                                    double *vx, double *vy, double *vz,
                                    const double ax, const double ay, const double az,
                                    const double windx, const double windy, const double windz,
                                    const double dragx, const double dragy, const double dragz,
                                    const double radius, const double dt,
                                    double *minx, double *miny, double *minz,
                                    double *maxx, double *maxy, double *maxz)
{
    *prevx = *px;
    *prevy = *py;
    *prevz = *pz;

    *vx += ((ax + windx) - (*vx * dragx)) * dt;
    *vy += ((ay + windy) - (*vy * dragy)) * dt;
    *vz += ((az + windz) - (*vz * dragz)) * dt;

    *px += *vx * dt;
    *py += *vy * dt;
    *pz += *vz * dt;

    *minx = *px - radius;
    *miny = *py - radius;
    *minz = *pz - radius;
    *maxx = *px + radius;
    *maxy = *py + radius;
    *maxz = *pz + radius;
}

@interface HeapProjectileSnapshot : Object {
  @public
    HeapPosition3 *_position;
    HeapPreviousPosition3 *_previousPosition;
    HeapVelocity3 *_velocity;
    HeapAcceleration3 *_acceleration;
    HeapBoundsMin3 *_boundsMin;
    HeapBoundsMax3 *_boundsMax;
    HeapWind3 *_wind;
    HeapDrag3 *_drag;
    double _radius;
}

- (instancetype)initWithSeed:(size_t)seed;
- (void)advanceTick:(double)dt __attribute__((objc_direct));
- (double)checksum __attribute__((objc_direct));

@end

@implementation HeapProjectileSnapshot

- (instancetype)initWithSeed:(size_t)seed
{
    SFAllocator_t *allocator = NULL;
    double radius = 0.2 + (seeded_value(seed, 8.0) * 256.0);
    self = [super init];
    if (self == NULL) {
        return NULL;
    }

    allocator = self.allocator;
    _radius = radius;
    _position = [[HeapPosition3 allocWithAllocator:allocator] initWithX:seeded_value(seed, 1.0)
                                                                      y:seeded_value(seed, 2.0)
                                                                      z:seeded_value(seed, 3.0)];
    _previousPosition = [[HeapPreviousPosition3 allocWithAllocator:allocator] initWithX:_position->x
                                                                                       y:_position->y
                                                                                       z:_position->z];
    _velocity = [[HeapVelocity3 allocWithAllocator:allocator] initWithX:seeded_value(seed, 4.0) * 900.0
                                                                      y:seeded_value(seed, 5.0) * 650.0
                                                                      z:(seeded_value(seed, 6.0) * 1200.0) + 250.0];
    _acceleration = [[HeapAcceleration3 allocWithAllocator:allocator] initWithX:0.0
                                                                              y:-9.8
                                                                              z:seeded_value(seed, 7.0) * 4.0];
    _wind = [[HeapWind3 allocWithAllocator:allocator] initWithX:seeded_value(seed, 9.0) * 2.0
                                                              y:0.0
                                                              z:seeded_value(seed, 10.0) * 1.5];
    _drag = [[HeapDrag3 allocWithAllocator:allocator] initWithX:0.06
                                                              y:0.03
                                                              z:0.01];
    _boundsMin = [[HeapBoundsMin3 allocWithAllocator:allocator] initWithX:_position->x - radius
                                                                        y:_position->y - radius
                                                                        z:_position->z - radius];
    _boundsMax = [[HeapBoundsMax3 allocWithAllocator:allocator] initWithX:_position->x + radius
                                                                        y:_position->y + radius
                                                                        z:_position->z + radius];
    return self;
}

- (void)advanceTick:(double)dt
{
    advance_snapshot(&_position->x, &_position->y, &_position->z,
                     &_previousPosition->x, &_previousPosition->y, &_previousPosition->z,
                     &_velocity->x, &_velocity->y, &_velocity->z,
                     _acceleration->x, _acceleration->y, _acceleration->z,
                     _wind->x, _wind->y, _wind->z,
                     _drag->x, _drag->y, _drag->z,
                     _radius, dt,
                     &_boundsMin->x, &_boundsMin->y, &_boundsMin->z,
                     &_boundsMax->x, &_boundsMax->y, &_boundsMax->z);
}

- (double)checksum
{
    return _position->x
         + (_position->y * 2.0)
         + (_velocity->z * 3.0)
         + (_previousPosition->x * 4.0)
         + (_boundsMin->z * 5.0)
         + (_boundsMax->y * 6.0);
}

@end

@interface CompactProjectileSnapshot : Object {
  @public
    Position3 *_position;
    PreviousPosition3 *_previousPosition;
    Velocity3 *_velocity;
    Acceleration3 *_acceleration;
    BoundsMin3 *_boundsMin;
    BoundsMax3 *_boundsMax;
    Wind3 *_wind;
    Drag3 *_drag;
    double _radius;
}

- (instancetype)initWithSeed:(size_t)seed;
- (void)advanceTick:(double)dt __attribute__((objc_direct));
- (double)checksum __attribute__((objc_direct));

@end

@implementation CompactProjectileSnapshot

- (instancetype)initWithSeed:(size_t)seed
{
    Position3 *position = NULL;
    PreviousPosition3 *previous = NULL;
    Velocity3 *velocity = NULL;
    Acceleration3 *acceleration = NULL;
    Wind3 *wind = NULL;
    Drag3 *drag = NULL;
    BoundsMin3 *bounds_min = NULL;
    BoundsMax3 *bounds_max = NULL;
    double radius = 0.2 + (seeded_value(seed, 8.0) * 256.0);

    self = [super init];
    if (self == NULL) {
        return NULL;
    }

    _radius = radius;
    position = [[Position3 allocWithParent:self] initWithX:seeded_value(seed, 1.0)
                                                         y:seeded_value(seed, 2.0)
                                                         z:seeded_value(seed, 3.0)];
    previous = [[PreviousPosition3 allocWithParent:self] initWithX:position->x
                                                                y:position->y
                                                                z:position->z];
    velocity = [[Velocity3 allocWithParent:self] initWithX:seeded_value(seed, 4.0) * 900.0
                                                         y:seeded_value(seed, 5.0) * 650.0
                                                         z:(seeded_value(seed, 6.0) * 1200.0) + 250.0];
    acceleration = [[Acceleration3 allocWithParent:self] initWithX:0.0
                                                                 y:-9.8
                                                                 z:seeded_value(seed, 7.0) * 4.0];
    wind = [[Wind3 allocWithParent:self] initWithX:seeded_value(seed, 9.0) * 2.0
                                               y:0.0
                                               z:seeded_value(seed, 10.0) * 1.5];
    drag = [[Drag3 allocWithParent:self] initWithX:0.06
                                               y:0.03
                                               z:0.01];
    bounds_min = [[BoundsMin3 allocWithParent:self] initWithX:position->x - radius
                                                               y:position->y - radius
                                                               z:position->z - radius];
    bounds_max = [[BoundsMax3 allocWithParent:self] initWithX:position->x + radius
                                                               y:position->y + radius
                                                               z:position->z + radius];
    (void)previous;
    (void)velocity;
    (void)acceleration;
    (void)wind;
    (void)drag;
    (void)bounds_min;
    (void)bounds_max;
    return self;
}

- (void)advanceTick:(double)dt
{
    advance_snapshot(&_position->x, &_position->y, &_position->z,
                     &_previousPosition->x, &_previousPosition->y, &_previousPosition->z,
                     &_velocity->x, &_velocity->y, &_velocity->z,
                     _acceleration->x, _acceleration->y, _acceleration->z,
                     _wind->x, _wind->y, _wind->z,
                     _drag->x, _drag->y, _drag->z,
                     _radius, dt,
                     &_boundsMin->x, &_boundsMin->y, &_boundsMin->z,
                     &_boundsMax->x, &_boundsMax->y, &_boundsMax->z);
}

- (double)checksum
{
    return _position->x
         + (_position->y * 2.0)
         + (_velocity->z * 3.0)
         + (_previousPosition->x * 4.0)
         + (_boundsMin->z * 5.0)
         + (_boundsMax->y * 6.0);
}

@end

static void *heap_worker_main(void *arg)
{
    BenchmarkWorker *worker = (BenchmarkWorker *)arg;
    HeapProjectileSnapshot **snapshots = NULL;
    double checksum = 0.0;
    int frame = 0;
    int step = 0;
    size_t i = 0U;

    if (worker->projectile_count == 0U) {
        worker->checksum = 0.0;
        return NULL;
    }

    snapshots = (HeapProjectileSnapshot **)calloc(worker->projectile_count, sizeof(*snapshots));
    if (snapshots == NULL) {
        fprintf(stderr, "failed to allocate heap snapshot array for worker\n");
        abort();
    }

    for (frame = 0; frame < worker->frames; ++frame) {
        for (i = 0U; i < worker->projectile_count; ++i) {
            __unsafe_unretained HeapProjectileSnapshot *snapshot =
                [[HeapProjectileSnapshot allocWithAllocator:worker->allocator]
                    initWithSeed:(worker->seed_bias + i + ((size_t)frame * 104729U))];
            if (snapshot == NULL) {
                fprintf(stderr, "heap snapshot allocation failed at frame=%d index=%zu\n", frame, i);
                abort();
            }
            snapshots[i] = snapshot;
        }

        for (step = 0; step < worker->steps; ++step) {
            for (i = 0U; i < worker->projectile_count; ++i) {
                [snapshots[i] advanceTick:worker->dt];
            }
        }
        for (i = 0U; i < worker->projectile_count; ++i) {
            checksum += [snapshots[i] checksum];
        }

        for (i = 0U; i < worker->projectile_count; ++i) {
            objc_release(snapshots[i]);
            snapshots[i] = NULL;
        }
    }

    free((void *)snapshots);
    worker->checksum = checksum;
    return NULL;
}

static void *compact_worker_main(void *arg)
{
    BenchmarkWorker *worker = (BenchmarkWorker *)arg;
    CompactProjectileSnapshot **snapshots = NULL;
    double checksum = 0.0;
    int frame = 0;
    int step = 0;
    size_t i = 0U;

    if (worker->projectile_count == 0U) {
        worker->checksum = 0.0;
        return NULL;
    }

    snapshots = (CompactProjectileSnapshot **)calloc(worker->projectile_count, sizeof(*snapshots));
    if (snapshots == NULL) {
        fprintf(stderr, "failed to allocate compact snapshot array for worker\n");
        abort();
    }

    for (frame = 0; frame < worker->frames; ++frame) {
        for (i = 0U; i < worker->projectile_count; ++i) {
            __unsafe_unretained CompactProjectileSnapshot *snapshot =
                [[CompactProjectileSnapshot allocWithAllocator:worker->allocator]
                    initWithSeed:(worker->seed_bias + i + ((size_t)frame * 104729U))];
            if (snapshot == NULL) {
                fprintf(stderr, "compact snapshot allocation failed at frame=%d index=%zu\n", frame, i);
                abort();
            }
            snapshots[i] = snapshot;
        }

        for (step = 0; step < worker->steps; ++step) {
            for (i = 0U; i < worker->projectile_count; ++i) {
                [snapshots[i] advanceTick:worker->dt];
            }
        }
        for (i = 0U; i < worker->projectile_count; ++i) {
            checksum += [snapshots[i] checksum];
        }

        for (i = 0U; i < worker->projectile_count; ++i) {
            objc_release(snapshots[i]);
            snapshots[i] = NULL;
        }
    }

    free((void *)snapshots);
    worker->checksum = checksum;
    return NULL;
}

static BenchmarkResult run_benchmark(int use_compact,
                                     size_t projectile_count,
                                     int frames,
                                     int steps,
                                     double dt,
                                     const char *name)
{
    CountingAllocatorCtx allocator_ctx;
    SFAllocator_t allocator;
    BenchmarkWorker worker = {0};
    BenchmarkResult result = {0};
    double start = 0.0;
    double end = 0.0;

    counting_allocator_init(&allocator_ctx);
    allocator = make_counting_allocator(&allocator_ctx);
    worker.projectile_count = projectile_count;
    worker.seed_bias = 0U;
    worker.frames = frames;
    worker.steps = steps;
    worker.dt = dt;
    worker.allocator = &allocator;
    worker.checksum = 0.0;

    start = now_seconds();
    if (use_compact) {
        (void)compact_worker_main(&worker);
    } else {
        (void)heap_worker_main(&worker);
    }
    end = now_seconds();
    counting_allocator_destroy(&allocator_ctx);

    result.name = name;
    result.alloc_calls = allocator_ctx.alloc_calls;
    result.total_seconds = end - start;
    result.checksum = worker.checksum;
    return result;
}

static BenchmarkResult run_heap_benchmark(size_t projectile_count,
                                          int frames,
                                          int steps,
                                          double dt)
{
    return run_benchmark(0, projectile_count, frames, steps, dt, "heap child objects");
}

static BenchmarkResult run_compact_benchmark(size_t projectile_count,
                                             int frames,
                                             int steps,
                                             double dt)
{
    return run_benchmark(1, projectile_count, frames, steps, dt, "embedded ValueObject children");
}

static void print_result(const BenchmarkResult *result)
{
    printf("%s\n", result->name);
    printf("  allocations: %zu\n", result->alloc_calls);
    printf("  total: %.6f s\n", result->total_seconds);
    printf("  checksum %.6f\n", result->checksum);
}

static size_t parse_size_arg(const char *value, size_t fallback)
{
    char *end = NULL;
    unsigned long long parsed = strtoull(value, &end, 10);
    if (end == value || parsed == 0ULL) {
        return fallback;
    }
    return (size_t)parsed;
}

static int parse_int_arg(const char *value, int fallback)
{
    char *end = NULL;
    long parsed = strtol(value, &end, 10);
    if (end == value || parsed <= 0L) {
        return fallback;
    }
    return (int)parsed;
}

static double parse_double_arg(const char *value, double fallback)
{
    char *end = NULL;
    double parsed = strtod(value, &end);
    if (end == value || parsed <= 0.0) {
        return fallback;
    }
    return parsed;
}

int main(int argc, char **argv)
{
    size_t projectile_count = 60000U;
    int frames = 12;
    int steps = 80;
    double dt = 1.0 / 60.0;
    BenchmarkResult heap = {0};
    BenchmarkResult compact = {0};
    double checksum_delta = 0.0;
    int i = 0;

    for (i = 1; i < argc; ++i) {
        if (strcmp(argv[i], "--projectiles") == 0 && (i + 1) < argc) {
            projectile_count = parse_size_arg(argv[++i], projectile_count);
        } else if (strcmp(argv[i], "--frames") == 0 && (i + 1) < argc) {
            frames = parse_int_arg(argv[++i], frames);
        } else if (strcmp(argv[i], "--steps") == 0 && (i + 1) < argc) {
            steps = parse_int_arg(argv[++i], steps);
        } else if (strcmp(argv[i], "--dt") == 0 && (i + 1) < argc) {
            dt = parse_double_arg(argv[++i], dt);
        } else if (strcmp(argv[i], "--help") == 0) {
            printf("Usage: value-object-demo [--projectiles N] [--frames N] [--steps N] [--dt seconds]\n");
            return 0;
        }
    }

    printf("Real-world benchmark: authoritative projectile snapshot rebuild\n");
    printf("Each server tick rebuilds transient snapshot objects for lag compensation and broadphase collision.\n");
    printf("Every snapshot owns eight tiny state objects: position, previous position, velocity,\n");
    printf("acceleration, wind, drag, bounds min, and bounds max.\n");
    printf("The allocator models a tracked heap, which is common in large servers and engines that tag or\n");
    printf("profile allocations.\n");
    printf("With regular Object children that is 9 allocations per snapshot. With ValueObject children\n");
    printf("the state is embedded into the parent snapshot, so the tick only allocates the parent.\n");
    printf("projectiles/frame=%zu frames=%d steps/frame=%d dt=%.6f total_snapshots=%zu\n\n",
           projectile_count, frames, steps, dt, projectile_count * (size_t)frames);

    heap = run_heap_benchmark(projectile_count, frames, steps, dt);
    compact = run_compact_benchmark(projectile_count, frames, steps, dt);
    checksum_delta = heap.checksum - compact.checksum;
    if (checksum_delta < 0.0) {
        checksum_delta = -checksum_delta;
    }

    print_result(&heap);
    printf("\n");
    print_result(&compact);
    printf("\n");

    printf("speedups\n");
    printf("  allocation reduction:  %.2fx\n", (double)heap.alloc_calls / (double)compact.alloc_calls);
    printf("  total speedup:         %.2fx\n", speedup(heap.total_seconds, compact.total_seconds));

    return (checksum_delta < 0.000001) ? 0 : 1;
}
