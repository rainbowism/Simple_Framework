Log_Type :: enum {
    Game;
    Core;
    Render;
    Audio;
}

Log_Level :: enum {
    Trace :: 0;
    Debug :: 1;
    Info  :: 2;
    Warn  :: 3;
    Error :: 4;
    Panic :: 5;
}

log :: ($log_type: Log_Type, $log_level: Log_Level, fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    #if log_level >= Default_Log_Level {
        // @Note(sushi): doing it lazily because there's no padding on string formatting
        #if Log_File_Paths {
            partial_path := path_filename(loc.fully_pathed_filename);
            #if log_level == .Info || log_level == .Warn {
                #if log_type == .Game    log(tprint("[SF:Game  ][% ][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
                #if log_type == .Core    log(tprint("[SF:Core  ][% ][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
                #if log_type == .Render  log(tprint("[SF:Render][% ][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
                #if log_type == .Audio   log(tprint("[SF:Audio ][% ][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
            } else {
                #if log_type == .Game    log(tprint("[SF:Game  ][%][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
                #if log_type == .Core    log(tprint("[SF:Core  ][%][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
                #if log_type == .Render  log(tprint("[SF:Render][%][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
                #if log_type == .Audio   log(tprint("[SF:Audio ][%][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
            }
        } else {
            #if log_level == .Info || log_level == .Warn {
                #if log_type == .Game    log(tprint("[SF:Game  ][% ] %\n", log_level, fmt), ..args, flags = flags);
                #if log_type == .Core    log(tprint("[SF:Core  ][% ] %\n", log_level, fmt), ..args, flags = flags);
                #if log_type == .Render  log(tprint("[SF:Render][% ] %\n", log_level, fmt), ..args, flags = flags);
                #if log_type == .Audio   log(tprint("[SF:Audio ][% ] %\n", log_level, fmt), ..args, flags = flags);
            } else {
                #if log_type == .Game    log(tprint("[SF:Game  ][%] %\n", log_level, fmt), ..args, flags = flags);
                #if log_type == .Core    log(tprint("[SF:Core  ][%] %\n", log_level, fmt), ..args, flags = flags);
                #if log_type == .Render  log(tprint("[SF:Render][%] %\n", log_level, fmt), ..args, flags = flags);
                #if log_type == .Audio   log(tprint("[SF:Audio ][%] %\n", log_level, fmt), ..args, flags = flags);
            }
        }
    }
}

trace :: (fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .Trace, fmt, ..args, flags = flags, loc = loc);
}

debug :: (fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .Debug, fmt, ..args, flags = flags, loc = loc);
}

info :: (fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .Info, fmt, ..args, flags = flags, loc = loc);
}

warn :: (fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .Warn, fmt, ..args, flags = flags | .WARNING, loc = loc);
}

error :: (fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .Error, fmt, ..args, flags = flags | .ERROR, loc = loc);
}

panic :: (fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .Panic, fmt, ..args, flags = flags | .ERROR, loc = loc);
}

trace :: (value: Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .Trace, "%", value, flags = flags, loc = loc);
}

debug :: (value: Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .Debug, "%", value, flags = flags, loc = loc);
}

info :: (value: Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .Info, "%", value, flags = flags, loc = loc);
}

warn :: (value: Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .Warn, "%", value, flags = flags | .WARNING, loc = loc);
}

error :: (value: Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .Error, "%", value, flags = flags | .ERROR, loc = loc);
}

panic :: (value: Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .Panic, "%", value, flags = flags | .ERROR, loc = loc);
}

trace :: ($log_type: Log_Type, fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(log_type, .Trace, fmt, ..args, flags = flags, loc = loc);
}

debug :: ($log_type: Log_Type, fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(log_type, .Debug, fmt, ..args, flags = flags, loc = loc);
}

info :: ($log_type: Log_Type, fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(log_type, .Info, fmt, ..args, flags = flags, loc = loc);
}

warn :: ($log_type: Log_Type, fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(log_type, .Warn, fmt, ..args, flags = flags | .WARNING, loc = loc);
}

error :: ($log_type: Log_Type, fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(log_type, .Error, fmt, ..args, flags = flags | .ERROR, loc = loc);
}

