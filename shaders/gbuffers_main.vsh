#extension GL_EXT_gpu_shader4 : enable
#include "/lib/Settings.glsl"

////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////ORIGINAL SHADER SPROUT BY SILVIA//////////////////////////////////
/////Anyone downloading this has permission to edit anything within for personal use, but //////////
/////////////////////redistribution of any kind requires explicit permission.///////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

attribute vec4 mc_Entity;
attribute vec4 at_tangent;
attribute vec4 mc_midTexCoord;

varying vec2 texcoord;
varying vec4 color;
varying vec2 vertexlightmaps;
varying mat3 TBN;
varying mat3x2 atlasTileInfo;
varying vec3 tangentViewSpace;
varying float matIDs;

uniform sampler2D texture;
uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;

#define atlasTileOffset     atlasTileInfo[0]
#define atlasTileSize       atlasTileInfo[1]
#define atlasTileResolution atlasTileInfo[2]


// Water
    #define WATER_FLOWING 8.0
    #define WATER_STILL   9.0

// Translucent
    #define LEAVES       18.0
    #define VINES       106.0
    #define TALLGRASS    31.0
    #define DANDELION    37.0
    #define ROSE         38.0
    #define WHEAT        59.0
    #define LILYPAD     111.0
    #define LEAVES2     161.0
    #define NEWFLOWERS  175.0
    #define NETHER_WART 115.0
    #define DEAD_BUSH    32.0
    #define CARROT      141.0
    #define POTATO      142.0
    #define COBWEB       30.0
    #define SUGAR_CANE   83.0
    #define BROWN_SHROOM 39.0
    #define RED_SHROOM   40.0

// Emitters
    #define TORCH        50.0
    #define FIRE         51.0
    #define LAVAFLOWING  10.0
    #define LAVASTILL    11.0
    #define GLOWSTONE    89.0
    #define SEA_LANTERN 169.0
    #define LAMP_ON     124.0
    #define BEACON      138.0
    #define END_ROD     198.0

vec2 haltonSequence(vec2 i, vec2 b) {
    vec2 f = vec2(1.0), r = vec2(0.0);
    while (i.x > 0.0 || i.y > 0.0) {
        f /= b;
        r += f * mod(i, b);
        i  = floor(i / b);
    }
    return r;
}

vec2 temporalJitter() {
    vec2 scale = 2.0 / vec2(viewWidth, viewHeight);
    return haltonSequence(vec2(frameCounter % 16), vec2(2.0, 3.0)) * scale + (-0.5 * scale);
}

void calculateMatIDs(out int materialIDs) {
    int IDs  = 0;
    float id = mc_Entity.x;

    // Water
    if (id == WATER_FLOWING || id == WATER_STILL) IDs = 1;

    // Translucent
    if (id == LEAVES || id == VINES || id == TALLGRASS || id == DANDELION || id == ROSE ||
        id == WHEAT || id == LILYPAD || id == LEAVES2 || id == NEWFLOWERS || id == NETHER_WART ||
        id == DEAD_BUSH || id == CARROT || id == POTATO || id == COBWEB || id == SUGAR_CANE ||
        id == BROWN_SHROOM || id == RED_SHROOM) IDs = 2;

    // Emitters
    if (id == TORCH || id == FIRE || id == LAVAFLOWING || id == LAVASTILL || id == GLOWSTONE ||
        id == SEA_LANTERN || id == LAMP_ON || id == BEACON || id == END_ROD) IDs = 3;

    materialIDs = IDs;
}

void main() {

vec3 normal   = gl_NormalMatrix * gl_Normal;
vec3 tangent  = gl_NormalMatrix * (at_tangent.xyz / at_tangent.w);
TBN = mat3(tangent, cross(tangent, normal), normal);

vec3 view = mat3(gl_ModelViewMatrix) * (gl_Vertex.xyz) + (gl_ModelViewMatrix)[3].xyz;

tangentViewSpace = view * TBN;

ivec2 textureResolution = textureSize2D(texture, 0);

atlasTileSize       = abs(gl_MultiTexCoord0.st - mc_midTexCoord.xy);
atlasTileOffset     = mc_midTexCoord.xy - atlasTileSize;
atlasTileSize      *= 2.0;

atlasTileResolution = round(atlasTileSize * textureResolution);
atlasTileSize       = atlasTileResolution / textureResolution;
atlasTileOffset     = round(atlasTileOffset * textureResolution) / textureResolution;

calculateMatIDs(matIDs);
gl_Position = ftransform();

gl_Position.xy = temporalJitter() * gl_Position.w + gl_Position.xy;

texcoord = mat2(gl_TextureMatrix[0]) * gl_MultiTexCoord0.st + gl_TextureMatrix[0][3].xy;

color = gl_Color;

vertexlightmaps = pow((gl_TextureMatrix[1] * gl_MultiTexCoord1).xy, vec2(1.0, 3.0));
vertexlightmaps = 16.0 - min(vec2(15.0), (vertexlightmaps - 0.5 / 16.0) * 16.0 * 16.0 / 15.0);
vertexlightmaps.x = pow(clamp(1.0 - pow(vertexlightmaps.x / 16.0, 4.0), 0.0, 1.0), 2.0) / (1.0 + vertexlightmaps.x * vertexlightmaps.x);
vertexlightmaps.y = 1.0 - vertexlightmaps.y / 16;
vertexlightmaps = sqrt(vertexlightmaps);
if(matIDs == 3) vertexlightmaps.x = 1.0;

}
