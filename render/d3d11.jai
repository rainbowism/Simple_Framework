driver_type   := D3D_DRIVER_TYPE.NULL;
feature_level := D3D_FEATURE_LEVEL._11_0;
d3d_device:         *ID3D11Device;
d3d_context:        *ID3D11DeviceContext;
swap_chain:         *IDXGISwapChain;
render_target_view: *ID3D11RenderTargetView;
depth_stencil_view: *ID3D11DepthStencilView;

init_d3d11_device :: (width: s32, height: s32, msaa: bool) -> bool {
    hwnd := get_hwnd();

    hr: HRESULT = S_OK;

    flags: D3D11_CREATE_DEVICE_FLAG;
    #if Debug  flags |= .DEBUG;

    driver_types   := D3D_DRIVER_TYPE.[.HARDWARE, .WARP, .REFERENCE];
    feature_levels := D3D_FEATURE_LEVEL.[._11_1, ._11_0, ._10_1, ._10_0];

    for 0..driver_types.count-1 {
        driver_type = driver_types[it];
        hr = D3D11CreateDevice(null, driver_type, null, flags, feature_levels.data, feature_levels.count, D3D11_SDK_VERSION, *d3d_device, *feature_level, *d3d_context);

        if hr == E_INVALIDARG {
            // DirectX 11.0 platforms will not recognize D3D_FEATURE_LEVEL_11_1 so we need to retry without it.
            hr = D3D11CreateDevice(null, driver_type, null, flags, feature_levels.data + 1, feature_levels.count - 1, D3D11_SDK_VERSION, *d3d_device, *feature_level, *d3d_context);
        }

        if SUCCEEDED(hr)  break;
    }
    if FAILED(hr) {
        panic(.Render, "D3D11CreateDevice failed.\n");
        return false;
    }
    assert(d3d_device != null, "Failed to create D3D11 device.");

    dxgi_factory: *IDXGIFactory1;
    {
        dxgi_device: *IDXGIDevice;
        hr = IUnknown_QueryInterface(d3d_device, *uid(IDXGIDevice_UUID), xx *dxgi_device);
        // You could also use the vtable helper instead of the C api:
        // hr = vtable(d3d_device).QueryInterface(d3d_device, *uid(IDXGIDevice_UUID), xx *dxgi_device);
        if SUCCEEDED(hr) {
            adapter: *IDXGIAdapter;
            hr = IDXGIDevice_GetAdapter(dxgi_device, *adapter);
            if SUCCEEDED(hr) {
                hr = IDXGIObject_GetParent(adapter, *uid(IDXGIFactory1_UUID), xx *dxgi_factory);
                IUnknown_Release(adapter);
            }
            IUnknown_Release(dxgi_device);
        } else {
            panic(.Render, "IUnknown_QueryInterface failed\n");
            return false;
        }
    }
    if FAILED(hr) {
        panic(.Render, "IDXGIDevice_GetAdapter failed.\n");
        return false;
    }
    defer IUnknown_Release(dxgi_factory);

    // Create swap chain
    {
        // DirectX 11.0 systems
        sd: DXGI_SWAP_CHAIN_DESC;
        sd.BufferCount = 1;
        sd.BufferDesc.Width = xx width;
        sd.BufferDesc.Height = xx height;
        sd.BufferDesc.Format = .R8G8B8A8_UNORM;
        // sd.BufferDesc.Format = .B8G8R8A8_UNORM;
        sd.BufferDesc.RefreshRate.Numerator = 60;
        sd.BufferDesc.RefreshRate.Denominator = 1;
        sd.BufferUsage = .RENDER_TARGET_OUTPUT;
        sd.OutputWindow = hwnd;
        sd.SwapEffect = .DISCARD;
        sd.BufferCount = 1;
        if msaa {
            sd.SampleDesc.Count = 4;
            sd.SampleDesc.Quality = xx D3D11_STANDARD_MULTISAMPLE_QUALITY_LEVELS.STANDARD_MULTISAMPLE_PATTERN;
        } else {
            sd.SampleDesc.Count = 1;
            sd.SampleDesc.Quality = 0;
        }
        sd.Windowed = BOOL.TRUE;

        hr = IDXGIFactory_CreateSwapChain(dxgi_factory, d3d_device, *sd, *swap_chain);
        if FAILED(hr) {
            panic("IDXGIFactory_CreateSwapChain failed: %", hr);
            return false;
        }
    }

    // Note this tutorial doesn't handle full-screen swapchains so we block the ALT+ENTER shortcut
    IDXGIFactory_MakeWindowAssociation(dxgi_factory, hwnd, cast (u32) DXGI_MWA.NO_ALT_ENTER);

    if FAILED(hr) return false;

    back_buffer: *ID3D11Texture2D;
    hr = IDXGISwapChain_GetBuffer(swap_chain, 0, *uid(ID3D11Texture2D_UUID), xx *back_buffer);
    if FAILED(hr) {
        log_error("GetBuffer failed: %", hr);
        return false;
    }
    defer IUnknown_Release(back_buffer);

    hr = ID3D11Device_CreateRenderTargetView(d3d_device, back_buffer, null, *render_target_view);
    if FAILED(hr) {
        panic("ID3D11Device_CreateRenderTargetView failed: %", hr);
        return false;
    }

    {
        depth_stencil_desc: D3D11_TEXTURE2D_DESC;
        depth_stencil_desc.Width = xx width;
        depth_stencil_desc.Height = xx height;
        depth_stencil_desc.MipLevels = 1;
        depth_stencil_desc.ArraySize = 1;
        depth_stencil_desc.Format = .DXGI_FORMAT_D24_UNORM_S8_UINT;
        if msaa {
            depth_stencil_desc.SampleDesc.Count = 4;
            depth_stencil_desc.SampleDesc.Quality = xx D3D11_STANDARD_MULTISAMPLE_QUALITY_LEVELS.STANDARD_MULTISAMPLE_PATTERN;
        } else {
            depth_stencil_desc.SampleDesc.Count = 1;
            depth_stencil_desc.SampleDesc.Quality = 0;
        }
        depth_stencil_desc.Usage = .D3D11_USAGE_DEFAULT;
        depth_stencil_desc.BindFlags = .D3D11_BIND_DEPTH_STENCIL;

        depth_stencil_buffer: *ID3D11Texture2D;
        hr = ID3D11Device_CreateTexture2D(d3d_device, *depth_stencil_desc, null, *depth_stencil_buffer);
        if FAILED(hr) {
            panic("ID3D11Device_CreateRenderTargetView failed: %", hr);
            return false;
        }
        hr = ID3D11Device_CreateDepthStencilView(d3d_device, depth_stencil_buffer, null, *depth_stencil_view);
        if FAILED(hr) {
            panic("ID3D11Device_CreateRenderTargetView failed: %", hr);
            return false;
        }
    }

    ID3D11DeviceContext_OMSetRenderTargets(d3d_context, 1, *render_target_view, depth_stencil_view);

    return true;
}

d3d11_render_target_view :: (user_data: *void) -> *void #c_call {
    new_context: Context;
    push_context new_context{
        assert(user_data == cast(*void) 0xDEADBEEF);
        return render_target_view;
    }
}

d3d11_depth_stencil_view :: (user_data: *void) -> *void #c_call {
    new_context: Context;
    push_context new_context{
        assert(user_data == cast(*void) 0xDEADBEEF);
        return depth_stencil_view;
    }
}

d3d11_present :: (vsync: u32) {
    hr := IDXGISwapChain_Present(swap_chain, vsync, 0);
    if FAILED(hr) {
        warn("IDXGISwapChain_Present failed: %", hr);
    }
}