panic :: ($log_type: Log_Type, fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(log_type, .Panic, fmt, ..args, flags = flags | .ERROR, loc = loc);
}

check_result :: (condition: bool, fmt: string, args: .. Any) #expand {
    if !condition  return;
    error(fmt, ..args);
    exit(1);
}


#if OS == .WINDOWS {
    usleep :: (microseconds: s64, target_time: float64) {
        ft: LARGE_INTEGER;
        // ft.QuadPart = -microseconds * 10;
        ft.QuadPart = -microseconds * 9;
        // ft.QuadPart = -(microseconds * 9 + microseconds >> 1);

        timer := CreateWaitableTimerW(null, .TRUE, null);
        SetWaitableTimer(timer, *ft, 0, null, null, .FALSE);
        WaitForSingleObject(timer, INFINITE);
        CloseHandle(timer);

        while get_time() < target_time {}
    }

    // usleep :: (microseconds: s64, target_time: float64) {
    //     CreateWaitableTimerExW :: (
    //         lpTimerAttributes: *SECURITY_ATTRIBUTES,
    //         lpTimerName:       LPCWSTR,
    //         dwFlags:           DWORD,
    //         dwDesiredAccess:   DWORD
    //     ) -> HANDLE #foreign kernel32;
    //     kernel32 :: #system_library "kernel32";

    //     // @PlatformDependence
    //     CREATE_WAITABLE_TIMER_HIGH_RESOLUTION :: 0x00000002;
    //     EVENT_ALL_ACCESS :: 0x1F0003;
    //     high_resolution_timer := CreateWaitableTimerExW(null, null, CREATE_WAITABLE_TIMER_HIGH_RESOLUTION, EVENT_ALL_ACCESS);

    //     // to wait on it:
    //     due_time: LARGE_INTEGER;
    //     due_time.QuadPart = -microseconds * 10;
    //     set_ok := SetWaitableTimer(high_resolution_timer, *due_time, 0, null, null, 0);
    //     assert(set_ok != 0, "%", GetLastError());
    //     WaitForSingleObject(high_resolution_timer, INFINITE);

    //     while get_time() < target_time {}
    // }
} else #if OS == .LINUX || OS == .MACOS {
    usleep :: (microseconds: s64, target_time: float64) {
        nanosleep :: (req: *timespec, rem: *timespec) -> int #foreign libc;

        MICRO_TO_NANO :: 1000;
        MICRO_TO_SECS :: 1000000;

        req: timespec;
        req.tv_sec = microseconds / MICRO_TO_SECS;
        req.tv_nsec = MICRO_TO_NANO * (microseconds % MICRO_TO_SECS);
        nanosleep(*req, null);

        while get_time() < target_time {}
    }
}

#scope_module

temp_c_string :: (s: string) -> *u8 {
    result: *u8 = talloc(s.count + 1);
    memcpy(result, s.data, s.count);
    result[s.count] = 0;
    return result;
}

to_string :: (c_string: *u8, count: $T) -> string
#modify {
    if (cast(*Type_Info) T).type == .INTEGER return true;    // Accept integers.
    return false;
} {
    s: string = ---;
    s.data  = c_string;
    s.count = count;
    return s;
}

count_newlines :: (s: string) -> s64 #no_abc {
    cursor := 0;
    count  := 0;

    while cursor < s.count {
        if s[cursor] == #char "\n"  count += 1;
        cursor += 1;
    }

    return count;
}

insert_line_numbers :: (s: string) -> string {
    builder: String_Builder;

    line_count := count_newlines(s);
    count      := line_count;
    digits     := 1;
    while count > 10 {
        count  %= 10;
        digits += 1;
    }

    lines := split(s, "\n");
    for 0..line_count-1 {
        print_to_builder(*builder, "%: %\n", formatInt(it, minimum_digits = digits), lines[it]);
    }
    return builder_to_string(*builder, __temporary_allocator);
}

#scope_file

#if OS == .WINDOWS {
    #import "Windows";
} else #if OS == .LINUX || OS == .MACOS {
    #import "POSIX";
}

#import "String";
#import "File_Utilities";
