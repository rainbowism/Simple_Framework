Profiler_Task :: struct {
    start: float64;
    end:   float64;
    name:  string;
    color: u32;
}

Profiler_Frame :: struct {
    start: float64;
    end:   float64;
    tasks: [..] Profiler_Task;
}

Profiler :: struct {
    frames: [MAX_PROFILER_FRAMES] Profiler_Frame;
    index: int;
}

#if Enable_Profiler {
    profiler_scoped_task :: (using profiler: *Profiler, name: string, color := Colors8.White) #expand {
        id := profiler_begin_task(name, color);
        defer profiler_end_task(id);
    }

    profiler_begin_frame :: (using profiler: *Profiler) {
        frames[index].start = get_time();
        frames[index].tasks.count = 0;
    }

    profiler_end_frame :: (using profiler: *Profiler) {
        frames[index].end = get_time();
        index = (index + 1) % MAX_PROFILER_FRAMES;
    }

    profiler_frame_elapsed :: (using profiler: *Profiler) -> float64 {
        return get_time() - frames[index].start;
    }

    profiler_begin_task :: (using profiler: *Profiler, name: string, color := Colors8.White) -> int {
        task: Profiler_Task = ---;
        task.start = profiler_frame_elapsed(profiler);
        task.name  = name;
        task.color = color.value;

        array_add(*frames[index].tasks, task);
        return frames[index].tasks.count-1;
    }

    profiler_end_task :: (using profiler: *Profiler, id: int) -> Profiler_Task {
        frames[index].tasks[id].end = profiler_frame_elapsed(profiler);
        return frames[index].tasks[id];
    }

    cpu_scoped_task :: (name: string, color := Colors8.White) #expand {
        id := profiler_begin_task(*_cpu_profiler, name, color);
        `defer profiler_end_task(*_cpu_profiler, id);
    }

    cpu_begin_frame :: () #expand {
        profiler_begin_frame(*_cpu_profiler);
    }

    cpu_end_frame :: () #expand {
        profiler_end_frame(*_cpu_profiler);
    }

    cpu_elapsed :: () -> float64 #expand {
        profiler_elapsed(*_cpu_profiler);
    }

    cpu_begin_task :: (name: string, color := Colors8.White) -> int #expand {
        return profiler_begin_task(*_cpu_profiler, name, color);
    }

    cpu_end_task :: (id: int) -> Profiler_Task #expand {
        profiler_end_task(*_cpu_profiler, id);
    }

    gpu_scoped_task :: (name: string, color := Colors8.White) #expand {
        id := profiler_begin_task(*_gpu_profiler, name, color);
        `defer profiler_end_task(*_gpu_profiler, id);
    }

    gpu_begin_frame :: () #expand {
        profiler_begin_frame(*_gpu_profiler);
    }

    gpu_end_frame :: () #expand {
        profiler_end_frame(*_gpu_profiler);
    }

    gpu_elapsed :: () -> float64 #expand {
        profiler_elapsed(*_gpu_profiler);
    }

    gpu_begin_task :: (name: string, color := Colors8.White) -> int #expand {
        return profiler_begin_task(*_gpu_profiler, name, color);
    }

    gpu_end_task :: (id: int) -> Profiler_Task #expand {
        profiler_end_task(*_gpu_profiler, id);
    }
} else {
    profiler_begin_frame :: (profiler: *Profiler) #expand {}
    profiler_end_frame   :: (profiler: *Profiler) #expand {}
    profiler_elapsed     :: (profiler: *Profiler) -> float64 #expand {}
    profiler_begin_task  :: (profiler: *Profiler, name: string, color := Colors8.White) -> int #expand {}
    profiler_end_task    :: (profiler: *Profiler, id: int) -> Profiler_Task #expand {}
    cpu_scoped_task :: (name: string, color := Colors8.White) #expand {}
    cpu_begin_frame :: () #expand {}
    cpu_end_frame :: () #expand {}
    cpu_elapsed :: () -> float64 #expand {}
    cpu_begin_task :: (name: string, color := Colors8.White) -> int #expand {}
    cpu_end_task :: (id: int) -> Profiler_Task #expand {}
    gpu_scoped_task :: (name: string, color := Colors8.White) #expand {}
    gpu_begin_frame :: () #expand {}
    gpu_end_frame :: () #expand {}
    gpu_elapsed :: () -> float64 #expand {}
    gpu_begin_task :: (name: string, color := Colors8.White) -> int #expand {}
    gpu_end_task :: (id: int) -> Profiler_Task #expand {}
}

#scope_module

MAX_PROFILER_FRAMES :: 300;
_cpu_profiler: Profiler;
_gpu_profiler: Profiler;
