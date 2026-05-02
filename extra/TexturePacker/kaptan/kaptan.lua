return {
    texture = '{{ texture.fullName }}',
    sprites = {
        {% for sprite in allSprites %}["{{ sprite.trimmedName }}"] = {
            source = {
                x = {{ sprite.frameRect.x }},
                y = {{ sprite.frameRect.y }},
                w = {{ sprite.frameRect.width }},
                h = {{ sprite.frameRect.height }}
            },
            frame = {
                w = {{ sprite.untrimmedSize.width }},
                h = {{ sprite.untrimmedSize.height }}
            },
            offset = {
                x = {{ sprite.cornerOffset.x }},
                y = {{ sprite.cornerOffset.y }}
            }
        }{% if not forloop.last %},
        {% endif %}{% endfor %}
    }
}
