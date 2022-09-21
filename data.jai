Color :: struct {
    r, g, b, a: float32;
}

Color8 :: struct {
    r, g, b, a: u8;
}

Colors :: struct #type_info_none {
    Transparent             :: Color.{1, 1, 1, 0};
    Alice_Blue              :: Color.{0.9412, 0.9725, 1, 1};      // #F0F8FF
    Antique_White           :: Color.{0.9804, 0.9216, 0.8431, 1}; // #FAEBD7
    Aqua                    :: Color.{0, 1, 1, 1};                // #00FFFF
    Aquamarine              :: Color.{0.498, 1, 0.8314, 1};       // #7FFFD4
    Azure                   :: Color.{0.9412, 1, 1, 1};           // #F0FFFF
    Beige                   :: Color.{0.9608, 0.9608, 0.8627, 1}; // #F5F5DC
    Bisque                  :: Color.{1, 0.8941, 0.7686, 1};      // #FFE4C4
    Black                   :: Color.{0, 0, 0, 1};                // #000000
    Blanched_Almond         :: Color.{1, 0.9216, 0.8039, 1};      // #FFEBCD
    Blue                    :: Color.{0, 0, 1, 1};                // #0000FF
    Blue_Violet             :: Color.{0.5412, 0.1686, 0.8863, 1}; // #8A2BE2
    Brown                   :: Color.{0.6471, 0.1647, 0.1647, 1}; // #A52A2A
    Burly_Wood              :: Color.{0.8706, 0.7216, 0.5294, 1}; // #DEB887
    Cadet_Blue              :: Color.{0.3725, 0.6196, 0.6275, 1}; // #5F9EA0
    Chartreuse              :: Color.{0.498, 1, 0, 1};            // #7FFF00
    Chocolate               :: Color.{0.8235, 0.4118, 0.1176, 1}; // #D2691E
    Coral                   :: Color.{1, 0.498, 0.3137, 1};       // #FF7F50
    Cornflower_Blue         :: Color.{0.3922, 0.5843, 0.9294, 1}; // #6495ED
    Cornsilk                :: Color.{1, 0.9725, 0.8627, 1};      // #FFF8DC
    Crimson                 :: Color.{0.8627, 0.0784, 0.2353, 1}; // #DC143C
    Cyan                    :: Color.{0, 1, 1, 1};                // #00FFFF
    Dark_Blue               :: Color.{0, 0, 0.5451, 1};           // #00008B
    Dark_Cyan               :: Color.{0, 0.5451, 0.5451, 1};      // #008B8B
    Dark_Golden_Rod         :: Color.{0.7216, 0.5255, 0.0431, 1}; // #B8860B
    Dark_Grey               :: Color.{0.6627, 0.6627, 0.6627, 1}; // #A9A9A9
    Dark_Green              :: Color.{0, 0.3922, 0, 1};           // #006400
    Dark_Khaki              :: Color.{0.7412, 0.7176, 0.4196, 1}; // #BDB76B
    Dark_Magenta            :: Color.{0.5451, 0, 0.5451, 1};      // #8B008B
    Dark_Olive_Green        :: Color.{0.3333, 0.4196, 0.1843, 1}; // #556B2F
    Darkorange              :: Color.{1, 0.549, 0, 1};            // #FF8C00
    Dark_Orchid             :: Color.{0.6, 0.1961, 0.8, 1};       // #9932CC
    Dark_Red                :: Color.{0.5451, 0, 0, 1};           // #8B0000
    Dark_Salmon             :: Color.{0.9137, 0.5882, 0.4784, 1}; // #E9967A
    Dark_Sea_Green          :: Color.{0.5608, 0.7373, 0.5608, 1}; // #8FBC8F
    Dark_Slate_Blue         :: Color.{0.2824, 0.2392, 0.5451, 1}; // #483D8B
    Dark_Slate_Grey         :: Color.{0.1843, 0.3098, 0.3098, 1}; // #2F4F4F
    Dark_Turquoise          :: Color.{0, 0.8078, 0.8196, 1};      // #00CED1
    Dark_Violet             :: Color.{0.5804, 0, 0.8275, 1};      // #9400D3
    Deep_Pink               :: Color.{1, 0.0784, 0.5765, 1};      // #FF1493
    Deep_Sky_Blue           :: Color.{0, 0.749, 1, 1};            // #00BFFF
    Dim_Gray                :: Color.{0.4118, 0.4118, 0.4118, 1}; // #696969
    Dodger_Blue             :: Color.{0.1176, 0.5647, 1, 1};      // #1E90FF
    Fire_Brick              :: Color.{0.698, 0.1333, 0.1333, 1};  // #B22222
    Floral_White            :: Color.{1, 0.9804, 0.9412, 1};      // #FFFAF0
    Forest_Green            :: Color.{0.1333, 0.5451, 0.1333, 1}; // #228B22
    Fuchsia                 :: Color.{1, 0, 1, 1};                // #FF00FF
    Gainsboro               :: Color.{0.8627, 0.8627, 0.8627, 1}; // #DCDCDC
    Ghost_White             :: Color.{0.9725, 0.9725, 1, 1};      // #F8F8FF
    Gold                    :: Color.{1, 0.8431, 0, 1};           // #FFD700
    Golden_Rod              :: Color.{0.8549, 0.6471, 0.1255, 1}; // #DAA520
    Grey                    :: Color.{0.502, 0.502, 0.502, 1};    // #808080
    Green                   :: Color.{0, 0.502, 0, 1};            // #008000
    Green_Yellow            :: Color.{0.6784, 1, 0.1843, 1};      // #ADFF2F
    Honey_Dew               :: Color.{0.9412, 1, 0.9412, 1};      // #F0FFF0
    Hot_Pink                :: Color.{1, 0.4118, 0.7059, 1};      // #FF69B4
    Indian_Red              :: Color.{0.8039, 0.3608, 0.3608, 1}; // #CD5C5C
    Indigo                  :: Color.{0.2941, 0, 0.5098, 1};      // #4B0082
    Ivory                   :: Color.{1, 1, 0.9412, 1};           // #FFFFF0
    Khaki                   :: Color.{0.9412, 0.902, 0.549, 1};   // #F0E68C
    Lavender                :: Color.{0.902, 0.902, 0.9804, 1};   // #E6E6FA
    Lavender_Blush          :: Color.{1, 0.9412, 0.9608, 1};      // #FFF0F5
    Lawn_Green              :: Color.{0.4863, 0.9882, 0, 1};      // #7CFC00
    Lemon_Chiffon           :: Color.{1, 0.9804, 0.8039, 1};      // #FFFACD
    Light_Blue              :: Color.{0.6784, 0.8471, 0.902, 1};  // #ADD8E6
    Light_Coral             :: Color.{0.9412, 0.502, 0.502, 1};   // #F08080
    Light_Cyan              :: Color.{0.8784, 1, 1, 1};           // #E0FFFF
    Light_Golden_Rod_Yellow :: Color.{0.9804, 0.9804, 0.8235, 1}; // #FAFAD2
    Light_Grey              :: Color.{0.8275, 0.8275, 0.8275, 1}; // #D3D3D3
    Light_Green             :: Color.{0.5647, 0.9333, 0.5647, 1}; // #90EE90
    Light_Pink              :: Color.{1, 0.7137, 0.7569, 1};      // #FFB6C1
    Light_Salmon            :: Color.{1, 0.6275, 0.4784, 1};      // #FFA07A
    Light_Sea_Green         :: Color.{0.1255, 0.698, 0.6667, 1};  // #20B2AA
    Light_Sky_Blue          :: Color.{0.5294, 0.8078, 0.9804, 1}; // #87CEFA
    Light_Slate_Grey        :: Color.{0.4667, 0.5333, 0.6, 1};    // #778899
    Light_Steel_Blue        :: Color.{0.6902, 0.7686, 0.8706, 1}; // #B0C4DE
    Light_Yellow            :: Color.{1, 1, 0.8784, 1};           // #FFFFE0
    Lime                    :: Color.{0, 1, 0, 1};                // #00FF00
    Lime_Green              :: Color.{0.1961, 0.8039, 0.1961, 1}; // #32CD32
    Linen                   :: Color.{0.9804, 0.9412, 0.902, 1};  // #FAF0E6
    Magenta                 :: Color.{1, 0, 1, 1};                // #FF00FF
    Maroon                  :: Color.{0.502, 0, 0, 1};            // #800000
    Medium_Aqua_Marine      :: Color.{0.4, 0.8039, 0.6667, 1};    // #66CDAA
    Medium_Blue             :: Color.{0, 0, 0.8039, 1};           // #0000CD
    Medium_Orchid           :: Color.{0.7294, 0.3333, 0.8275, 1}; // #BA55D3
    Medium_Purple           :: Color.{0.5765, 0.4392, 0.8471, 1}; // #9370D8
    Medium_Sea_Green        :: Color.{0.2353, 0.702, 0.4431, 1};  // #3CB371
    Medium_Slate_Blue       :: Color.{0.4824, 0.4078, 0.9333, 1}; // #7B68EE
    Medium_Spring_Green     :: Color.{0, 0.9804, 0.6039, 1};      // #00FA9A
    Medium_Turquoise        :: Color.{0.2824, 0.8196, 0.8, 1};    // #48D1CC
    Medium_Violet_Red       :: Color.{0.7804, 0.0824, 0.5216, 1}; // #C71585
    Midnight_Blue           :: Color.{0.098, 0.098, 0.4392, 1};   // #191970
    Mint_Cream              :: Color.{0.9608, 1, 0.9804, 1};      // #F5FFFA
    Misty_Rose              :: Color.{1, 0.8941, 0.8824, 1};      // #FFE4E1
    Moccasin                :: Color.{1, 0.8941, 0.7098, 1};      // #FFE4B5
    Navajo_White            :: Color.{1, 0.8706, 0.6784, 1};      // #FFDEAD
    Navy                    :: Color.{0, 0, 0.502, 1};            // #000080
    Old_Lace                :: Color.{0.9922, 0.9608, 0.902, 1};  // #FDF5E6
    Olive                   :: Color.{0.502, 0.502, 0, 1};        // #808000
    Olive_Drab              :: Color.{0.4196, 0.5569, 0.1373, 1}; // #6B8E23
    Orange                  :: Color.{1, 0.6471, 0, 1};           // #FFA500
    Orange_Red              :: Color.{1, 0.2706, 0, 1};           // #FF4500
    Orchid                  :: Color.{0.8549, 0.4392, 0.8392, 1}; // #DA70D6
    Pale_Golden_Rod         :: Color.{0.9333, 0.9098, 0.6667, 1}; // #EEE8AA
    Pale_Green              :: Color.{0.5961, 0.9843, 0.5961, 1}; // #98FB98
    Pale_Turquoise          :: Color.{0.6863, 0.9333, 0.9333, 1}; // #AFEEEE
    Pale_Violet_Red         :: Color.{0.8471, 0.4392, 0.5765, 1}; // #D87093
    Papaya_Whip             :: Color.{1, 0.9373, 0.8353, 1};      // #FFEFD5
    Peach_Puff              :: Color.{1, 0.8549, 0.7255, 1};      // #FFDAB9
    Peru                    :: Color.{0.8039, 0.5216, 0.2471, 1}; // #CD853F
    Pink                    :: Color.{1, 0.7529, 0.7961, 1};      // #FFC0CB
    Plum                    :: Color.{0.8667, 0.6275, 0.8667, 1}; // #DDA0DD
    Powder_Blue             :: Color.{0.6902, 0.8784, 0.902, 1};  // #B0E0E6
    Purple                  :: Color.{0.502, 0, 0.502, 1};        // #800080
    Red                     :: Color.{1, 0, 0, 1};                // #FF0000
    Rosy_Brown              :: Color.{0.7373, 0.5608, 0.5608, 1}; // #BC8F8F
    Royal_Blue              :: Color.{0.2549, 0.4118, 0.8824, 1}; // #4169E1
    Saddle_Brown            :: Color.{0.5451, 0.2706, 0.0745, 1}; // #8B4513
    Salmon                  :: Color.{0.9804, 0.502, 0.4471, 1};  // #FA8072
    Sandy_Brown             :: Color.{0.9569, 0.6431, 0.3765, 1}; // #F4A460
    Sea_Green               :: Color.{0.1804, 0.5451, 0.3412, 1}; // #2E8B57
    Sea_Shell               :: Color.{1, 0.9608, 0.9333, 1};      // #FFF5EE
    Sienna                  :: Color.{0.6275, 0.3216, 0.1765, 1}; // #A0522D
    Silver                  :: Color.{0.7529, 0.7529, 0.7529, 1}; // #C0C0C0
    Sky_Blue                :: Color.{0.5294, 0.8078, 0.9216, 1}; // #87CEEB
    Slate_Blue              :: Color.{0.4157, 0.3529, 0.8039, 1}; // #6A5ACD
    Slate_Grey              :: Color.{0.4392, 0.502, 0.5647, 1};  // #708090
    Snow                    :: Color.{1, 0.9804, 0.9804, 1};      // #FFFAFA
    Spring_Green            :: Color.{0, 1, 0.498, 1};            // #00FF7F
    Steel_Blue              :: Color.{0.2745, 0.5098, 0.7059, 1}; // #4682B4
    Tan                     :: Color.{0.8235, 0.7059, 0.549, 1};  // #D2B48C
    Teal                    :: Color.{0, 0.502, 0.502, 1};        // #008080
    Thistle                 :: Color.{0.8471, 0.749, 0.8471, 1};  // #D8BFD8
    Tomato                  :: Color.{1, 0.3882, 0.2784, 1};      // #FF6347
    Turquoise               :: Color.{0.251, 0.8784, 0.8157, 1};  // #40E0D0
    Violet                  :: Color.{0.9333, 0.5098, 0.9333, 1}; // #EE82EE
    Wheat                   :: Color.{0.9608, 0.8706, 0.702, 1};  // #F5DEB3
    White                   :: Color.{1, 1, 1, 1};                // #FFFFFF
    White_Smoke             :: Color.{0.9608, 0.9608, 0.9608, 1}; // #F5F5F5
    Yellow                  :: Color.{1, 1, 0, 1};                // #FFFF00
    Yellow_Green            :: Color.{0.6039, 0.8039, 0.1961, 1}; // #9ACD32
}

ONE_OVER_255 : float32 : 1.0 / 255;

alloc_color :: (r: float32, g: float32, b: float32, a: float32) -> Color {
    c: Color = ---;
    c.r = r;
    c.g = g;
    c.b = b;
    c.a = a;
    return c;
}

alloc_color8 :: (r: u8, g: u8, b: u8, a: u8) -> Color8 {
    c: Color8 = ---;
    c.r = r;
    c.g = g;
    c.b = b;
    c.a = a;
    return c;
}

to_color :: (in: Color8) -> Color {
    out: Color = ---;
    out.r = (cast(float32) in.r) * ONE_OVER_255;
    out.g = (cast(float32) in.g) * ONE_OVER_255;
    out.b = (cast(float32) in.b) * ONE_OVER_255;
    out.a = (cast(float32) in.a) * ONE_OVER_255;
    return out;
}
