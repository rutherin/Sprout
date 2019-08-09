#version 460 compatibility
#include "/lib/Settings.glsl"


varying vec2 texcoord;
varying vec3 color;

float distortionfactor(vec2 shadowspace){
float dist = length(abs(shadowspace * 1.165));
float distortion = ((1.0 - shadowBias) + dist * shadowBias) * 0.97;
return distortion;
}

void main() {

gl_Position = ftransform();

gl_Position.xyz /= vec3(vec2(distortionfactor(gl_Position.xy)), shadowZstretch);

texcoord = gl_MultiTexCoord0.xy;

color = gl_Color.rgb;

}