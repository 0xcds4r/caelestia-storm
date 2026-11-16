#version 310 es
precision highp float;

layout(location = 0) in highp vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    highp vec2 resolution;
    float density;
    float wind;
    float flakeSize;
    float strength;
    float time;
} ubuf;

highp float hash(highp vec2 p) {
    p = fract(p * vec2(123.34, 345.45));
    p += dot(p, p + 34.345);
    return fract(p.x * p.y);
}

highp float layer(highp vec2 uv, highp float cells, highp float speed, highp float radius, highp float seed) {
    highp vec2 grid = uv * cells;
    highp vec2 cell = floor(grid);
    highp vec2 local = fract(grid);
    highp float sum = 0.0;

    for (int y = -1; y <= 1; ++y) {
        for (int x = -1; x <= 1; ++x) {
            highp vec2 offset = vec2(float(x), float(y));
            highp vec2 id = cell + offset + seed;

            highp float h1 = hash(id);
            highp float h2 = hash(id + vec2(11.3, 4.7));
            highp float h3 = hash(id + vec2(7.9, 23.1));

            if (h3 > ubuf.density)
                continue;

            highp float r = radius * mix(0.55, 1.45, h1) * ubuf.flakeSize;
            highp float px = fract(h2 + ubuf.wind * ubuf.time * 0.45);
            highp float py = fract(h1 + ubuf.time * speed * (0.35 + 0.65 * h3));

            highp vec2 delta = local - (offset + vec2(px, py));
            sum += (1.0 - smoothstep(r * 0.55, r, length(delta))) * (0.45 + 0.55 * h3);
        }
    }

    return sum;
}

void main() {
    highp vec2 res = max(ubuf.resolution, vec2(1.0, 1.0));
    highp vec2 p = qt_TexCoord0 * vec2(res.x / res.y, 1.0);

    highp float flakes = 0.0;
    flakes += layer(p, 10.0, 0.28, 0.075, 0.0) * 0.55;
    flakes += layer(p, 20.0, 0.55, 0.045, 31.0) * 0.75;
    flakes += layer(p, 38.0, 0.95, 0.028, 71.0) * 0.95;

    highp float alpha = clamp(flakes * ubuf.strength, 0.0, 1.0) * ubuf.qt_Opacity;

    // Qt Quick blends premultiplied alpha: white must be scaled by the alpha
    fragColor = vec4(vec3(alpha), alpha);
}
