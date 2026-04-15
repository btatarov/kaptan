package main

import "core:fmt"
import "core:os"

main :: proc() {
    fmt.println("Running", os.args[1])
}
