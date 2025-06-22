package main

import "base:runtime"
import "core:fmt"
import "vendor:glfw"

WINDOW_WIDTH :: 640
WINDOW_HEIGHT :: 480
WINDOW_TITLE :: "Flectris"

GlobalContext :: struct {
	window: glfw.WindowHandle,
}
gc: GlobalContext

main :: proc() {
	{ 	// glfw init
		glfw.SetErrorCallback(error_callback)

		ok := glfw.Init()
		if !ok {
			panic("glfw.Init failed")
		}
	}
	defer glfw.Terminate()

	{ 	// create window
		glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API)
		glfw.WindowHint(glfw.RESIZABLE, false)
		gc.window = glfw.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, WINDOW_TITLE, nil, nil)
		if gc.window == nil {
			panic("glfw.CreateWindow failed")
		}
	}
	defer {
		glfw.DestroyWindow(gc.window)
		gc.window = nil
	}
}

// ErrorProc              :: #type proc "c" (error: c.int, description: cstring)
error_callback :: proc "c" (error: i32, description: cstring) {
	context = runtime.default_context()
	fmt.eprintln("glfw error", error, description)
}
