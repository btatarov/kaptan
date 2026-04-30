package graphics

import "core:log"
import "core:strings"

import rl "vendor:raylib"

Texture :: struct {
    tex:        rl.Texture2D,
    identifier: string,
    ref_count:  i32,
}

@(private="file") texture_cache: map[string]Texture

TextureInit :: proc(cpath: cstring) -> ^Texture {
    path := string(cpath)

    if path in texture_cache {
        tex := &texture_cache[path]
        tex.ref_count += 1
        return tex
    }

    log.debugf("Load texture: %s", path)

    texture := rl.LoadTexture(cpath)
    identifier := strings.clone(path)
    texture_cache[identifier] = Texture{tex = texture, identifier = identifier, ref_count = 1}
    return &texture_cache[identifier]
}

TextureDestroy :: proc(tex: ^Texture) {
    if tex.identifier not_in texture_cache {
        return
    }

    tex.ref_count -= 1

    if tex.ref_count == 0 {
        log.debugf("Unload texture: %s", tex.identifier)

        identifier := tex.identifier
        rl.UnloadTexture(tex.tex)
        delete_key(&texture_cache, identifier)
        delete(identifier)
    }
}

InitTextureCache :: proc() {
    log.debugf("Init texture cache")

    texture_cache = make(map[string]Texture)
}

DestroyTextureCache :: proc() {
    log.debugf("Destroy texture cache")

    for _, &texture in texture_cache {
        log.debugf("Unload texture: %s", texture.identifier)

        rl.UnloadTexture(texture.tex)
        delete(texture.identifier)
    }

    delete(texture_cache)
}
