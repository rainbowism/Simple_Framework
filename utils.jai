Log_Type :: enum {
    Game;
    Core;
    Render;
    Audio;
}

Log_Level :: enum {
    TRACE;
    DEBUG;
    INFO;
    WARN;
    ERROR;
}

log :: ($log_type: Log_Type, $log_level: Log_Level, fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    #if log_level < LOG_LEVEL  return;
    // @Note(sushi): doing it lazily because there's no padding on string formatting
    #if LOG_FILE_PATH {
        path := parse_path(loc.fully_pathed_filename);
        partial_path := path.words[path.words.count-1];
        #if log_level == .ERROR || log_level == .DEBUG {
            #if log_type == .Game    log(tprint("[SF:Game  ][%][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
            #if log_type == .Core    log(tprint("[SF:Core  ][%][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
            #if log_type == .Render  log(tprint("[SF:Render][%][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
            #if log_type == .Audio   log(tprint("[SF:Audio ][%][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
        } else {
            #if log_type == .Game    log(tprint("[SF:Game  ][% ][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
            #if log_type == .Core    log(tprint("[SF:Core  ][% ][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
            #if log_type == .Render  log(tprint("[SF:Render][% ][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
            #if log_type == .Audio   log(tprint("[SF:Audio ][% ][%:%,%] %\n", log_level, partial_path, loc.line_number, loc.character_number, fmt), ..args, flags = flags);
        }
    } else {
        #if log_level == .ERROR || log_level == .DEBUG {
            #if log_type == .Game    log(tprint("[SF:Game  ][%] %\n", log_level, fmt), ..args, flags = flags);
            #if log_type == .Core    log(tprint("[SF:Core  ][%] %\n", log_level, fmt), ..args, flags = flags);
            #if log_type == .Render  log(tprint("[SF:Render][%] %\n", log_level, fmt), ..args, flags = flags);
            #if log_type == .Audio   log(tprint("[SF:Audio ][%] %\n", log_level, fmt), ..args, flags = flags);
        } else {
            #if log_type == .Game    log(tprint("[SF:Game  ][% ] %\n", log_level, fmt), ..args, flags = flags);
            #if log_type == .Core    log(tprint("[SF:Core  ][% ] %\n", log_level, fmt), ..args, flags = flags);
            #if log_type == .Render  log(tprint("[SF:Render][% ] %\n", log_level, fmt), ..args, flags = flags);
            #if log_type == .Audio   log(tprint("[SF:Audio ][% ] %\n", log_level, fmt), ..args, flags = flags);
        }
    }
}

trace :: (fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .TRACE, fmt, ..args, flags = flags, loc = loc);
}

debug :: (fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .DEBUG, fmt, ..args, flags = flags, loc = loc);
}

info :: (fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .INFO, fmt, ..args, flags = flags, loc = loc);
}

warn :: (fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .WARN, fmt, ..args, flags = flags | .WARNING, loc = loc);
}

error :: (fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(.Game, .ERROR, fmt, ..args, flags = flags | .ERROR, loc = loc);
}

trace :: ($log_type: Log_Type, fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(log_type, .TRACE, fmt, ..args, flags = flags, loc = loc);
}

debug :: ($log_type: Log_Type, fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(log_type, .DEBUG, fmt, ..args, flags = flags, loc = loc);
}

info :: ($log_type: Log_Type, fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(log_type, .INFO, fmt, ..args, flags = flags, loc = loc);
}

warn :: ($log_type: Log_Type, fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(log_type, .WARN, fmt, ..args, flags = flags | .WARNING, loc = loc);
}

error :: ($log_type: Log_Type, fmt: string, args: .. Any, flags := Log_Flags.NONE, loc := #caller_location) #expand {
    log(log_type, .ERROR, fmt, ..args, flags = flags | .ERROR, loc = loc);
}

#scope_module

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

temp_c_string :: (s: string) -> *u8 {
    result: *u8 = talloc(s.count + 1);
    memcpy(result, s.data, s.count);
    result[s.count] = 0;
    return result;
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

#if OS == .WINDOWS {
    usleep :: (microseconds: s64, target_time: float64) {
        ft: Win32.LARGE_INTEGER;
        ft.QuadPart = -(10 * microseconds);

        timer := Win32.CreateWaitableTimerW(null, .TRUE, null);
        Win32.SetWaitableTimer(timer, *ft, 0, null, null, .FALSE);
        Win32.WaitForSingleObject(timer, Win32.INFINITE);
        Win32.CloseHandle(timer);

        while get_time() < target_time {}
    }
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

#scope_file

#if OS == .WINDOWS {
    Win32 :: #import "Windows";
} else #if OS == .LINUX || OS == .MACOS {
    #import "POSIX";
}

#import "String";
#import "File_Utilities";
