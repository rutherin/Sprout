#extension GL_EXT_gpu_shader4 : enable
#include "/lib/settings.glsl"
#include "/lib/Utility.glsl"

////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////ORIGINAL SHADER SPROUT BY SILVIA//////////////////////////////////
/////Anyone downloading this has permission to edit anything within for personal use, but //////////
/////////////////////redistribution of any kind requires explicit permission.///////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

layout (location = 0) out vec4 colortex0write;
layout (location = 1) out vec4 colortex1write;
layout (location = 2) out vec4 colortex2write;
layout (location = 3) out vec4 colortex3write;



varying vec2 texcoord;
varying vec2 vertexlightmaps;
varying float matIDs;
varying vec4 color;
varying mat3 TBN;
varying mat3x2 atlasTileInfo;
varying vec3 tangentViewSpace;

uniform sampler2D texture;
uniform sampler2D specular;
uniform sampler2D normals;
uniform ivec2 atlasSize;
uniform vec4 entityColor;


#define atlasTileOffset     atlasTileInfo[0]
#define atlasTileSize       atlasTileInfo[1]
#define atlasTileResolution atlasTileInfo[2]


float maxof(vec2 x) { return max(x.x, x.y); }
float minof(vec2 x) { return min(x.x, x.y); }
float minof(vec3 x) { return min(x.x, min(x.y, x.z)); }

vec4 textureSmoothGrad(sampler2D t, vec2 x, vec2 textureSize, mat2 derivatives) {
    x *= vec2(textureSize);

    vec2 p = floor(x);
    vec2 f = fract(x);

    vec4 a = texture2DGrad(t, (p                 ) / vec2(textureSize), derivatives[0], derivatives[1]);
    vec4 b = texture2DGrad(t, (p + vec2(1.0, 0.0)) / vec2(textureSize), derivatives[0], derivatives[1]);
    vec4 c = texture2DGrad(t, (p + vec2(0.0, 1.0)) / vec2(textureSize), derivatives[0], derivatives[1]);
    vec4 d = texture2DGrad(t, (p + vec2(1.0, 1.0)) / vec2(textureSize), derivatives[0], derivatives[1]);

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec2 parallax_calculateCoordinate(vec2 textureCoordinates, mat2 textureCoordinateDerivatives, vec3 tangentViewVector, inout float parallaxShadow) {
    #ifndef Parallax_Occlusion
        return textureCoordinates;
    #endif

    if (tangentViewVector.z > 0.0) return textureCoordinates;

    ivec2 textureResolution = textureSize2D(texture, 0);

    mat2 derivatives = textureCoordinateDerivatives; derivatives[0] *= textureResolution; derivatives[1] *= textureResolution;
    float d = max(max(dot(derivatives[0], derivatives[0]), dot(derivatives[1], derivatives[1])), 1.0);
    vec2 atlasTileResolutionLod = atlasTileResolution * exp2(ceil(-0.5 * log2(d)));

    tangentViewVector.xy *= Parallax_Depth;
    tangentViewVector.y  *= atlasTileResolution.x / atlasTileResolution.y; // Tile aspect ratio - fixes snow layer sides
    vec2 texelDelta = tangentViewVector.xy * atlasTileResolutionLod;

    vec3 position = vec3((textureCoordinates - atlasTileOffset) / atlasTileSize, 1.0);
    float height;

    for (int i = 0; i < 256; ++i) {
        #ifdef Smooth_POM
            height = textureSmoothGrad(normals, fract(position.st) * atlasTileSize + atlasTileOffset, atlasSize, textureCoordinateDerivatives).a;
        #else
            height = texture2DGrad(normals, fract(position.st) * atlasTileSize + atlasTileOffset, textureCoordinateDerivatives[0], textureCoordinateDerivatives[1]).a;
        #endif

        // Calculate distance to the next two texels
        // xy = closest, zw = second closest
        vec4 texelCoordinates = fract(position.stst * atlasTileResolutionLod.stst);
        texelCoordinates = texelCoordinates * vec4(2.0, 2.0, 1.0, 1.0) + vec4(-1.0, -1.0, -0.5, -0.5);
        texelCoordinates = (texelCoordinates * sign(texelDelta).xyxy) * -0.5 + 0.5;

        vec4 distanceToNextTexelDirectional = texelCoordinates / abs(texelDelta).xyxy;
        float distanceToNextTexel = min(distanceToNextTexelDirectional.x, distanceToNextTexelDirectional.y);

        // Check for intersection
        if (tangentViewVector.z * distanceToNextTexel + position.z < height) break;

        // Distance to second closest texel
        float distanceToNextTexel2 = min(
            maxof(distanceToNextTexelDirectional.xy),
            minof(distanceToNextTexelDirectional.zw)
        );

        // Move to halfway trough next texel
        position += 0.5 * (distanceToNextTexel + distanceToNextTexel2) * tangentViewVector;
    }

    position.xy = clamp(fract(position.st), 1e-6, 1.0 - 1e-6) * atlasTileSize + atlasTileOffset;

    //parallaxShadow = parallax_calculateShadow(position, textureCoordinateDerivatives, (shadowLightPosition) * tbnMatrixView);

    return position.xy;
}

void main() {

float shadowed    = 1.0;
mat2  derivatives = mat2(dFdx(texcoord), dFdy(texcoord));
vec2  coord       = parallax_calculateCoordinate(texcoord, derivatives, tangentViewSpace, shadowed);

vec4 albedo = texture2D(texture, coord);
vec4 speculartex = texture2D(specular, coord);
vec4 normalTex   = texture2D(normals, coord) * 2.0 - 1.0;

albedo.rgb *= (color.rgb + entityColor.rgb);
colortex0write = albedo;
#ifdef Minecraft_AO
colortex1write = vec4(vertexlightmaps * (color.a * 1.2), matIDs * 0.1, 1);
#else
colortex1write = vec4(vertexlightmaps * 1.0, matIDs * 0.1, 1);
#endif

colortex2write = vec4(normalize(TBN * normalTex.xyz) * 0.5 + 0.5, 1);
colortex3write = speculartex;
}