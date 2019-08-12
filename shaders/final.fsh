#version 450 compatibility

#include "/lib/Settings.glsl"
#include "/lib/Utility.glsl"

////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////ORIGINAL SHADER SPROUT BY SILVIA//////////////////////////////////
/////Anyone downloading this has permission to edit anything within for personal use, but //////////
/////////////////////redistribution of any kind requires explicit permission.///////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////

/* DRAWBUFFERS:0 */

const bool colortex0MipmapEnabled = true;
const bool colortex6MipmapEnabled = true;

layout (location = 0) out vec4 outColor;

#define About 0 //[0]
#define About1 0 //[0] Clouds and underwater! lots of things fixed and rebalanced~

varying vec2 texcoord;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D texture;
uniform sampler2D noisetex;
uniform sampler2D colortex0;
uniform sampler2D colortex6;
uniform sampler2D depthtex0;
uniform int frameCounter;
uniform float centerDepthSmooth;
uniform float aspectRatio;
uniform float frameTimeCounter;
uniform mat4 gbufferProjection, gbufferProjectionInverse;
uniform vec2 resolution;
uniform float frameTime;
uniform int isEyeInWater;



uniform float viewWidth, viewHeight;
uniform float near, far;
vec2 pixel = 1.0 / vec2(viewWidth, viewHeight);

#define lumaCoeff vec3(0.2125, 0.7254, 0.0721)
#include "/lib/Palette.glsl"


vec3 toSRGB(vec3 color) {
	return mix(color * 12.92, 1.055 * pow(color, vec3(1.0 / 2.4)) - 0.055, vec3(greaterThan(color, vec3(0.0031308))));
}

vec3 toLinear(vec3 color) {
	return mix(color / 12.92, pow((color + 0.055) / 1.055, vec3(2.4)), vec3(greaterThan(color, vec3(0.04045))));
}

vec3 getColor(vec2 coord) {
    return texture2DLod(colortex6, coord, 0.0).rgb;
}

#define PI  radians(180.0)
#define TAU PI * 2.0
#define PHI sqrt(5.0) * 0.5 + 0.5
#define GOLDEN_ANGLE TAU / PHI / PHI

vec2 circlemap(vec2 p) {
	p.y *= TAU;
	return vec2(cos(p.y), sin(p.y)) * sqrt(p.x);
}

#define cubicSmooth(x) (x * x) * (3.0 - 2.0 * x)


float calculateViewSpaceZ(float depth) {
	depth = depth * 2.0 - 1.0;
	return -1.0 / (depth * gbufferProjectionInverse[2][3] + gbufferProjectionInverse[3][3]);
}

vec2 hammersley(int i, int N) {
	return vec2(float(i) / float(N), float(bitfieldReverse(i)) * 2.3283064365386963e-10);
}

vec4 noiseSmooth(vec2 coord) {
    coord = coord * noiseTextureResolution + 0.5;

	vec2 whole = floor(coord);
	vec2 part  = cubicSmooth(fract(coord));

	coord = (whole + part - 0.5) * noiseResInverse;

	return texture2D(noisetex, coord);
}

vec2 calculateDistortion() {
    vec2 coord = texcoord;

    float noiseTexture = texture2D(noisetex, coord.st * 0.03 + frameTimeCounter * 0.001).x;
    return coord;
}

float ld(float depth) {
    return (2.0 * near) / (far + near - depth * (far - near));
}


void calculateDepthOfField(inout vec3 color, in vec2 coord) {
#ifndef Depth_Of_Field
return;
#endif
    float ditherSizeSq = pow(viewWidth, 2.0);
    float dither       = pow(noiseSmooth(gl_FragCoord.xy * noiseResInverse).b, 2.2) * ditherSizeSq;

    float focalLength  = Focal_Length / 1000.0;
    float aperture     = (Focal_Length / FStop) / 1000.0;

    float expDepth     = texture2D(depthtex1, coord).x;
    if (expDepth < texture2D(depthtex2, coord).x) return;
    float depth        = calculateViewSpaceZ(expDepth);
    float focus        = calculateViewSpaceZ(centerDepthSmooth);

    float CoC          = ((aperture) * ((focalLength) * (focus - depth)) / (focus * (depth - (focalLength)))) * 1000.0;

    #ifdef Distance_Blur
          CoC         += smoothstep(0.1, 1.8, ld(expDepth)) * 1.4;
    #endif

    if (isEyeInWater >= 0.5) CoC += smoothstep(0.1, 0.3, ld(expDepth)) * 0.4;

    #ifdef Tilt_Shift
          CoC          = (coord.y - 0.5) * 0.5;
    #endif
    
    vec2 segment = circlemap(
        hammersley(int(DepthOfFieldQuality * ditherSizeSq + dither), int(DepthOfFieldQuality * ditherSizeSq))
    ) * aperture * CoC;

    float f = TAU / DepthOfFieldQuality;
    float a = cos(f);
    float b = sin(f);

    vec3  depthOfField = vec3(0.0);

    for (int i = 0; i < DepthOfFieldQuality; i++) {
        vec2 offset = segment * vec2(1.0, aspectRatio);

        depthOfField += toLinear(texture2DLod(colortex6, segment * vec2(1.0, aspectRatio) + coord, 0.0).rgb);

        float ns = b * segment.y + a * segment.x;
        float nc = a * segment.y - b * segment.x;
        segment = vec2(ns,nc);
    }

    color = depthOfField / DepthOfFieldQuality;
}

