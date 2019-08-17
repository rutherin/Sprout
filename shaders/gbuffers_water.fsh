#version 450 compatibility
#include "/lib/settings.glsl"

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
uniform vec3 cameraPosition;


uniform mat4 gbufferModelView;

uniform sampler2D texture;

#define GOLDEN_ANGLE_RADIAN 2.39996
 
float linearstep(const float edge, float x) {
	return clamp(x / edge, 0.0, 1.0);
}

float circ(vec2 pos, vec2 c, float s)
{
	c = abs(pos - c);
	c = min(c, 1.0 - c);
//	return dot(c, c) < s ? -1.0 : 0.0;
	return linearstep(0.002, sqrt(s) - length(c));
}

// Foam pattern for the water constructed out of a series of circles
float waterlayer(vec2 uv)
{
    uv = mod(uv, 1.0); // Clamp to [0..1]
    float ret = 0.0;
    ret += circ(uv, vec2(0.37378, 0.277169), 0.0268181);
    ret += circ(uv, vec2(0.0317477, 0.540372), 0.0193742);
    ret += circ(uv, vec2(0.430044, 0.882218), 0.0232337);
    ret += circ(uv, vec2(0.641033, 0.695106), 0.0117864);
    ret += circ(uv, vec2(0.0146398, 0.0791346), 0.0299458);
    ret += circ(uv, vec2(0.43871, 0.394445), 0.0289087);
    ret += circ(uv, vec2(0.909446, 0.878141), 0.028466);
    ret += circ(uv, vec2(0.310149, 0.686637), 0.0128496);
    ret += circ(uv, vec2(0.928617, 0.195986), 0.0152041);
    ret += circ(uv, vec2(0.0438506, 0.868153), 0.0268601);
    ret += circ(uv, vec2(0.308619, 0.194937), 0.00806102);
    ret += circ(uv, vec2(0.349922, 0.449714), 0.00928667);
    ret += circ(uv, vec2(0.0449556, 0.953415), 0.023126);
    ret += circ(uv, vec2(0.117761, 0.503309), 0.0151272);
    ret += circ(uv, vec2(0.563517, 0.244991), 0.0292322);
    ret += circ(uv, vec2(0.566936, 0.954457), 0.00981141);
    ret += circ(uv, vec2(0.0489944, 0.200931), 0.0178746);
    ret += circ(uv, vec2(0.569297, 0.624893), 0.0132408);
    ret += circ(uv, vec2(0.298347, 0.710972), 0.0114426);
    ret += circ(uv, vec2(0.878141, 0.771279), 0.00322719);
    ret += circ(uv, vec2(0.150995, 0.376221), 0.00216157);
    ret += circ(uv, vec2(0.119673, 0.541984), 0.0124621);
    ret += circ(uv, vec2(0.629598, 0.295629), 0.0198736);
    ret += circ(uv, vec2(0.334357, 0.266278), 0.0187145);
    ret += circ(uv, vec2(0.918044, 0.968163), 0.0182928);
    ret += circ(uv, vec2(0.965445, 0.505026), 0.006348);
    ret += circ(uv, vec2(0.514847, 0.865444), 0.00623523);
    ret += circ(uv, vec2(0.710575, 0.0415131), 0.00322689);
    ret += circ(uv, vec2(0.71403, 0.576945), 0.0215641);
    ret += circ(uv, vec2(0.748873, 0.413325), 0.0110795);
    ret += circ(uv, vec2(0.0623365, 0.896713), 0.0236203);
    ret += circ(uv, vec2(0.980482, 0.473849), 0.00573439);
    ret += circ(uv, vec2(0.647463, 0.654349), 0.0188713);
    ret += circ(uv, vec2(0.173781, 0.631155), 0.00049917);
    ret += circ(uv, vec2(0.173781, 0.631155), 0.019917);

    	

	return max(1.0 - ret, 0.0);
}

// Procedural texture generation for the water
vec3 water(vec2 uv) {
  uv *= vec2(0.25);
	
	// Texture distortion
	float d1 = mod(uv.x + uv.y, TAU);
	float d2 = mod((uv.x + uv.y + 0.25) * 1.3, TAU * 3);
	d1 = frameTimeCounter * 0.25 + d1;
	d2 = frameTimeCounter * 0.5 + d2;
	vec2 dist = vec2(
		(sin(d1) + sin(2.2 * uv.y + 5.52) + sin(2.9 * uv.x + 0.93) + sin(4.6 * uv.x + 8.94)) / 4,
		(cos(d1) + cos(1.2 * uv.x + 1.52) + cos(5.9 * uv.y + 0.23) + cos(1.6 * uv.x + 2.94)) / 16

	);
  
  float depth = length(worldspace - cameraPosition) / 3.0;
	
	vec3 waterCol  = vec3(0.0, 0.4453, 0.7305);
	vec3 waterCol2 = vec3(0.0, 0.4180, 0.6758);
	vec3 foamCol   = vec3(0.9625, 0.9609, 0.9648) * 2;
  
	vec3 ret = mix(waterCol, waterCol2, waterlayer(uv + dist.xy));
	ret = mix(ret, foamCol, waterlayer(vec2(1.0) - uv - dist.yx) / (1.0 + depth));
	return ret;
}

void main() {

vec3 normalTangentSpace =  normals;
vec3 viewSpace = mat3(gbufferModelView) * worldspace;

vec4 albedo = texture2D(texture, texcoord);

if (isWater > 0.5) albedo = vec4(water(worldspace.xz - worldspace.y * 0.2), 1.0);

albedo.rgb *= color;

colortex0write = albedo;
colortex1write = vec4(vertexlightmaps, 1, 1);
colortex2write = vec4(normalTangentSpace * 0.5 + 0.5, 1);
}