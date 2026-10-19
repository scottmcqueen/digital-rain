// Metal shaders, compiled at runtime so the build needs only the Command Line Tools.
// Same passes as the web version: glyph scene, quarter-res bloom, composite.
let rainShaderSource = """
#include <metal_stdlib>
using namespace metal;

struct VOut { float4 pos [[position]]; float2 uv; };

vertex VOut vfull(uint vid [[vertex_id]]) {
    float2 p = float2((vid << 1) & 2, vid & 2);
    VOut o;
    o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
    o.uv = float2(p.x, 1.0 - p.y);   // texture space, origin top-left
    return o;
}

struct SceneU { float4 color; float2 grid; float2 atlasGrid; float time; float trail; float flicker; float ng; };
struct CompU  { float bloom; float door; float doorPx; float pad; };

float hash12(float2 p) {
    float3 q = fract(float3(p.xyx) * 0.1031);
    q += dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

fragment float4 fscene(VOut in [[stage_in]],
                       constant SceneU& u [[buffer(0)]],
                       texture2d<float> state [[texture(0)]],
                       texture2d<float> atlas [[texture(1)]]) {
    constexpr sampler sa(filter::linear, mip_filter::linear, address::clamp_to_edge);
    float2 cp = in.uv * u.grid;
    float2 cell = floor(cp), f = fract(cp);
    uint2 ci = uint2(min(cell, u.grid - 1.0));
    float2 s = state.read(ci).rg;          // r: time the cell was written, g: cursor flag
    float lead = s.y;
    float b = exp(-max(u.time - s.x, 0.0) / u.trail);
    float h = hash12(cell);
    float rate = mix(u.flicker * (0.4 + 1.2 * h), 14.0, lead);
    float epoch = fmod(floor(u.time * rate + h * 97.0) + floor(s.x * 37.0) * (1.0 - lead), 4096.0);
    float g = min(floor(hash12(cell + float2(epoch * 1.618, epoch * 0.731)) * u.ng), u.ng - 1.0);
    float2 a = float2(fmod(g, u.atlasGrid.x), floor(g / u.atlasGrid.x));
    float m = atlas.sample(sa, (a + f) / u.atlasGrid,
                           gradient2d(dfdx(cp) / u.atlasGrid, dfdy(cp) / u.atlasGrid)).r;
    float3 trail = u.color.rgb * pow(b, 1.7);
    float3 head = mix(u.color.rgb, float3(1.0), 0.78);
    return float4(mix(trail, head, lead) * m, 1.0);
}

fragment float4 fdown(VOut in [[stage_in]],
                      constant float2& texel [[buffer(0)]],
                      texture2d<float> t [[texture(0)]]) {
    constexpr sampler sl(filter::linear, address::clamp_to_edge);
    return 0.25 * (t.sample(sl, in.uv + float2(-texel.x, -texel.y)) + t.sample(sl, in.uv + float2(texel.x, -texel.y)) +
                   t.sample(sl, in.uv + float2(-texel.x,  texel.y)) + t.sample(sl, in.uv + float2(texel.x,  texel.y)));
}

fragment float4 fblur(VOut in [[stage_in]],
                      constant float2& dir [[buffer(0)]],
                      texture2d<float> t [[texture(0)]]) {
    constexpr sampler sl(filter::linear, address::clamp_to_edge);
    float3 c = t.sample(sl, in.uv).rgb * 0.227027;
    c += (t.sample(sl, in.uv + dir).rgb       + t.sample(sl, in.uv - dir).rgb)       * 0.1945946;
    c += (t.sample(sl, in.uv + dir * 2.0).rgb + t.sample(sl, in.uv - dir * 2.0).rgb) * 0.1216216;
    c += (t.sample(sl, in.uv + dir * 3.0).rgb + t.sample(sl, in.uv - dir * 3.0).rgb) * 0.054054;
    c += (t.sample(sl, in.uv + dir * 4.0).rgb + t.sample(sl, in.uv - dir * 4.0).rgb) * 0.016216;
    return float4(c, 1.0);
}

fragment float4 fcomp(VOut in [[stage_in]],
                      constant CompU& u [[buffer(0)]],
                      texture2d<float> scene [[texture(0)]],
                      texture2d<float> bloom [[texture(1)]]) {
    constexpr sampler sl(filter::linear, address::clamp_to_edge);
    float3 c = scene.sample(sl, in.uv).rgb + bloom.sample(sl, in.uv).rgb * u.bloom;
    float2 d = abs(fract(in.pos.xy / u.doorPx) - 0.5) * 2.0;
    float grid = max(smoothstep(0.5, 1.0, d.x), smoothstep(0.62, 1.0, d.y));
    c *= 1.0 - u.door * grid;
    float2 q = in.uv - 0.5;
    c *= 1.0 - dot(q, q) * 0.4;
    c = 1.0 - exp(-c * 1.9);
    return float4(c, 1.0);
}
"""
