#include "runtime/internal.h"

#include <stdlib.h>

#if SF_RUNTIME_COMPACT_HEADERS
static uintptr_t sf_inline_value_tagged_parent(id parent)
{
    return ((uintptr_t)parent) | (uintptr_t)1U;
}

int sf_header_is_inline_value_prefix(SFObjHeader_t *hdr)
{
#if SF_RUNTIME_INLINE_VALUE_STORAGE
    SFInlineValueHeader_t *inline_hdr = (SFInlineValueHeader_t *)(void *)hdr;
    return hdr != NULL and
           (inline_hdr->flags & SF_OBJ_FLAG_INLINE_VALUE) != 0U and
           (inline_hdr->tagged_parent & (uintptr_t)1U) != 0U;
#else
    (void)hdr;
    return 0;
#endif
}

id sf_header_object(SFObjHeader_t *hdr)
{
    if (hdr == NULL) {
        return NULL;
    }
#if SF_RUNTIME_COMPACT_HEADERS && SF_RUNTIME_INLINE_VALUE_STORAGE
    if (sf_header_is_inline_value_prefix(hdr)) {
        return (id)(void *)((unsigned char *)(void *)hdr + sizeof(SFInlineValueHeader_t));
    }
#endif
    return (id)(void *)(hdr + 1);
}

static id sf_inline_value_parent(SFObjHeader_t *hdr)
{
#if SF_RUNTIME_INLINE_VALUE_STORAGE
    SFInlineValueHeader_t *inline_hdr = (SFInlineValueHeader_t *)(void *)hdr;
    return (id)(void *)(inline_hdr->tagged_parent & ~(uintptr_t)1U);
#else
    (void)hdr;
    return NULL;
#endif
}

static SFObjColdState_t *sf_header_cold_state(SFObjHeader_t *hdr)
{
    if (sf_header_is_inline_value_prefix(hdr)) {
        return NULL;
    }
    return (hdr != NULL and (hdr->flags & SF_OBJ_FLAG_HAS_COLD) != 0U) ? hdr->cold : NULL;
}

static SFObjColdState_t *sf_header_ensure_cold_state(SFObjHeader_t *hdr)
{
    SFObjColdState_t *cold = NULL;

    if (hdr == NULL) {
        return NULL;
    }
    if (sf_header_is_inline_value_prefix(hdr)) {
        return NULL;
    }
    cold = sf_header_cold_state(hdr);
    if (cold != NULL) {
        return cold;
    }
    cold = (SFObjColdState_t *)sf_runtime_test_calloc(1U, sizeof(*cold));
    if (cold == NULL) {
        return NULL;
    }
    hdr->cold = cold;
    hdr->flags |= SF_OBJ_FLAG_HAS_COLD;
    return cold;
}

static SFAllocator_t *sf_header_allocator_local(SFObjHeader_t *hdr)
{
    if (sf_header_is_inline_value_prefix(hdr)) {
        SFObjHeader_t *parent_hdr = sf_header_from_object(sf_inline_value_parent(hdr));
        SFAllocator_t *allocator = sf_header_allocator(parent_hdr);
        return allocator != NULL ? allocator : sf_default_allocator();
    }
    SFObjColdState_t *cold = sf_header_cold_state(hdr);
    return cold != NULL ? cold->allocator : NULL;
}

static int sf_header_set_allocator_local(SFObjHeader_t *hdr, SFAllocator_t *allocator)
{
    SFObjColdState_t *cold = NULL;
    SFAllocator_t *default_allocator = sf_default_allocator();

    if (hdr == NULL) {
        return 0;
    }
    if (sf_header_is_inline_value_prefix(hdr)) {
        SFAllocator_t *current = sf_header_allocator_local(hdr);
        return allocator == NULL or allocator == current;
    }
    if (allocator == NULL or allocator == default_allocator) {
        cold = sf_header_cold_state(hdr);
        if (cold != NULL) {
            cold->allocator = NULL;
        }
        return 1;
    }
    cold = sf_header_ensure_cold_state(hdr);
    if (cold == NULL) {
        return 0;
    }
    cold->allocator = allocator;
    return 1;
}

