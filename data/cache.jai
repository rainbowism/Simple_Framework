MD5_Cache :: struct (Value_Type: Type) {
    Entry :: struct {
        value:    Value_Type;
        refcount: s32 = 1;
    }

    table: Table(u32, Entry);
}

Texture_Cache :: MD5_Cache(Texture);

init_cache :: (cache: *MD5_Cache($T), allocator: Allocator = context.allocator) {
    cache.table.allocator = allocator;
    init(*cache.table);
}

free_cache :: (cache: *MD5_Cache($T)) {
    deinit(*cache.table);
}

load_texture :: (cache: *Texture_Cache, filepath: string) -> Texture {
    hash := get_hash(filepath);
    entry, newly_added := find_or_add(*cache.table, hash);
    if !newly_added {
        entry.refcount += 1;
        // trace("Texture_Cache hit: % counts", entry.refcount);
        return entry.value;
    }

    texture := load_texture(filepath);
    entry.value = texture;
    // trace("Texture_Cache miss.");
    return texture;
}

free_texture :: (cache: *Texture_Cache, filepath: string) {
    hash := get_hash(filepath);
    pointer := table_find_pointer(*cache.table, hash);
    if pointer == null  return;
    pointer.refcount -= 1;
    // trace("Texture_Cache free: % counts left", pointer.refcount);
    if pointer.refcount > 0  return;
    free_texture(pointer.value);
    table_remove(*cache.table, hash);
}

#scope_file

#import "Hash";
#import "Hash_Table";
