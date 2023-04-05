#scope_file

Basic :: #import "Basic";

#scope_export

Unicode_Result :: enum {
    Conversion_Ok;
    Source_Exhausted;
    Source_Illegal;
}

Unicode_Replacement_Char :: 0x0000FFFD;
Unicode_Max_BMP          :: 0x0000FFFF;
Unicode_Max_UTF16        :: 0x0010FFFF;
Unicode_Max_UTF32        :: 0x7FFFFFFF;

UTF8_Trailing_Bytes :: u8.[
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
    1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1, 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,
    2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2, 3,3,3,3,3,3,3,3,4,4,4,4,5,5,5,5,
];

UTF8_Inital_Byte_Mask :: u8.[ 0x7F, 0x1F, 0x0F, 0x07, 0x03, 0x01 ];

Offsets_From_UTF8 : [6] u32 : .[
    0x00000000, 0x00003080, 0x000E2080, 
    0x03C82080, 0xFA082080, 0x82082080,
];

First_Byte_Mark : [7] u8 : .[ 0x00, 0x00, 0xC0, 0xE0, 0xF0, 0xF8, 0xFC ];

character_utf8_to_utf32 :: (s: *u8, source_length: s64, $strict := false) -> u32, s64, Unicode_Result {
    continuation_bytes := UTF8_Trailing_Bytes[s[0]];

    if continuation_bytes + 1 > source_length {
        return Unicode_Replacement_Char, source_length, .Source_Exhausted;
    }

    ch: u32 = s[0] & UTF8_Inital_Byte_Mask[continuation_bytes];

    for 1..continuation_bytes {  // Do nothing if it is 0.
        ch = ch << 6;
        #if strict { if s[it] & 0xC0 != 0x80 then return Unicode_Replacement_Char, it - 1, .Source_Illegal; }
        ch |= s[it] & 0x3F;
    }

    #if strict {
        if ch > Unicode_Max_UTF16 ||
          (SURROGATES_START <= ch && ch <= SURROGATES_END) ||
          (ch <= 0x0000007F && continuation_bytes != 0) ||
          (ch <= 0x000007FF && continuation_bytes != 1) ||
          (ch <= 0x0000FFFF && continuation_bytes != 2) ||
          continuation_bytes > 3 {
            return Unicode_Replacement_Char, continuation_bytes+1, .Source_Illegal;
        }
    }

    if ch > Unicode_Max_UTF32 {
        ch = Unicode_Replacement_Char;
    }

    return ch, continuation_bytes+1, Unicode_Result.Conversion_Ok;
}


// Based on ConvertUTF.h reference implementation.
character_utf32_to_utf8 :: (ch: u32) -> string {
    count := 0;
         if ch < 0x80                count = 1;
    else if ch < 0x800               count = 2;
    else if ch < 0x10000             count = 3;
    else if ch <= Unicode_Max_UTF16  count = 4;
    else {
        count = 3;
        ch = Unicode_Replacement_Char;
    }

    // @Cleanup: We really are taking a dependency on Basic just for this?
    s := Basic.alloc_string(count);

    Byte_Mask :: 0xBF;
    Byte_Mark :: 0x80; 

    if count == {
        case 4; s.data[3] = xx (ch | byteMark) & byteMask; ch = ch >> 6; #through;
        case 3; s.data[2] = xx (ch | byteMark) & byteMask; ch = ch >> 6; #through;
        case 2; s.data[1] = xx (ch | byteMark) & byteMask; ch = ch >> 6; #through;
        case 1; s.data[0] = xx (ch | firstByteMark[count]);
    }

    return s;
}


unicode_next_character :: (s: *u8) -> *u8 {
    bytes_for_this_character := 1 + UTF8_Trailing_Bytes[<< s];
    return s + bytes_for_this_character;
}

utf8_next_character :: (s: *string) -> code: u32, success: Unicode_Result {
    code, bytes, success := character_utf8_to_utf32(s.data, s.count);

    s.data  += bytes;
    s.count -= bytes;
    Basic.assert(s.count >= 0);

    return code, success;
}
