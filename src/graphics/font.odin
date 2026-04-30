package graphics

import "core:fmt"
import "core:log"
import "core:strings"

import rl "vendor:raylib"

FontResource :: struct {
    font:       rl.Font,
    identifier: string,
    ref_count:  i32,
}

@(private="file") font_cache: map[string]^FontResource

FontInit :: proc(path: cstring, font_size: i32) -> ^FontResource {
    identifier := fmt.tprintf("%s:%d", path, font_size)

    if identifier in font_cache {
        resource := font_cache[identifier]
        resource.ref_count += 1
        return resource
    }

    log.debugf("Load font: %s", identifier)

    font := rl.LoadFontEx(path, font_size, nil, 0)
    resource_identifier := strings.clone(identifier)
    resource := new(FontResource)
    resource^ = FontResource{font = font, identifier = resource_identifier, ref_count = 1}
    font_cache[resource_identifier] = resource
    return resource
}

FontDestroy :: proc(resource: ^FontResource) {
    if resource.identifier not_in font_cache {
        return
    }

    resource.ref_count -= 1

    if resource.ref_count == 0 {
        log.debugf("Unload font: %s", resource.identifier)

        identifier := resource.identifier
        rl.UnloadFont(resource.font)
        delete_key(&font_cache, identifier)
        delete(identifier)
        free(resource)
    }
}

InitFontCache :: proc() {
    log.debugf("Init font cache")

    font_cache = make(map[string]^FontResource)
}

DestroyFontCache :: proc() {
    log.debugf("Destroy font cache")

    for _, resource in font_cache {
        log.debugf("Unload font: %s", resource.identifier)

        rl.UnloadFont(resource.font)
        delete(resource.identifier)
        free(resource)
    }

    delete(font_cache)
}
