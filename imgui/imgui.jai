init_imgui :: () {
    ImGui_Impl_CreateContext();
    ImGui.StyleColorsDark();
    ImGui_Impl_Init(window.handle);
}

imgui_begin :: () {
    ImGui_Impl_NewFrame(window.handle, window.size.width, window.size.height, time.delta);
}

imgui_end :: () {
    ImGui.Render();
    ImGui_Impl_RenderDrawData(ImGui.GetDrawData());
}

#scope_file

ImGui :: #import "ImGui";
