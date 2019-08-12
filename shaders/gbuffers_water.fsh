#version 450 compatibility
#include "/lib/Settings.glsl"

////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////ORIGINAL SHADER SPROUT BY SILVIA//////////////////////////////////
/////Anyone downloading this has permission to edit anything within for personal use, but //////////
/////////////////////redistribution of any kind requires explicit permission.///////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

layout (location = 0) out vec4 colortex0write;
layout (location = 1) out vec4 colortex1write;
layout (location = 2) out vec4 colortex2write;



varying vec2 texcoord;
varying vec2 vertexlightmaps;

varying mat3 tbnMatrix;
varying float isWater;
varying vec3 tangentViewSpace;
varying vec3 color;
varying vec3 normals;
varying vec3 worldspace;
uniform float frameTimeCounter;

uniform mat4 gbufferModelView;

uniform sampler2D texture;

#define GOLDEN_ANGLE_RADIAN 2.39996
 
float wave(vec2 uv, vec2 emitter, float speed, float phase){
    float dst = distance(uv, emitter);
    return pow((0.5 + 0.5 * sin(dst * phase - frameTimeCounter * speed)), 5.0);
}
 
float getwaves(vec2 uv){
    float w = 0.0;
    float sw = 0.5;
    float iter = 0.3;
    float ww = 1.0;
    uv += frameTimeCounter * 0.01;
    // it seems its absolutely fastest way for water height function that looks real
    for(int i=0;i<20;i++){
        w += ww * wave(uv * 0.07 , vec2(sin(iter), cos(iter)) * 10.0, 2.0 + iter * 0.08, 2.0 + iter * 3.0);
        sw += ww;
        ww = mix(ww, 0.0115, 0.4);
        iter += GOLDEN_ANGLE_RADIAN;
    }
   
    return w / sw;
}
 
vec2 water_calculateParallax(vec2 position, vec3 direction) {
    const int iterations    = Water_Parallax_Iterations;
    const float rIterations = 1.0 / iterations;
 
    const float depth = 3.0 * Water_Parallax_Depth;
    float dist = inversesqrt(dot(direction, direction));
 
    vec2 offset = (direction.xy * rIterations) * (dist * depth);
 
    for(int i = 0; i < iterations; ++i) {
        position = getwaves(position) * offset - position;
    }
 
    return position;
}
 
// Procedural texture generation for the water
vec3 water(vec2 uv, mat3 tbn, vec3 tangentVector, vec3 viewVector, inout vec3 normal) {
    const vec3 waterCol  = vec3(0.0, 0.4453, 0.7305) * 0.6;
    const vec3 waterCol2 = vec3(0.0, 0.5180, 0.6758) * 0.55;
 
    uv *= vec2(0.51);
 
    uv = water_calculateParallax(uv, tangentVector);
 
    const float delta  = 0.08;
    const float iDelta = 1.0 / delta;
 
    float sampleC = getwaves(uv                   );
    float sampleX = getwaves(uv + vec2(delta, 0.0));
    float sampleY = getwaves(uv + vec2(0.0, delta));
 
    vec3 waveNormals = normalize(vec3(
        (sampleC - sampleX) * iDelta,
        (sampleC - sampleY) * iDelta,
        1.0
    )) * tbn;
 
    normal = waveNormals;

    float multiplier = 0.7;
    #ifdef Color_Compression
    multiplier *= 0.6;
    #endif
 
    return mix(waterCol, waterCol2, smoothstep(-0.1, -0.58, dot(waveNormals, viewVector))) * (Water_Brightness * 2.9) * multiplier * (vertexlightmaps.x + vertexlightmaps.y);
}

void main() {

vec3 normalTangentSpace =  normals;
vec3 viewSpace = mat3(gbufferModelView) * worldspace;

vec4 albedo = texture2D(texture, texcoord);

if (isWater > 0.5) albedo = vec4(water(worldspace.xz - worldspace.y, tbnMatrix, tangentViewSpace, viewSpace, normalTangentSpace), 0.95);

albedo.rgb *= color;

colortex0write = albedo;
colortex1write = vec4(vertexlightmaps, 1, 1);
colortex2write = vec4(normalTangentSpace * 0.5 + 0.5, 1);
}