static id sf_header_parent_local(SFObjHeader_t *hdr)
{
    if (sf_header_is_inline_value_prefix(hdr)) {
        return sf_inline_value_parent(hdr);
    }
    SFObjColdState_t *cold = sf_header_cold_state(hdr);
    return cold != NULL ? cold->parent : NULL;
}

static int sf_header_set_parent_local(SFObjHeader_t *hdr, id parent)
{
    SFObjColdState_t *cold = NULL;

    if (hdr == NULL) {
        return 0;
    }
    if (sf_header_is_inline_value_prefix(hdr)) {
        SFInlineValueHeader_t *inline_hdr = (SFInlineValueHeader_t *)(void *)hdr;
        inline_hdr->tagged_parent = sf_inline_value_tagged_parent(parent);
        return 1;
    }
    cold = (parent != NULL) ? sf_header_ensure_cold_state(hdr) : sf_header_cold_state(hdr);
    if (parent != NULL and cold == NULL) {
        return 0;
    }
    if (cold != NULL) {
        cold->parent = parent;
    }
    return 1;
}

static SFObjHeader_t *sf_header_group_root_local(SFObjHeader_t *hdr)
{
    if (sf_header_is_inline_value_prefix(hdr)) {
        return hdr;
    }
    SFObjColdState_t *cold = sf_header_cold_state(hdr);
    return (cold != NULL and cold->group_root != NULL) ? cold->group_root : hdr;
}

static SFObjHeader_t *sf_header_group_next_local(SFObjHeader_t *hdr)
{
    if (sf_header_is_inline_value_prefix(hdr)) {
        return NULL;
    }
    SFObjColdState_t *cold = sf_header_cold_state(hdr);
    return cold != NULL ? cold->group_next : NULL;
}

static int sf_header_set_group_next_local(SFObjHeader_t *hdr, SFObjHeader_t *group_next)
{
    SFObjColdState_t *cold = NULL;

    if (hdr == NULL) {
        return 0;
    }
    if (sf_header_is_inline_value_prefix(hdr)) {
        return group_next == NULL;
    }
    cold = (group_next != NULL) ? sf_header_ensure_cold_state(hdr) : sf_header_cold_state(hdr);
    if (group_next != NULL and cold == NULL) {
        return 0;
    }
    if (cold != NULL) {
        cold->group_next = group_next;
    }
    return 1;
}

#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
static SFGroupState_t *sf_header_group_state_local(SFObjHeader_t *hdr)
{
    SFObjHeader_t *root = sf_header_group_root_local(hdr);
    SFObjColdState_t *cold = sf_header_cold_state(root);
    return cold != NULL ? cold->group : NULL;
}

static int sf_header_set_group_state_local(SFObjHeader_t *root, SFGroupState_t *group)
{
    SFObjColdState_t *cold = NULL;

    if (root == NULL) {
        return 0;
    }
    cold = (group != NULL) ? sf_header_ensure_cold_state(root) : sf_header_cold_state(root);
    if (group != NULL and cold == NULL) {
        return 0;
    }
    if (cold != NULL) {
        cold->group = group;
    }
    return 1;
}
#else
static SFObjColdState_t *sf_header_inline_group_root_cold(SFObjHeader_t *hdr)
{
    return sf_header_cold_state(sf_header_group_root_local(hdr));
}
#endif
#else
int sf_header_is_inline_value_prefix(SFObjHeader_t *hdr)
{
    (void)hdr;
    return 0;
}

id sf_header_object(SFObjHeader_t *hdr)
{
    return hdr != NULL ? (id)(void *)(hdr + 1) : NULL;
}

#if SF_RUNTIME_THREADSAFE
static SFGroupState_t *sf_header_group_state_atomic(SFObjHeader_t *hdr)
{
    return hdr != NULL ? __atomic_load_n(&hdr->group, __ATOMIC_ACQUIRE) : NULL;
}

static void sf_header_set_group_state_atomic(SFObjHeader_t *hdr, SFGroupState_t *group)
{
    if (hdr != NULL) {
        __atomic_store_n(&hdr->group, group, __ATOMIC_RELEASE);
    }
}

