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
    return hdr != nullptr and
           (inline_hdr->flags & SF_OBJ_FLAG_INLINE_VALUE) != 0U and
           (inline_hdr->tagged_parent & (uintptr_t)1U) != 0U;
#else
    (void)hdr;
    return 0;
#endif
}

id sf_header_object(SFObjHeader_t *hdr)
{
    if (hdr == nullptr) {
        return nullptr;
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
    return nullptr;
#endif
}

static SFObjColdState_t *sf_header_cold_state(SFObjHeader_t *hdr)
{
    if (sf_header_is_inline_value_prefix(hdr)) {
        return nullptr;
    }
    return (hdr != nullptr and (hdr->flags & SF_OBJ_FLAG_HAS_COLD) != 0U) ? hdr->cold : nullptr;
}

static SFObjColdState_t *sf_header_ensure_cold_state(SFObjHeader_t *hdr)
{
    SFObjColdState_t *cold = nullptr;

    if (hdr == nullptr) {
        return nullptr;
    }
    if (sf_header_is_inline_value_prefix(hdr)) {
        return nullptr;
    }
    cold = sf_header_cold_state(hdr);
    if (cold != nullptr) {
        return cold;
    }
    cold = (SFObjColdState_t *)sf_runtime_test_calloc(1U, sizeof(*cold));
    if (cold == nullptr) {
        return nullptr;
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
        return allocator != nullptr ? allocator : sf_default_allocator();
    }
    SFObjColdState_t *cold = sf_header_cold_state(hdr);
    return cold != nullptr ? cold->allocator : nullptr;
}

static int sf_header_set_allocator_local(SFObjHeader_t *hdr, SFAllocator_t *allocator)
{
    SFObjColdState_t *cold = nullptr;
    SFAllocator_t *default_allocator = sf_default_allocator();

    if (hdr == nullptr) {
        return 0;
    }
    if (sf_header_is_inline_value_prefix(hdr)) {
        SFAllocator_t *current = sf_header_allocator_local(hdr);
        return allocator == nullptr or allocator == current;
    }
    if (allocator == nullptr or allocator == default_allocator) {
        cold = sf_header_cold_state(hdr);
        if (cold != nullptr) {
            cold->allocator = nullptr;
        }
        return 1;
    }
    cold = sf_header_ensure_cold_state(hdr);
    if (cold == nullptr) {
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
    return cold != nullptr ? cold->parent : nullptr;
}

static int sf_header_set_parent_local(SFObjHeader_t *hdr, id parent)
{
    SFObjColdState_t *cold = nullptr;

    if (hdr == nullptr) {
        return 0;
    }
    if (sf_header_is_inline_value_prefix(hdr)) {
        SFInlineValueHeader_t *inline_hdr = (SFInlineValueHeader_t *)(void *)hdr;
        inline_hdr->tagged_parent = sf_inline_value_tagged_parent(parent);
        return 1;
    }
    cold = (parent != nullptr) ? sf_header_ensure_cold_state(hdr) : sf_header_cold_state(hdr);
    if (parent != nullptr and cold == nullptr) {
        return 0;
    }
    if (cold != nullptr) {
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
    return (cold != nullptr and cold->group_root != nullptr) ? cold->group_root : hdr;
}

static SFObjHeader_t *sf_header_group_next_local(SFObjHeader_t *hdr)
{
    if (sf_header_is_inline_value_prefix(hdr)) {
        return nullptr;
    }
    SFObjColdState_t *cold = sf_header_cold_state(hdr);
    return cold != nullptr ? cold->group_next : nullptr;
}

static int sf_header_set_group_next_local(SFObjHeader_t *hdr, SFObjHeader_t *group_next)
{
    SFObjColdState_t *cold = nullptr;

    if (hdr == nullptr) {
        return 0;
    }
    if (sf_header_is_inline_value_prefix(hdr)) {
        return group_next == nullptr;
    }
    cold = (group_next != nullptr) ? sf_header_ensure_cold_state(hdr) : sf_header_cold_state(hdr);
    if (group_next != nullptr and cold == nullptr) {
        return 0;
    }
    if (cold != nullptr) {
        cold->group_next = group_next;
    }
    return 1;
}

#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
static SFGroupState_t *sf_header_group_state_local(SFObjHeader_t *hdr)
{
    SFObjHeader_t *root = sf_header_group_root_local(hdr);
    SFObjColdState_t *cold = sf_header_cold_state(root);
    return cold != nullptr ? cold->group : nullptr;
}

static int sf_header_set_group_state_local(SFObjHeader_t *root, SFGroupState_t *group)
{
    SFObjColdState_t *cold = nullptr;

    if (root == nullptr) {
        return 0;
    }
    cold = (group != nullptr) ? sf_header_ensure_cold_state(root) : sf_header_cold_state(root);
    if (group != nullptr and cold == nullptr) {
        return 0;
    }
    if (cold != nullptr) {
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
    return hdr != nullptr ? (id)(void *)(hdr + 1) : nullptr;
}

#if SF_RUNTIME_THREADSAFE
static SFGroupState_t *sf_header_group_state_atomic(SFObjHeader_t *hdr)
{
    return hdr != nullptr ? __atomic_load_n(&hdr->group, __ATOMIC_ACQUIRE) : nullptr;
}

static void sf_header_set_group_state_atomic(SFObjHeader_t *hdr, SFGroupState_t *group)
{
    if (hdr != nullptr) {
        __atomic_store_n(&hdr->group, group, __ATOMIC_RELEASE);
    }
}

static SFGroupState_t *sf_header_exchange_group_state_atomic(SFObjHeader_t *hdr, SFGroupState_t *group)
{
    return hdr != nullptr ? __atomic_exchange_n(&hdr->group, group, __ATOMIC_ACQ_REL) : nullptr;
}

static int sf_header_try_set_group_state_atomic(SFObjHeader_t *hdr, SFGroupState_t *group)
{
    SFGroupState_t *expected = nullptr;

    if (hdr == nullptr) {
        return 0;
    }
    return __atomic_compare_exchange_n(&hdr->group, &expected, group, 0, __ATOMIC_RELEASE,
                                       __ATOMIC_ACQUIRE);
}
#else
static int sf_header_uses_inline_group_state(SFObjHeader_t *hdr)
{
    return hdr != nullptr and (((uintptr_t)hdr->group) & (uintptr_t)1U) != 0U;
}

static SFObjHeader_t *sf_header_inline_group_root(SFObjHeader_t *hdr)
{
    return sf_header_uses_inline_group_state(hdr)
               ? (SFObjHeader_t *)(void *)(((uintptr_t)hdr->group) & ~(uintptr_t)1U)
               : nullptr;
}

static int sf_header_can_use_inline_group_root(SFObjHeader_t *hdr)
{
    return hdr != nullptr and (hdr->flags & SF_OBJ_FLAG_EMBEDDED) == 0U;
}

static SFObjHeader_t *sf_header_inline_group_head(SFObjHeader_t *root)
{
    return root != nullptr ? (SFObjHeader_t *)(void *)root->parent : nullptr;
}

static void sf_header_set_inline_group_head(SFObjHeader_t *root, SFObjHeader_t *head)
{
    if (root != nullptr) {
        root->parent = (id)(void *)head;
    }
}

static SFGroupState_t *sf_header_group_state_atomic(SFObjHeader_t *hdr)
{
    return (hdr != nullptr and not sf_header_uses_inline_group_state(hdr)) ? hdr->group : nullptr;
}

static void sf_header_set_group_state_atomic(SFObjHeader_t *hdr, SFGroupState_t *group)
{
    if (hdr != nullptr) {
        hdr->group = group;
    }
}

static SFGroupState_t *sf_header_exchange_group_state_atomic(SFObjHeader_t *hdr, SFGroupState_t *group)
{
    SFGroupState_t *old = nullptr;

    if (hdr == nullptr) {
        return nullptr;
    }
    old = sf_header_group_state_atomic(hdr);
    hdr->group = group;
    return old;
}

static int sf_header_try_set_group_state_atomic(SFObjHeader_t *hdr, SFGroupState_t *group)
{
    if (hdr == nullptr or hdr->group != nullptr or sf_header_uses_inline_group_state(hdr)) {
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
    if (group == nullptr) {
        return nullptr;
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
        return nullptr;
    }
#if SF_RUNTIME_VALIDATION
    SFObjColdState_t *cold = sf_header_cold_state(hdr);
    return cold != nullptr ? cold->live_next : nullptr;
#else
    (void)hdr;
    return nullptr;
#endif
#else
#if SF_RUNTIME_VALIDATION
    return hdr != nullptr ? hdr->live_next : nullptr;
#else
    (void)hdr;
    return nullptr;
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
    SFObjColdState_t *cold = (next != nullptr) ? sf_header_ensure_cold_state(hdr) : sf_header_cold_state(hdr);
    if (cold != nullptr) {
        cold->live_next = next;
    }
#else
    (void)hdr;
    (void)next;
#endif
#else
#if SF_RUNTIME_VALIDATION
    if (hdr != nullptr) {
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
    if (hdr == nullptr) {
        return nullptr;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return sf_header_allocator_local(hdr);
#else
    return hdr->allocator;
#endif
}

int sf_header_set_allocator(SFObjHeader_t *hdr, SFAllocator_t *allocator)
{
    if (hdr == nullptr) {
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
    if (hdr == nullptr) {
        return nullptr;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return sf_header_parent_local(hdr);
#else
    if (sf_header_uses_inline_group_state(hdr) and sf_header_inline_group_root(hdr) == hdr and
        (hdr->flags & SF_OBJ_FLAG_EMBEDDED) == 0U) {
        return nullptr;
    }
    return hdr->parent;
#endif
}

int sf_header_set_parent(SFObjHeader_t *hdr, id parent)
{
    if (hdr == nullptr) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return sf_header_set_parent_local(hdr, parent);
#else
    if (sf_header_uses_inline_group_state(hdr) and sf_header_inline_group_root(hdr) == hdr and
        (hdr->flags & SF_OBJ_FLAG_EMBEDDED) == 0U) {
        return parent == nullptr;
    }
    hdr->parent = parent;
    return 1;
#endif
}

SFObjHeader_t *sf_header_group_root(SFObjHeader_t *hdr)
{
    if (hdr == nullptr) {
        return nullptr;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return sf_header_group_root_local(hdr);
#else
    SFObjHeader_t *inline_root = sf_header_inline_group_root(hdr);
    if (inline_root != nullptr) {
        return inline_root;
    }
    SFGroupState_t *group = sf_header_group_state_atomic(hdr);
    if (group != nullptr and group->root != nullptr) {
        return group->root;
    }
    return hdr;
#endif
}

int sf_header_set_group_root(SFObjHeader_t *hdr, SFObjHeader_t *group_root)
{
    if (hdr == nullptr) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    if (sf_header_is_inline_value_prefix(hdr)) {
        return group_root == nullptr or group_root == hdr;
    }
    if (group_root == nullptr) {
        SFObjColdState_t *cold = sf_header_cold_state(hdr);
        if (cold != nullptr) {
            cold->group_root = nullptr;
        }
        return 1;
    }
    if (not sf_header_init_group_root(group_root)) {
        return 0;
    }
    if (hdr == group_root) {
        SFObjColdState_t *cold = sf_header_cold_state(hdr);
        if (cold != nullptr) {
            cold->group_root = nullptr;
        }
        return 1;
    }
    SFObjColdState_t *cold = sf_header_ensure_cold_state(hdr);
    if (cold == nullptr) {
        return 0;
    }
    cold->group_root = group_root;
    return 1;
#else
    if (group_root == nullptr) {
        sf_header_set_group_state_atomic(hdr, nullptr);
        return 1;
    }
    if (not sf_header_init_group_root(group_root)) {
        return 0;
    }
    if (sf_header_uses_inline_group_state(group_root)) {
        hdr->group = (SFGroupState_t *)(void *)((uintptr_t)group_root | (uintptr_t)1U);
        return 1;
    }
    sf_header_set_group_state_atomic(hdr, sf_header_group_state_atomic(group_root));
    return sf_header_group_state_atomic(hdr) != nullptr;
#endif
}

SFObjHeader_t *sf_header_group_next(SFObjHeader_t *hdr)
{
    if (hdr == nullptr) {
        return nullptr;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    return sf_header_group_next_local(hdr);
#else
    return hdr->group_next;
#endif
}

int sf_header_set_group_next(SFObjHeader_t *hdr, SFObjHeader_t *group_next)
{
    if (hdr == nullptr) {
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
    if (hdr == nullptr) {
        return nullptr;
    }
#if SF_RUNTIME_COMPACT_HEADERS
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    SFGroupState_t *group = sf_header_group_state_local(hdr);
    if (group != nullptr and group->head != nullptr) {
        return group->head;
    }
#else
    SFObjColdState_t *cold = sf_header_inline_group_root_cold(hdr);
    if (cold != nullptr and cold->inline_group_head != nullptr) {
        return cold->inline_group_head;
    }
#endif
    return sf_header_group_root_local(hdr);
#else
    SFObjHeader_t *root = sf_header_group_root(hdr);
    if (root != nullptr and sf_header_uses_inline_group_state(root)) {
        SFObjHeader_t *head = sf_header_inline_group_head(root);
        return head != nullptr ? head : root;
    }
    SFGroupState_t *group = sf_header_group_state_atomic(hdr);
    if (group != nullptr and group->head != nullptr) {
        return group->head;
    }
    return hdr;
#endif
}

int sf_header_set_group_head(SFObjHeader_t *hdr, SFObjHeader_t *group_head)
{
    SFObjHeader_t *root = sf_header_group_root(hdr);
    if (root == nullptr) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    if (group_head == nullptr and sf_header_group_state_local(root) == nullptr) {
        return 1;
    }
    if (not sf_header_init_group_root(root)) {
        return 0;
    }
    SFGroupState_t *group = sf_header_group_state_local(root);
    if (group == nullptr) {
        return 0;
    }
    group->head = group_head;
    return 1;
#else
    if (group_head == nullptr) {
        SFObjColdState_t *cold = sf_header_cold_state(root);
        if (cold == nullptr) {
            return 1;
        }
        cold->inline_group_head = nullptr;
        return 1;
    }
    if (not sf_header_init_group_root(root)) {
        return 0;
    }
    SFObjColdState_t *cold = sf_header_inline_group_root_cold(root);
    if (cold == nullptr) {
        return 0;
    }
    cold->inline_group_head = group_head;
    return 1;
#endif
#else
    SFGroupState_t *group = nullptr;

    if (sf_header_uses_inline_group_state(root)) {
        sf_header_set_inline_group_head(root, group_head);
        return 1;
    }
    if (group_head == nullptr and sf_header_group_state_atomic(root) == nullptr) {
        return 1;
    }
    if (not sf_header_init_group_root(root)) {
        return 0;
    }
    group = sf_header_group_state_atomic(root);
    if (group == nullptr) {
        return 0;
    }
    group->head = group_head;
    return 1;
#endif
}

size_t sf_header_group_live_count(SFObjHeader_t *hdr)
{
    if (hdr == nullptr) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    SFGroupState_t *group = sf_header_group_state_local(hdr);
    if (group != nullptr) {
        return group->group_live_count;
    }
#else
    SFObjColdState_t *cold = sf_header_inline_group_root_cold(hdr);
    if (cold != nullptr and cold->inline_group_live_count != 0U) {
        return cold->inline_group_live_count;
    }
#endif
    return (hdr->state == SF_OBJ_STATE_LIVE) ? (size_t)1 : (size_t)0;
#else
    SFObjHeader_t *root = sf_header_group_root(hdr);
    if (root != nullptr and sf_header_uses_inline_group_state(root)) {
        return (size_t)root->reserved;
    }
    SFGroupState_t *group = sf_header_group_state_atomic(hdr);
    if (group != nullptr) {
        return group->group_live_count;
    }
    return (hdr->state == SF_OBJ_STATE_LIVE) ? (size_t)1 : (size_t)0;
#endif
}

int sf_header_set_group_live_count(SFObjHeader_t *hdr, size_t count)
{
    SFObjHeader_t *root = sf_header_group_root(hdr);
    if (root == nullptr) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    if (count <= (size_t)1 and sf_header_group_state_local(root) == nullptr) {
        if (count == 0U) {
            sf_header_or_aux_flags(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
        } else {
            sf_header_clear_aux_flags(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
        }
        return 1;
    }
    if (not sf_header_init_group_root(root)) {
        return 0;
    }
    SFGroupState_t *group = sf_header_group_state_local(root);
    if (group == nullptr) {
        return 0;
    }
    group->group_live_count = count;
    group->dead = (count == 0) ? 1U : 0U;
    if (count == 0U) {
        sf_header_or_aux_flags(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
    } else {
        sf_header_clear_aux_flags(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
    }
    return 1;
#else
    if (count <= (size_t)1) {
        SFObjColdState_t *cold = sf_header_cold_state(root);
        if (cold == nullptr) {
            if (count == 0U) {
                sf_header_or_aux_flags(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
            } else {
                sf_header_clear_aux_flags(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
            }
            return 1;
        }
        cold->inline_group_live_count = count;
        cold->inline_group_dead = (count == 0) ? 1U : 0U;
        if (count != 0U and cold->inline_group_head == nullptr) {
            cold->inline_group_head = root;
        }
        if (count == 0U) {
            sf_header_or_aux_flags(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
        } else {
            sf_header_clear_aux_flags(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
        }
        return 1;
    }
    if (not sf_header_init_group_root(root)) {
        return 0;
    }
    SFObjColdState_t *cold = sf_header_inline_group_root_cold(root);
    if (cold == nullptr) {
        return 0;
    }
    cold->inline_group_live_count = count;
    cold->inline_group_dead = (count == 0) ? 1U : 0U;
    if (count == 0U) {
        sf_header_or_aux_flags(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
    } else {
        sf_header_clear_aux_flags(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
    }
    return 1;
#endif
#else
    SFGroupState_t *group = nullptr;

    if (sf_header_uses_inline_group_state(root)) {
        root->reserved = (uint32_t)count;
        if (count == 0U) {
            sf_header_or_aux_flags(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
        } else {
            sf_header_clear_aux_flags(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
            if (sf_header_inline_group_head(root) == nullptr) {
                sf_header_set_inline_group_head(root, root);
            }
        }
        return 1;
    }
    if (count <= (size_t)1 and sf_header_group_state_atomic(root) == nullptr) {
        return 1;
    }
    if (not sf_header_init_group_root(root)) {
        return 0;
    }
    group = sf_header_group_state_atomic(root);
    if (group == nullptr) {
        return 0;
    }
    group->group_live_count = count;
    group->dead = (count == 0) ? 1U : 0U;
    if (count == 0U) {
        sf_header_or_aux_flags(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
    } else {
        sf_header_clear_aux_flags(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
    }
    return 1;
#endif
}

int sf_header_group_dead(SFObjHeader_t *hdr)
{
    SFObjHeader_t *root = sf_header_group_root(hdr);

    if (root == nullptr) {
        return 0;
    }
    if (sf_header_has_aux_flag(root, SF_OBJ_AUX_FLAG_GROUP_DEAD)) {
        return 1;
    }
#if SF_RUNTIME_COMPACT_HEADERS
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    SFGroupState_t *group = sf_header_group_state_local(root);
    return group != nullptr and group->dead != 0U;
#else
    SFObjColdState_t *cold = sf_header_inline_group_root_cold(root);
    return cold != nullptr and cold->inline_group_dead != 0U;
#endif
#else
    if (sf_header_uses_inline_group_state(root)) {
        return sf_header_has_aux_flag(root, SF_OBJ_AUX_FLAG_GROUP_DEAD);
    }
    SFGroupState_t *group = sf_header_group_state_atomic(root);
    return group != nullptr and group->dead != 0U;
#endif
}

int sf_header_grouped(SFObjHeader_t *hdr)
{
    if (hdr == nullptr) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    if (sf_header_is_inline_value_prefix(hdr)) {
        return 0;
    }
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    return sf_header_group_state_local(hdr) != nullptr;
#else
    SFObjColdState_t *cold = sf_header_cold_state(hdr);
    if (cold != nullptr and cold->group_root != nullptr) {
        return 1;
    }
    return hdr == sf_header_group_root_local(hdr) and
           cold != nullptr and
           (cold->inline_group_live_count != 0U or cold->inline_group_head != nullptr);
#endif
#else
    return sf_header_uses_inline_group_state(hdr) or sf_header_group_state_atomic(hdr) != nullptr;
#endif
}

int sf_header_init_group_root(SFObjHeader_t *hdr)
{
    if (hdr == nullptr) {
        return 0;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    if (sf_header_is_inline_value_prefix(hdr)) {
        return 1;
    }
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    if (sf_header_group_state_local(hdr) != nullptr) {
        return 1;
    }
    SFGroupState_t *group = sf_create_group_state(hdr);
    if (group == nullptr) {
        return 0;
    }
    if (not sf_header_set_group_state_local(hdr, group)) {
        sf_runtime_mutex_destroy(&group->group_lock);
        free(group);
        return 0;
    }
    (void)sf_header_set_group_next_local(hdr, nullptr);
    sf_header_clear_aux_flags(hdr, SF_OBJ_AUX_FLAG_GROUP_DEAD);
    return 1;
#else
    SFObjColdState_t *cold = sf_header_ensure_cold_state(hdr);
    if (cold == nullptr) {
        return 0;
    }
    if (cold->inline_group_live_count != 0U or cold->inline_group_head != nullptr) {
        return 1;
    }
    cold->inline_group_head = hdr;
    cold->inline_group_live_count = 1U;
    cold->inline_group_dead = 0U;
    cold->group_next = nullptr;
    sf_header_clear_aux_flags(hdr, SF_OBJ_AUX_FLAG_GROUP_DEAD);
    return 1;
#endif
#else
    SFGroupState_t *group = nullptr;

    if (sf_header_uses_inline_group_state(hdr) or sf_header_group_state_atomic(hdr) != nullptr) {
        return 1;
    }
    if (sf_header_can_use_inline_group_root(hdr)) {
        hdr->group = (SFGroupState_t *)(void *)((uintptr_t)hdr | (uintptr_t)1U);
        sf_header_set_inline_group_head(hdr, hdr);
        hdr->group_next = nullptr;
        hdr->reserved = 1U;
        sf_header_clear_aux_flags(hdr, SF_OBJ_AUX_FLAG_GROUP_DEAD);
        return 1;
    }
    group = sf_create_group_state(hdr);
    if (group == nullptr) {
        return 0;
    }
    hdr->group_next = nullptr;
    if (sf_header_try_set_group_state_atomic(hdr, group)) {
        sf_header_clear_aux_flags(hdr, SF_OBJ_AUX_FLAG_GROUP_DEAD);
        return 1;
    }
    sf_runtime_mutex_destroy(&group->group_lock);
    free(group);
    return sf_header_group_state_atomic(hdr) != nullptr;
#endif
}

SFRuntimeMutex_t *sf_header_group_lock(SFObjHeader_t *hdr)
{
    SFObjHeader_t *root = sf_header_group_root(hdr);
    if (root == nullptr) {
        return nullptr;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    if (sf_header_is_inline_value_prefix(root)) {
        return nullptr;
    }
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    SFGroupState_t *group = sf_header_group_state_local(root);
    if (group == nullptr) {
        return nullptr;
    }
    return &group->group_lock;
#else
    SFObjColdState_t *cold = sf_header_inline_group_root_cold(root);
    if (cold == nullptr or cold->inline_group_live_count == 0U) {
        return nullptr;
    }
    return (SFRuntimeMutex_t *)&cold->inline_group_reserved;
#endif
#else
    if (sf_header_uses_inline_group_state(root)) {
        return (SFRuntimeMutex_t *)&root->reserved;
    }
    SFGroupState_t *group = sf_header_group_state_atomic(root);
    if (group == nullptr) {
        return nullptr;
    }
    return &group->group_lock;
#endif
}

void sf_header_destroy_sidecar(SFObjHeader_t *hdr, int destroy_group_lock)
{
    if (hdr == nullptr) {
        return;
    }
#if SF_RUNTIME_COMPACT_HEADERS
    if (sf_header_is_inline_value_prefix(hdr)) {
        (void)destroy_group_lock;
        return;
    }
    SFObjColdState_t *cold = sf_header_cold_state(hdr);
    if (cold == nullptr) {
        return;
    }
#if SF_RUNTIME_THREADSAFE || !SF_RUNTIME_INLINE_GROUP_STATE
    if (destroy_group_lock and cold->group != nullptr and cold->group->root == hdr) {
        sf_runtime_mutex_destroy(&cold->group->group_lock);
        free(cold->group);
    }
#else
    (void)destroy_group_lock;
#endif
    hdr->cold = nullptr;
    hdr->flags &= ~(uint32_t)SF_OBJ_FLAG_HAS_COLD;
    free(cold);
#else
    if (sf_header_uses_inline_group_state(hdr)) {
        SFObjHeader_t *inline_root = sf_header_inline_group_root(hdr);
        hdr->group = nullptr;
        hdr->group_next = nullptr;
        if (inline_root == hdr and (hdr->flags & SF_OBJ_FLAG_EMBEDDED) == 0U) {
            sf_header_set_inline_group_head(hdr, nullptr);
            hdr->reserved = 0U;
            sf_header_clear_aux_flags(hdr, SF_OBJ_AUX_FLAG_GROUP_DEAD);
        } else {
            hdr->parent = nullptr;
        }
        return;
    }
    SFGroupState_t *group = sf_header_exchange_group_state_atomic(hdr, nullptr);
    hdr->parent = nullptr;
    hdr->group_next = nullptr;
    if (destroy_group_lock and group != nullptr and group->root == hdr) {
        sf_runtime_mutex_destroy(&group->group_lock);
        free(group);
    }
#endif
}
