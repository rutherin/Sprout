#version 460 compatibility
#include "/lib/Settings.glsl"

////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////ORIGINAL SHADER SPROUT BY SILVIA//////////////////////////////////
/////Anyone downloading this has permission to edit anything within for personal use, but //////////
/////////////////////redistribution of any kind requires explicit permission.///////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

varying vec2 texcoord;
varying vec3 color;
varying vec2 vertexlightmaps;
varying vec3 normals;
varying vec3 worldspace;
attribute vec4 at_tangent;
varying vec3 tangentViewSpace;
attribute vec4 mc_Entity;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

varying mat3 tbnMatrix;

varying float isWater;

uniform float viewWidth;
uniform float viewHeight;
uniform int frameCounter;

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

void main() {

isWater = 0.0;
if (mc_Entity.x == 8.0 || mc_Entity.x == 9.0) isWater = 1.0;

vec3 normal = normalize(gl_NormalMatrix * gl_Normal);
vec3 tangent = normalize(gl_NormalMatrix*at_tangent.xyz);
vec3 binormal = normalize(cross(tangent, normal));

tbnMatrix = transpose(mat3(tangent, binormal, normal));

tangentViewSpace = tbnMatrix * (gl_ModelViewMatrix * gl_Vertex).xyz;

worldspace = (gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex)).xyz + cameraPosition;

normals = gl_NormalMatrix * gl_Normal;

gl_Position = ftransform();

gl_Position.xy = temporalJitter() * gl_Position.w + gl_Position.xy;

texcoord = gl_MultiTexCoord0.xy;

color = gl_Color.rgb;

vertexlightmaps = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;

}