static SFGroupState_t *sf_header_exchange_group_state_atomic(SFObjHeader_t *hdr, SFGroupState_t *group)
{
    return hdr != NULL ? __atomic_exchange_n(&hdr->group, group, __ATOMIC_ACQ_REL) : NULL;
}

static int sf_header_try_set_group_state_atomic(SFObjHeader_t *hdr, SFGroupState_t *group)
{
    SFGroupState_t *expected = NULL;

    if (hdr == NULL) {
        return 0;
    }
    return __atomic_compare_exchange_n(&hdr->group, &expected, group, 0, __ATOMIC_RELEASE,
                                       __ATOMIC_ACQUIRE);
}
#else
static SFGroupState_t *sf_header_group_state_atomic(SFObjHeader_t *hdr)
{
    return hdr != NULL ? hdr->group : NULL;
}

static void sf_header_set_group_state_atomic(SFObjHeader_t *hdr, SFGroupState_t *group)
{
    if (hdr != NULL) {
        hdr->group = group;
    }
}

static SFGroupState_t *sf_header_exchange_group_state_atomic(SFObjHeader_t *hdr, SFGroupState_t *group)
{
    SFGroupState_t *old = NULL;

    if (hdr == NULL) {
        return NULL;
    }
    old = hdr->group;
    hdr->group = group;
    return old;
}

static int sf_header_try_set_group_state_atomic(SFObjHeader_t *hdr, SFGroupState_t *group)
{
    if (hdr == NULL or hdr->group != NULL) {
        return 0;
    }
    hdr->group = group;
    return 1;
}
#endif
#endif

static SFGroupState_t *sf_create_group_state(SFObjHeader_t *root)
{
    SFGroupState_t *group = (SFGroupState_t *)sf_runtime_test_calloc(1, sizeof(*group));
    if (group == NULL) {
        return NULL;
    }
    group->root = root;
    group->head = root;
    group->group_live_count = 1U;
    group->dead = 0U;
    sf_runtime_mutex_init(&group->group_lock);
    return group;
}

SFObjHeader_t *sf_header_live_next(SFObjHeader_t *hdr)
{
#if SF_RUNTIME_COMPACT_HEADERS
    if (sf_header_is_inline_value_prefix(hdr)) {
        return NULL;
    }
#if SF_RUNTIME_VALIDATION
    SFObjColdState_t *cold = sf_header_cold_state(hdr);
    return cold != NULL ? cold->live_next : NULL;
#else
    (void)hdr;
    return NULL;
#endif
#else
#if SF_RUNTIME_VALIDATION
    return hdr != NULL ? hdr->live_next : NULL;
#else
    (void)hdr;
    return NULL;
#endif
#endif
}

void sf_header_set_live_next(SFObjHeader_t *hdr, SFObjHeader_t *next)
{
#if SF_RUNTIME_COMPACT_HEADERS
    if (sf_header_is_inline_value_prefix(hdr)) {
        (void)next;
        return;
    }
#if SF_RUNTIME_VALIDATION
    SFObjColdState_t *cold = (next != NULL) ? sf_header_ensure_cold_state(hdr) : sf_header_cold_state(hdr);
    if (cold != NULL) {
        cold->live_next = next;
    }
#else
    (void)hdr;
    (void)next;
#endif
#else
#if SF_RUNTIME_VALIDATION
    if (hdr != NULL) {
        hdr->live_next = next;
    }
#else
    (void)hdr;
    (void)next;
#endif
#endif
}

