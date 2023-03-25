MD5_Cache :: struct (Value_Type: Type) {
    Entry :: struct {
        value:    Value_Type;
        refcount: s32 = 1;
    }

    table: Table(u32, Entry);
}

init_cache :: (cache: *MD5_Cache($T), allocator := context.allocator) {
    cache.table.allocator = allocator;
    init(*cache.table);
}

free_cache :: (cache: *MD5_Cache($T)) {
    deinit(*cache.table);
}

#if !DISABLE_RENDER {
    Texture_Cache :: MD5_Cache(Texture);
    
    load_texture :: (cache: *Texture_Cache, filepath: string,
        min_sampling  := Sampling_Mode.Trilinear_Mipmap,
        mag_sampling  := Sampling_Mode.Linear,
        wrap_mode     := Wrap_Mode.Clamp_To_Edge,
        $pixel_format := Pixel_Format.RGBA) -> Texture {
        hash := get_hash(filepath);
        entry, newly_added := find_or_add(*cache.table, hash);
        if !newly_added {
            entry.refcount += 1;
            // trace("Texture_Cache hit: % counts", entry.refcount);
            return entry.value;
        }
    
        texture := load_texture(filepath, min_sampling, mag_sampling, wrap_mode, pixel_format);
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
}