void calculateNightEye(inout vec3 color) {
    float luminance  = dot(color, lumaCoeff);
    float lows       = exp(-luminance * 100.0);
    vec3  saturation = mix(vec3(1.05, 1.0, 1.0), vec3(0.1, 0.1, 0.1), lows);
    vec3  tint       = normalize(vec3(0.2, 0.1, 0.3)) * 10;

    color = mix(luminance * tint, color, saturation);
}


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

void tonemap_filmic(inout vec3 color) {

	const vec3 a = vec3(1.14, 1.14, 1.14) * 1.8;
	const vec3 b = vec3(0.62, 0.59, 0.62);
	const vec3 c = vec3(0.82, 0.82, 0.82);
	const vec3 d = vec3(0.50, 0.50, 0.50);

	vec3 cr = mix(vec3(dot(color, lumaCoeff)), color, d) + 1.0;

	color = pow(color, a);
	color = pow(color / (1.0 + color), b / a);
	color = pow(color * color * (-2.0 * color + 3.0), cr / c);
}

vec4 cubic(float x) {
  float x2 = x * x;
  float x3 = x2 * x;
  vec4 w;
  w.x =   -x3 + 3*x2 - 3*x + 1;
  w.y =  3*x3 - 6*x2       + 4;
  w.z = -3*x3 + 3*x2 + 3*x + 1;
  w.w =  x3;
  return w / 6.f;
}

vec4 bicubicTexture(sampler2D tex, vec2 coord) {
  vec2 resolution = vec2(viewWidth, viewHeight);

  coord *= resolution;

  float fx = fract(coord.x);
  float fy = fract(coord.y);
  coord.x -= fx;
  coord.y -= fy;

  vec4 xcubic = cubic(fx);
  vec4 ycubic = cubic(fy);

  vec4 c = vec4(coord.x - 0.5, coord.x + 1.5, coord.y - 0.5, coord.y + 1.5);
  vec4 s = vec4(xcubic.x + xcubic.y, xcubic.z + xcubic.w, ycubic.x + ycubic.y, ycubic.z + ycubic.w);
  vec4 offset = c + vec4(xcubic.y, xcubic.w, ycubic.y, ycubic.w) / s;

  vec4 sample0 = texture2D(tex, vec2(offset.x, offset.z) / resolution);
  vec4 sample1 = texture2D(tex, vec2(offset.y, offset.z) / resolution);
  vec4 sample2 = texture2D(tex, vec2(offset.x, offset.w) / resolution);
  vec4 sample3 = texture2D(tex, vec2(offset.y, offset.w) / resolution);

  float sx = s.x / (s.x + s.y);
  float sy = s.z / (s.z + s.w);

  return mix( mix(sample3, sample2, sx), mix(sample1, sample0, sx), sy);
}

vec2 pixelSize = 1.0 / vec2(viewWidth, viewHeight);

vec3 SeishinBloomTile(const float lod, vec2 offset) {
	return toLinear(bicubicTexture(colortex0, texcoord / exp2(lod) + offset - pixelSize * 0.5).rgb * 10.0);
}

void SeishinBloom(inout vec3 color) {
	
	vec3 bloom = vec3(0.0);
	bloom += SeishinBloomTile(2.0, vec2(0.0                         ,                        0.0)) * 0.475;
	bloom += SeishinBloomTile(3.0, vec2(0.0                         , 0.25   + pixelSize.y * 2.0)) * 0.625;
	bloom += SeishinBloomTile(4.0, vec2(0.125    + pixelSize.x * 2.0, 0.25   + pixelSize.y * 2.0)) * 0.750;
	bloom += SeishinBloomTile(5.0, vec2(0.1875   + pixelSize.x * 4.0, 0.25   + pixelSize.y * 2.0)) * 0.850;
	bloom += SeishinBloomTile(6.0, vec2(0.125    + pixelSize.x * 2.0, 0.3125 + pixelSize.y * 4.0)) * 0.925;
	bloom += SeishinBloomTile(7.0, vec2(0.140625 + pixelSize.x * 4.0, 0.3125 + pixelSize.y * 4.0)) * 0.975;
	
	bloom /= 5.0;
	
	color = mix(color, bloom, 0.2);
}


void ditherScreen(inout vec3 color) {
    vec3 lestynRGB = vec3(dot(vec2(171.0, 231.0), gl_FragCoord.xy));
         lestynRGB = fract(lestynRGB.rgb / vec3(103.0, 71.0, 97.0));

    color += lestynRGB.rgb / 255.0;
}

#include "/lib/ACES_Main.glsl"



void main() {
int pixelCOMB = (pixelX * pixelY) / 2;


#ifdef Pixelizer
vec2 newTC = pixelize(texcoord, pixelCOMB);
#else
vec2 newTC = texcoord;
#endif

vec3 color = toLinear(texture2D(colortex6, newTC).rgb);

#ifdef Depth_Of_Field
calculateDepthOfField(color, newTC);
#endif
//calculateBloom(color, newTC);

//calculateExposure(color);
calculateNightEye(color);
//tonemap_filmic(color);

color = (color * sRGB_2_AP0) * 1.0;
FilmToneMap(color);

color = WhiteBalance(color);
color = Vibrance(color);
color = Saturation(color);
color = Contrast(color);
color = LiftGammaGain(color);
SeishinBloom(color);

#ifdef Big_Dither
color = dither8x8(newTC, color, pixelCOMB);
#endif



#ifndef Color_Compression
color          = toSRGB(color * 1.2);
#endif
ditherScreen(color);

gl_FragColor   = vec4(color, 1.0);
}