SFAllocator_t *sf_header_allocator(SFObjHeader_t *hdr)
{
    if (hdr == NULL) {
        return NULL;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return sf_header_allocator_local(hdr);
#else
    return hdr->allocator;
#endif
}

int sf_header_set_allocator(SFObjHeader_t *hdr, SFAllocator_t *allocator)
{
    if (hdr == NULL) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return sf_header_set_allocator_local(hdr, allocator);
#else
    hdr->allocator = allocator;
    return 1;
#endif
}

id sf_header_parent(SFObjHeader_t *hdr)
{
    if (hdr == NULL) {
        return NULL;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return sf_header_parent_local(hdr);
#else
    return hdr->parent;
#endif
}

int sf_header_set_parent(SFObjHeader_t *hdr, id parent)
{
    if (hdr == NULL) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return sf_header_set_parent_local(hdr, parent);
#else
    hdr->parent = parent;
    return 1;
#endif
}

SFObjHeader_t *sf_header_group_root(SFObjHeader_t *hdr)
{
    if (hdr == NULL) {
        return NULL;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return sf_header_group_root_local(hdr);
#else
    SFGroupState_t *group = sf_header_group_state_atomic(hdr);
    if (group != NULL and group->root != NULL) {
        return group->root;
    }
    return hdr;
#endif
}

int sf_header_set_group_root(SFObjHeader_t *hdr, SFObjHeader_t *group_root)
{
    if (hdr == NULL) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    if (sf_header_is_inline_value_prefix(hdr)) {
        return group_root == NULL or group_root == hdr;
    }
    if (group_root == NULL) {
        SFObjColdState_t *cold = sf_header_cold_state(hdr);
        if (cold != NULL) {
            cold->group_root = NULL;
        }
        return 1;
    }
    if (not sf_header_init_group_root(group_root)) {
        return 0;
    }
    if (hdr == group_root) {
        SFObjColdState_t *cold = sf_header_cold_state(hdr);
        if (cold != NULL) {
            cold->group_root = NULL;
        }
        return 1;
    }
    SFObjColdState_t *cold = sf_header_ensure_cold_state(hdr);
    if (cold == NULL) {
        return 0;
    }
    cold->group_root = group_root;
    return 1;
#else
    if (group_root == NULL) {
        sf_header_set_group_state_atomic(hdr, NULL);
        return 1;
    }
    if (not sf_header_init_group_root(group_root)) {
        return 0;
    }
    sf_header_set_group_state_atomic(hdr, sf_header_group_state_atomic(group_root));
    return sf_header_group_state_atomic(hdr) != NULL;
#endif
}

SFObjHeader_t *sf_header_group_next(SFObjHeader_t *hdr)
{
    if (hdr == NULL) {
        return NULL;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return sf_header_group_next_local(hdr);
#else
    return hdr->group_next;
#endif
}

int sf_header_set_group_next(SFObjHeader_t *hdr, SFObjHeader_t *group_next)
{
    if (hdr == NULL) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return sf_header_set_group_next_local(hdr, group_next);
#else
    hdr->group_next = group_next;
    return 1;
#endif
}

SFObjHeader_t *sf_header_group_head(SFObjHeader_t *hdr)
{
    if (hdr == NULL) {
        return NULL;
    }
#if SF_RUNTIME_COMPACT_HEADERS
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    SFGroupState_t *group = sf_header_group_state_local(hdr);
    if (group != NULL and group->head != NULL) {
        return group->head;
    }
#else
    SFObjColdState_t *cold = sf_header_inline_group_root_cold(hdr);
    if (cold != NULL and cold->inline_group_head != NULL) {
        return cold->inline_group_head;
    }
#endif
    return sf_header_group_root_local(hdr);
#else
    SFGroupState_t *group = sf_header_group_state_atomic(hdr);
    if (group != NULL and group->head != NULL) {
        return group->head;
    }
    return hdr;
#endif
}

int sf_header_set_group_head(SFObjHeader_t *hdr, SFObjHeader_t *group_head)
{
    SFObjHeader_t *root = sf_header_group_root(hdr);
    if (root == NULL) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    if (group_head == NULL and sf_header_group_state_local(root) == NULL) {
        return 1;
    }
    if (not sf_header_init_group_root(root)) {
        return 0;
    }
    SFGroupState_t *group = sf_header_group_state_local(root);
    if (group == NULL) {
        return 0;
    }
    group->head = group_head;
    return 1;
#else
    if (group_head == NULL) {
        SFObjColdState_t *cold = sf_header_cold_state(root);
        if (cold == NULL) {
            return 1;
        }
        cold->inline_group_head = NULL;
        return 1;
    }
    if (not sf_header_init_group_root(root)) {
        return 0;
    }
    SFObjColdState_t *cold = sf_header_inline_group_root_cold(root);
    if (cold == NULL) {
        return 0;
    }
    cold->inline_group_head = group_head;
    return 1;
#endif
#else
    SFGroupState_t *group = NULL;

    if (group_head == NULL and sf_header_group_state_atomic(root) == NULL) {
        return 1;
    }
    if (not sf_header_init_group_root(root)) {
        return 0;
    }
    group = sf_header_group_state_atomic(root);
    if (group == NULL) {
        return 0;
    }
    group->head = group_head;
    return 1;
#endif
}

size_t sf_header_group_live_count(SFObjHeader_t *hdr)
{
    if (hdr == NULL) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    SFGroupState_t *group = sf_header_group_state_local(hdr);
    if (group != NULL) {
        return group->group_live_count;
    }
#else
    SFObjColdState_t *cold = sf_header_inline_group_root_cold(hdr);
    if (cold != NULL and cold->inline_group_live_count != 0U) {
        return cold->inline_group_live_count;
    }
#endif
    return (hdr->state == SF_OBJ_STATE_LIVE) ? (size_t)1 : (size_t)0;
#else
    SFGroupState_t *group = sf_header_group_state_atomic(hdr);
    if (group != NULL) {
        return group->group_live_count;
    }
    return (hdr->state == SF_OBJ_STATE_LIVE) ? (size_t)1 : (size_t)0;
#endif
}

int sf_header_set_group_live_count(SFObjHeader_t *hdr, size_t count)
{
    SFObjHeader_t *root = sf_header_group_root(hdr);
    if (root == NULL) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    if (count <= (size_t)1 and sf_header_group_state_local(root) == NULL) {
        return 1;
    }
    if (not sf_header_init_group_root(root)) {
        return 0;
    }
    SFGroupState_t *group = sf_header_group_state_local(root);
    if (group == NULL) {
        return 0;
    }
    group->group_live_count = count;
    group->dead = (count == 0) ? 1U : 0U;
    return 1;
#else
    if (count <= (size_t)1) {
        SFObjColdState_t *cold = sf_header_cold_state(root);
        if (cold == NULL) {
            return 1;
        }
        cold->inline_group_live_count = count;
        cold->inline_group_dead = (count == 0) ? 1U : 0U;
        if (count != 0U and cold->inline_group_head == NULL) {
            cold->inline_group_head = root;
        }
        return 1;
    }
    if (not sf_header_init_group_root(root)) {
        return 0;
    }
    SFObjColdState_t *cold = sf_header_inline_group_root_cold(root);
    if (cold == NULL) {
        return 0;
    }
    cold->inline_group_live_count = count;
    cold->inline_group_dead = (count == 0) ? 1U : 0U;
    return 1;
#endif
#else
    SFGroupState_t *group = NULL;

    if (count <= (size_t)1 and sf_header_group_state_atomic(root) == NULL) {
        return 1;
    }
    if (not sf_header_init_group_root(root)) {
        return 0;
    }
    group = sf_header_group_state_atomic(root);
    if (group == NULL) {
        return 0;
    }
    group->group_live_count = count;
    group->dead = (count == 0) ? 1U : 0U;
    return 1;
#endif
}

int sf_header_group_dead(SFObjHeader_t *hdr)
{
    SFObjHeader_t *root = sf_header_group_root(hdr);

    if (root == NULL) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    SFGroupState_t *group = sf_header_group_state_local(root);
    return group != NULL and group->dead != 0U;
#else
    SFObjColdState_t *cold = sf_header_inline_group_root_cold(root);
    return cold != NULL and cold->inline_group_dead != 0U;
#endif
#else
    SFGroupState_t *group = sf_header_group_state_atomic(root);
    return group != NULL and group->dead != 0U;
#endif
}

int sf_header_grouped(SFObjHeader_t *hdr)
{
    if (hdr == NULL) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    if (sf_header_is_inline_value_prefix(hdr)) {
        return 0;
    }
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    return sf_header_group_state_local(hdr) != NULL;
#else
    SFObjColdState_t *cold = sf_header_cold_state(hdr);
    if (cold != NULL and cold->group_root != NULL) {
        return 1;
    }
    return hdr == sf_header_group_root_local(hdr) and
           cold != NULL and
           (cold->inline_group_live_count != 0U or cold->inline_group_head != NULL);
#endif
#else
    return sf_header_group_state_atomic(hdr) != NULL;
#endif
}

int sf_header_init_group_root(SFObjHeader_t *hdr)
{
    if (hdr == NULL) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    if (sf_header_is_inline_value_prefix(hdr)) {
        return 1;
    }
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    if (sf_header_group_state_local(hdr) != NULL) {
        return 1;
    }
    SFGroupState_t *group = sf_create_group_state(hdr);
    if (group == NULL) {
        return 0;
    }
    if (not sf_header_set_group_state_local(hdr, group)) {
        sf_runtime_mutex_destroy(&group->group_lock);
        free(group);
        return 0;
    }
    (void)sf_header_set_group_next_local(hdr, NULL);
    return 1;
#else
    SFObjColdState_t *cold = sf_header_ensure_cold_state(hdr);
    if (cold == NULL) {
        return 0;
    }
    if (cold->inline_group_live_count != 0U or cold->inline_group_head != NULL) {
        return 1;
    }
    cold->inline_group_head = hdr;
    cold->inline_group_live_count = 1U;
    cold->inline_group_dead = 0U;
    cold->group_next = NULL;
    return 1;
#endif
#else
    SFGroupState_t *group = NULL;

    if (sf_header_group_state_atomic(hdr) != NULL) {
        return 1;
    }
    group = sf_create_group_state(hdr);
    if (group == NULL) {
        return 0;
    }
    hdr->group_next = NULL;
    if (sf_header_try_set_group_state_atomic(hdr, group)) {
        return 1;
    }
    sf_runtime_mutex_destroy(&group->group_lock);
    free(group);
    return sf_header_group_state_atomic(hdr) != NULL;
#endif
}

SFRuntimeMutex_t *sf_header_group_lock(SFObjHeader_t *hdr)
{
    SFObjHeader_t *root = sf_header_group_root(hdr);
    if (root == NULL) {
        return NULL;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    if (sf_header_is_inline_value_prefix(root)) {
        return NULL;
    }
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    SFGroupState_t *group = sf_header_group_state_local(root);
    if (group == NULL) {
        return NULL;
    }
    return &group->group_lock;
#else
    SFObjColdState_t *cold = sf_header_inline_group_root_cold(root);
    if (cold == NULL or cold->inline_group_live_count == 0U) {
        return NULL;
    }
    return (SFRuntimeMutex_t *)&cold->inline_group_reserved;
#endif
#else
    SFGroupState_t *group = sf_header_group_state_atomic(root);
    if (group == NULL) {
        return NULL;
    }
    return &group->group_lock;
#endif
}

void sf_header_destroy_sidecar(SFObjHeader_t *hdr, int destroy_group_lock)
{
    if (hdr == NULL) {
        return;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    if (sf_header_is_inline_value_prefix(hdr)) {
        (void)destroy_group_lock;
        return;
    }
    SFObjColdState_t *cold = sf_header_cold_state(hdr);
    if (cold == NULL) {
        return;
    }
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    if (destroy_group_lock and cold->group != NULL and cold->group->root == hdr) {
        sf_runtime_mutex_destroy(&cold->group->group_lock);
        free(cold->group);
    }
#else
    (void)destroy_group_lock;
#endif
    hdr->cold = NULL;
    hdr->flags &= ~(uint32_t)SF_OBJ_FLAG_HAS_COLD;
    free(cold);
#else
    SFGroupState_t *group = sf_header_exchange_group_state_atomic(hdr, NULL);
    hdr->parent = NULL;
    hdr->group_next = NULL;
    if (destroy_group_lock and group != NULL and group->root == hdr) {
        sf_runtime_mutex_destroy(&group->group_lock);
        free(group);
    }
#endif
}
