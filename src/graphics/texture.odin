package graphics

import "core:log"

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
    texture_cache[path] = Texture{tex = texture, ref_count = 1}
    return &texture_cache[path]
}

TextureDestroy :: proc(tex: ^Texture) {
    if tex.identifier not_in texture_cache {
        return
    }

    texture := texture_cache[tex.identifier]
    texture.ref_count -= 1

    if tex.ref_count == 0 {
        log.debugf("Unload texture: %s", tex.identifier)

        delete_key(&texture_cache, tex.identifier)
        rl.UnloadTexture(texture.tex)
    }
}

InitTextureCache :: proc() {
    log.debugf("Init texture cache")

    texture_cache = make(map[string]Texture)
}

DestroyTextureCache :: proc() {
    log.debugf("Destroy texture cache")

    for _, &texture in texture_cache {
        if texture.ref_count > 0 {
            TextureDestroy(&texture)
        }
    }

    delete(texture_cache)
}
