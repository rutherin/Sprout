#version 450 compatibility
#include "/lib/settings.glsl"
#include "/lib/Utility.glsl"

////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////ORIGINAL SHADER SPROUT BY SILVIA//////////////////////////////////
/////Anyone downloading this has permission to edit anything within for personal use, but //////////
/////////////////////redistribution of any kind requires explicit permission.///////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////


varying vec2 texcoord;
varying vec3 color;
uniform ivec2 eyeBrightnessSmooth;
uniform ivec2 eyeBrightness;

float indoors       = 1.0 - clamp01((-eyeBrightnessSmooth.y + 230) / 100.0);


float ShadowBiasC = shadowBias;

float distortionfactor(vec2 shadowSpace) {
float ShadowDistC = 1.165;

  if (eyeBrightness.y <= 200) {
  	ShadowDistC = 1.0;
  }

  vec2  coord = abs(shadowSpace);
  float dist = length(coord);
	return ((1.0 - shadowBias) + dist * shadowBias);
}


void main() {

gl_Position = ftransform();

gl_Position.xyz /= vec3(vec2(distortionfactor(gl_Position.xy)), shadowZstretch);

texcoord = gl_MultiTexCoord0.xy;

color = gl_Color.rgb;

}