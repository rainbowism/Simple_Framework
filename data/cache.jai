MD5_Cache :: struct (Value_Type: Type) {
    Entry :: struct {
        value:    Value_Type;
        refcount: s32 = 1;
    }

    table: Table(string, Entry);
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
    // trace("Texture_Cache.load_texture: %", filepath);
    // file_buffer, success := read_entire_file(filepath);
    // // @Todo(sushi): Check if successful
    // defer free(file_buffer);

    // digest := md5(file_buffer);
    // defer free(digest);

    // hash := get_hash(digest);

    entry, newly_added := find_or_add(*cache.table, filepath);
    if !newly_added {
        entry.refcount += 1;
        trace("Texture_Cache hit: % counts", entry.refcount);
        return entry.value;
    }

    texture := load_texture(filepath);
    // defer free_stbi_image(image);

    // texture := create_texture(image);
    entry.value = texture;
    // table_add(*cache.table, hash, texture);

    trace("Texture_Cache miss.");
    return texture;
}

free_texture :: (cache: *Texture_Cache, filepath: string) {
    pointer := table_find_pointer(*cache.table, filepath);
    if pointer == null  return;
    pointer.refcount -= 1;
    trace("Texture_Cache free: % counts left", pointer.refcount);
    if pointer.refcount > 0  return;
    free_texture(pointer.value);
    table_remove(*cache.table, filepath);
}

#scope_file

#import "Hash";
#import "Hash_Table";
#import "md5";
